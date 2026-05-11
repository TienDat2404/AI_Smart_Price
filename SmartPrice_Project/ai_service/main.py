"""
SmartPrice AI Engine — FastAPI server
Cung cấp 2 endpoints:
  POST /parse/text  — NLP bóc tách chi tiêu từ văn bản
  POST /parse/image — OCR bóc tách hóa đơn từ ảnh (EasyOCR + Regex)

Chạy:
  cd ai_service
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import re
import io
import os
import logging
from datetime import datetime
from typing import Optional

import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(title="SmartPrice AI Engine", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Lazy-load EasyOCR (tránh khởi động chậm) ─────────────────────────────────
_ocr_reader = None

# ── Load NLP model (nếu đã train) ────────────────────────────────────────────
_nlp_model = None

def get_nlp_model():
    """Load model đã train từ nlp_model.pkl nếu có."""
    global _nlp_model
    if _nlp_model is not None:
        return _nlp_model
    model_path = os.path.join(os.path.dirname(__file__), "nlp_model.pkl")
    if os.path.exists(model_path):
        try:
            import pickle
            with open(model_path, "rb") as f:
                _nlp_model = pickle.load(f)
            logger.info(f"✅ Loaded NLP model từ {model_path}")
        except Exception as e:
            logger.warning(f"Không load được NLP model: {e}")
            _nlp_model = None
    return _nlp_model

def get_ocr_reader():
    global _ocr_reader
    if _ocr_reader is None:
        try:
            import easyocr
            logger.info("Đang khởi tạo EasyOCR (lần đầu có thể mất 30-60 giây)...")
            _ocr_reader = easyocr.Reader(["vi", "en"], gpu=False)
            logger.info("EasyOCR sẵn sàng.")
        except ImportError:
            logger.warning("EasyOCR chưa được cài. Dùng: pip install easyocr")
            _ocr_reader = None
    return _ocr_reader


# ── Vietnamese Dialect Normalizer ─────────────────────────────────────────────

# Từ địa phương → từ phổ thông
DIALECT_WORD_MAP = {
    # Động từ vùng miền
    "mần":      "ăn",       # Miền Trung/Nghệ Tĩnh: "mần cái bánh" → "ăn cái bánh"
    "nhậu":     "ăn",       # nhậu → ăn uống
    "kiếm":     "mua",      # "kiếm cái áo" → "mua cái áo"
    "chộp":     "mua",      # miền Nam
    "dzô":      "vào",
    "dzề":      "về",
    "dzậy":     "vậy",
    "hổng":     "không",
    "hổng có":  "không có",
    "tui":      "tôi",
    "mình":     "tôi",
    "tau":      "tôi",      # Nghệ Tĩnh
    "mi":       "bạn",      # Nghệ Tĩnh
    "eng":      "anh",      # Nghệ Tĩnh
    "ả":        "chị",      # Nghệ Tĩnh
    "nác":      "nước",     # Nghệ Tĩnh
    "mô":       "đâu",      # Nghệ Tĩnh/Huế
    "răng":     "sao",      # Nghệ Tĩnh/Huế
    "rứa":      "vậy",      # Nghệ Tĩnh/Huế
    "ni":       "này",      # Huế
    "tê":       "kia",      # Huế
    "chừ":      "giờ",      # Huế/miền Trung
    "hết":      "hết",      # giữ nguyên (dùng trong "hết X tiền")
    "xài":      "dùng",     # miền Nam
    "lẹ":       "nhanh",    # miền Nam
    "bự":       "lớn",      # miền Nam
    "coi":      "xem",      # miền Nam
    "thứ":      "cái",      # miền Nam
}

# Số đếm vùng miền → giá trị số
DIALECT_NUMBER_MAP = {
    # Miền Nam đặc trưng
    r"\bhăm\s*lăm\b":          "25",
    r"\bhăm\s*mốt\b":          "21",
    r"\bhăm\s*hai\b":          "22",
    r"\bhăm\s*ba\b":           "23",
    r"\bhăm\s*bốn\b":          "24",
    r"\bhăm\s*sáu\b":          "26",
    r"\bhăm\s*bảy\b":          "27",
    r"\bhăm\s*tám\b":          "28",
    r"\bhăm\s*chín\b":         "29",
    r"\bhăm\b":                "20",   # "hăm ngàn" = 20k
    r"\bnhăm\b":               "25",   # biến thể của "hăm lăm"
    r"\blăm\b":                "5",    # "lăm ngàn" = 5k (khi đứng một mình)
    r"\bmốt\b":                "1",    # "mốt ngàn" = 1k
    # Đơn vị tiền tệ vùng miền
    r"\bngàn\b":               "000",  # miền Nam: "ngàn" = nghìn
    r"\bngàn\s*đồng\b":        "000",
    r"\bchục\b":               "0",    # "hai chục" = 20 (x10)
    r"\bchục\s*ngàn\b":        "0000", # "hai chục ngàn" = 20.000
    r"\bchục\s*nghìn\b":       "0000",
    # Số đếm phổ thông nhưng hay bị nhầm
    r"\bmười\s*lăm\b":         "15",
    r"\bmười\s*mốt\b":         "11",
    r"\bmười\s*hai\b":         "12",
    r"\bmười\s*ba\b":          "13",
    r"\bmười\s*bốn\b":         "14",
    r"\bmười\s*sáu\b":         "16",
    r"\bmười\s*bảy\b":         "17",
    r"\bmười\s*tám\b":         "18",
    r"\bmười\s*chín\b":        "19",
    r"\bnăm\s*chục\b":         "50",   # "năm chục" = 50
    r"\bba\s*chục\b":          "30",
    r"\bbốn\s*chục\b":         "40",
    r"\bsáu\s*chục\b":         "60",
    r"\bbảy\s*chục\b":         "70",
    r"\btám\s*chục\b":         "80",
    r"\bchín\s*chục\b":        "90",
    r"\bhai\s*chục\b":         "20",
    r"\bmột\s*chục\b":         "10",
}

# Số chữ → số (phổ thông)
WORD_TO_NUMBER = {
    "không": 0, "một": 1, "hai": 2, "ba": 3, "bốn": 4,
    "năm": 5, "sáu": 6, "bảy": 7, "tám": 8, "chín": 9,
    "mười": 10, "mươi": 10,
    "trăm": 100, "nghìn": 1000, "ngàn": 1000,
    "triệu": 1000000, "tỷ": 1000000000,
}


def normalize_dialect(text: str) -> str:
    """
    Chuẩn hóa từ địa phương → từ phổ thông.
    Xử lý theo thứ tự: số đếm → từ vựng → đơn vị tiền.
    """
    result = text.lower().strip()

    # 1. Chuẩn hóa số đếm vùng miền (regex, thứ tự quan trọng — dài trước)
    for pattern, replacement in DIALECT_NUMBER_MAP.items():
        result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)

    # 2. Chuẩn hóa từ vựng địa phương (word boundary)
    for dialect_word, standard_word in DIALECT_WORD_MAP.items():
        result = re.sub(
            r'\b' + re.escape(dialect_word) + r'\b',
            standard_word,
            result,
            flags=re.IGNORECASE
        )

    # 3. Chuẩn hóa "X chục" → số (nếu chưa được xử lý)
    # "hai chục ngàn" → "20 ngàn" → 20000
    def replace_chuc(m):
        word = m.group(1).lower()
        n = WORD_TO_NUMBER.get(word, 0)
        return str(n * 10)
    result = re.sub(
        r'\b(một|hai|ba|bốn|năm|sáu|bảy|tám|chín)\s+chục\b',
        replace_chuc, result, flags=re.IGNORECASE
    )

    logger.info(f"Dialect normalize: '{text}' → '{result}'")
    return result


def extract_amount_vi(text: str) -> float:
    """
    Bóc tách số tiền từ văn bản tiếng Việt đã được chuẩn hóa.
    Hỗ trợ: "50k", "50 nghìn", "50 ngàn", "50.000", "50000"
    """
    # Chuẩn hóa dialect trước
    normalized = normalize_dialect(text)

    # Thử extract từ text đã normalize
    amount = extract_amount(normalized)
    if amount > 0:
        return amount

    # Fallback: thử extract từ text gốc
    return extract_amount(text)


# ── Category keywords ─────────────────────────────────────────────────────────
CATEGORY_KEYWORDS = {
    "Ăn uống":   [
        # Phổ thông
        "phở", "cơm", "bún", "bánh", "ăn", "cafe", "trà", "nhậu", "lẩu",
        "pizza", "burger", "sushi", "restaurant", "food", "drink", "coffee",
        "bữa", "ăn sáng", "ăn trưa", "ăn tối", "uống",
        # Miền Nam
        "cà phê", "hủ tiếu", "bánh mì", "cơm tấm", "bún bò",
        # Miền Trung / Nghệ Tĩnh
        "mần",      # "mần cái bánh" = ăn cái bánh
        "tô",       # "tô phở", "tô bún"
        "chén",     # "chén cơm"
        # Miền Bắc
        "bát", "đĩa",
    ],
    "Di chuyển": [
        "grab", "xe", "xăng", "bus", "taxi", "uber", "gojek", "transport",
        "petrol", "fuel", "parking", "bãi xe",
        # Vùng miền
        "xe ôm",    # miền Nam/Bắc: xe ôm = xe máy ôm
        "honda ôm", # miền Nam
        "xích lô",
        "xe lam",   # miền Nam
        "xe đò",    # miền Nam: xe khách
        "tàu",      # tàu hỏa, tàu điện
        "máy bay",
    ],
    "Mua sắm":   [
        "shopee", "lazada", "tiki", "quần", "áo", "giày", "mua", "shop",
        "store", "market", "siêu thị", "vinmart", "coopmart", "bigc",
        # Vùng miền
        "chợ",      # đi chợ
        "kiếm",     # miền Nam: "kiếm cái áo" = mua cái áo
        "chộp",     # miền Nam: "chộp cái này"
    ],
    "Giải trí":  [
        "phim", "game", "netflix", "spotify", "cinema", "cgv", "lotte",
        "entertainment", "concert", "karaoke",
        "coi phim",  # miền Nam: coi = xem
        "coi",
    ],
    "Sức khỏe":  [
        "thuốc", "bác sĩ", "khám", "gym", "pharmacy", "hospital", "clinic",
        "pharmacity", "guardian", "medicine",
        "nhà thuốc", "tiệm thuốc",
    ],
    "Hóa đơn":   [
        "điện", "nước", "internet", "wifi", "điện thoại", "electric",
        "water", "bill", "invoice",
        "tiền nhà", "tiền thuê",
    ],
    "Thu nhập":  [
        "lương", "thưởng", "freelance", "salary", "income", "bonus",
        "tiền công", "tiền làm",
    ],
}


def detect_category(text: str) -> str:
    """
    Phát hiện hạng mục từ văn bản.
    Ưu tiên: ML model (nếu đã train) → keyword dict (fallback)
    """
    # Thử dùng ML model trước
    model = get_nlp_model()
    if model is not None:
        try:
            vec  = model["vectorizer"].transform([text])
            pred = model["clf"].predict(vec)[0]
            prob = model["clf"].predict_proba(vec).max()
            if prob >= 0.5:  # chỉ tin nếu độ tin cậy >= 50%
                logger.info(f"ML category: '{pred}' ({prob*100:.0f}%)")
                return pred
        except Exception as e:
            logger.warning(f"ML predict lỗi: {e}")

    # Fallback: keyword dict
    lower = text.lower()
    for category, keywords in CATEGORY_KEYWORDS.items():
        for kw in keywords:
            if kw in lower:
                return category
    return "Khác"


def extract_amount(text: str) -> float:
    """
    Bóc tách số tiền từ văn bản OCR.
    Hỗ trợ các định dạng:
      - 450,000  /  450.000  /  450000
      - 45k  /  45K
      - 45 nghìn  /  45 nghin
      - TOTAL: 450,000  /  Tổng: 450.000
    """
    # Ưu tiên tìm dòng có nhãn tổng tiền
    total_patterns = [
        r"(?:total|tổng|thanh toán|thành tiền|cộng|grand total)[:\s]*([0-9][0-9,. ]+)",
        r"(?:tong|tong tien|tong cong)[:\s]*([0-9][0-9,. ]+)",
    ]
    for pat in total_patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            raw = m.group(1).strip()
            amount = _parse_number(raw)
            if amount > 0:
                logger.info(f"Tìm thấy tổng tiền (label): {amount}")
                return amount

    # Tìm số tiền dạng "45k" / "45K"
    k_match = re.search(r"(\d+(?:[.,]\d+)?)\s*[kK]\b", text)
    if k_match:
        amount = float(k_match.group(1).replace(",", ".")) * 1000
        logger.info(f"Tìm thấy số tiền (k): {amount}")
        return amount

    # Tìm số tiền dạng "45 nghìn"
    nghin_match = re.search(r"(\d+)\s*(?:nghìn|nghin|ngàn|ngan)", text, re.IGNORECASE)
    if nghin_match:
        amount = float(nghin_match.group(1)) * 1000
        logger.info(f"Tìm thấy số tiền (nghìn): {amount}")
        return amount

    # Tìm số có dấu phân cách (450,000 hoặc 450.000)
    sep_matches = re.findall(r"\b(\d{1,3}(?:[.,]\d{3})+)\b", text)
    if sep_matches:
        amounts = [_parse_number(m) for m in sep_matches]
        amounts = [a for a in amounts if a > 0]
        if amounts:
            best = max(amounts)  # lấy số lớn nhất (thường là tổng)
            logger.info(f"Tìm thấy số tiền (phân cách): {best}")
            return best

    # Tìm số nguyên >= 4 chữ số
    plain_matches = re.findall(r"\b(\d{4,})\b", text)
    if plain_matches:
        amounts = [float(m) for m in plain_matches]
        best = max(amounts)
        logger.info(f"Tìm thấy số tiền (plain): {best}")
        return best

    return 0.0


def _parse_number(raw: str) -> float:
    """Chuyển chuỗi số có dấu phân cách thành float."""
    # Xác định dấu thập phân: nếu có cả , và . thì dấu cuối là thập phân
    raw = raw.strip()
    if "," in raw and "." in raw:
        # 450,000.50 → dấu . là thập phân
        if raw.rfind(".") > raw.rfind(","):
            raw = raw.replace(",", "")
        else:
            # 450.000,50 → dấu , là thập phân
            raw = raw.replace(".", "").replace(",", ".")
    elif "," in raw:
        # 450,000 → dấu phân nghìn
        parts = raw.split(",")
        if len(parts) == 2 and len(parts[1]) == 3:
            raw = raw.replace(",", "")
        else:
            raw = raw.replace(",", ".")
    elif "." in raw:
        parts = raw.split(".")
        if len(parts) == 2 and len(parts[1]) == 3:
            raw = raw.replace(".", "")
    try:
        return float(raw)
    except ValueError:
        return 0.0


def extract_store_name(text: str) -> str:
    """Bóc tách tên cửa hàng — thường ở dòng đầu tiên của hóa đơn."""
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    if not lines:
        return "Không rõ"
    # Dòng đầu thường là tên cửa hàng (loại bỏ dòng chỉ có số)
    for line in lines[:3]:
        if re.search(r"[a-zA-ZÀ-ỹ]", line) and len(line) > 2:
            return line[:50]  # giới hạn 50 ký tự
    return lines[0][:50]


def extract_date(text: str) -> str:
    """Bóc tách ngày từ văn bản OCR."""
    patterns = [
        r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})",   # dd/mm/yyyy
        r"(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})",   # yyyy-mm-dd
        r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})",   # dd/mm/yy
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            groups = m.groups()
            if len(groups[0]) == 4:  # yyyy-mm-dd
                return f"{groups[2]}/{groups[1]}/{groups[0]}"
            return f"{groups[0].zfill(2)}/{groups[1].zfill(2)}/{groups[2]}"
    return datetime.now().strftime("%d/%m/%Y")


# ── Models ────────────────────────────────────────────────────────────────────

class TextParseRequest(BaseModel):
    text: str

class ParseResponse(BaseModel):
    item: str
    price: float
    category: str
    confidence: float = 1.0
    note: Optional[str] = None
    normalized_text: Optional[str] = None   # text sau khi chuẩn hóa dialect
    dialect_detected: bool = False           # có phát hiện từ địa phương không


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/")
def health():
    return {"status": "ok", "service": "SmartPrice AI Engine", "version": "1.0.0"}


@app.post("/parse/text", response_model=ParseResponse)
def parse_text(req: TextParseRequest):
    """
    NLP: Bóc tách chi tiêu từ văn bản tự nhiên.
    Hỗ trợ tiếng Việt vùng miền (Bắc, Trung, Nam).

    Input:  { "text": "Sáng nay uống cà phê hết hăm lăm ngàn" }
    Output: { "item": "Uống cà phê", "price": 25000, "category": "Ăn uống",
              "normalized_text": "sáng nay uống cà phê hết 25 000",
              "dialect_detected": true }
    """
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text không được để trống.")

    # 1. Chuẩn hóa dialect
    normalized = normalize_dialect(text)
    dialect_detected = (normalized.lower() != text.lower())

    # 2. Bóc tách số tiền từ text đã chuẩn hóa
    amount = extract_amount_vi(text)

    # 3. Phát hiện hạng mục (dùng cả text gốc và normalized)
    combined = text + " " + normalized
    category = detect_category(combined)

    # 4. Tạo item name: xóa phần số tiền và từ nối
    item = re.sub(r"\d+(?:[.,]\d+)?\s*[kK]\b", "", normalized, flags=re.IGNORECASE)
    item = re.sub(r"\d+\s*(?:nghìn|ngàn|nghin|ngan)", "", item, flags=re.IGNORECASE)
    item = re.sub(r"\b\d{4,}\b", "", item)
    item = re.sub(r"\b(hết|mất|tốn|chi|hôm nay|sáng nay|trưa nay|tối nay|hôm qua)\b",
                  "", item, flags=re.IGNORECASE)
    item = re.sub(r"\s{2,}", " ", item).strip()
    if item:
        item = item[0].upper() + item[1:]

    confidence = 0.92 if (amount > 0 and category != "Khác") else 0.65

    logger.info(f"parse_text: raw='{text}' → normalized='{normalized}' | "
                f"price={amount} | category='{category}' | dialect={dialect_detected}")

    return ParseResponse(
        item=item or text,
        price=amount,
        category=category,
        confidence=confidence,
        note=item or text,
        normalized_text=normalized if dialect_detected else None,
        dialect_detected=dialect_detected,
    )


@app.post("/parse/image")
async def parse_image(image: UploadFile = File(...)):
    """
    OCR: Bóc tách hóa đơn từ ảnh.
    Input:  multipart/form-data với field 'image'
    Output: { "store": "...", "total": 0, "date": "...", "category": "...", "confidence": 0.0 }
    """
    # Validate file type
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File phải là ảnh (jpg/png/webp).")

    # Đọc ảnh
    contents = await image.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File ảnh rỗng.")

    try:
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
        img_array = np.array(pil_image)
    except Exception as e:
        logger.error(f"Không thể đọc ảnh: {e}")
        raise HTTPException(status_code=422, detail=f"Không thể đọc ảnh: {str(e)}")

    # Chạy EasyOCR
    reader = get_ocr_reader()
    if reader is None:
        raise HTTPException(
            status_code=503,
            detail="EasyOCR chưa được cài. Chạy: pip install easyocr"
        )

    try:
        logger.info(f"Đang chạy EasyOCR trên ảnh {image.filename} ({img_array.shape})...")
        ocr_results = reader.readtext(img_array, detail=1, paragraph=False)
        logger.info(f"EasyOCR tìm thấy {len(ocr_results)} vùng text")
    except Exception as e:
        logger.error(f"EasyOCR lỗi: {e}")
        raise HTTPException(status_code=422, detail=f"OCR thất bại: {str(e)}")

    if not ocr_results:
        raise HTTPException(
            status_code=422,
            detail="Không nhận diện được text trong ảnh. Hãy chụp rõ hơn."
        )

    # Ghép toàn bộ text từ OCR
    full_text = "\n".join([item[1] for item in ocr_results])
    avg_confidence = sum(item[2] for item in ocr_results) / len(ocr_results)

    logger.info(f"Full OCR text:\n{full_text}")
    logger.info(f"Avg confidence: {avg_confidence:.2f}")

    # Bóc tách thông tin
    store    = extract_store_name(full_text)
    total    = extract_amount(full_text)
    date     = extract_date(full_text)
    category = detect_category(full_text)

    # Nếu không tìm được số tiền → báo lỗi
    if total == 0:
        raise HTTPException(
            status_code=422,
            detail="Không tìm thấy số tiền trong hóa đơn. Hãy chụp rõ hơn hoặc nhập tay."
        )

    result = {
        "store":      store,
        "total":      total,
        "date":       date,
        "category":   category,
        "confidence": round(avg_confidence, 2),
        "invoice_id": f"INV-{datetime.now().strftime('%Y%m%d')}-{hash(full_text) % 9000 + 1000}",
        "raw_text":   full_text[:500],  # debug — giới hạn 500 ký tự
    }

    logger.info(f"OCR result: {result}")
    return result
