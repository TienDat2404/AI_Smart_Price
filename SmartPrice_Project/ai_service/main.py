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
import json
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
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app):
    """Tải EasyOCR model ngay khi server khởi động — tránh chậm ở request đầu tiên."""
    import asyncio
    logger.info("🚀 Server đang khởi động — tải EasyOCR model vào RAM...")
    # Chạy trong thread pool để không block event loop
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, get_ocr_reader)
    if _ocr_reader is not None:
        logger.info("✅ EasyOCR model đã sẵn sàng — server có thể nhận request!")
    else:
        logger.warning("⚠️  EasyOCR không khả dụng — OCR sẽ thất bại")
    yield
    # Cleanup khi shutdown (không cần làm gì)
    logger.info("Server đang tắt...")

app = FastAPI(title="SmartPrice AI Engine", version="1.0.0", lifespan=lifespan)

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


# ── Load extended dialect map từ CentralVietnamDataset ───────────────────────
_EXTENDED_DIALECT_MAP: dict = {}

def _load_extended_dialect():
    """Load dialect_extended.json (tạo bởi build_dialect_map.py) vào memory."""
    global _EXTENDED_DIALECT_MAP
    json_path = os.path.join(os.path.dirname(__file__), "dialect_extended.json")
    if not os.path.exists(json_path):
        logger.warning("dialect_extended.json chưa có. Chạy: python build_dialect_map.py")
        return
    try:
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        # Dùng all_dialect_map (504 entries từ CentralVietnamDataset)
        _EXTENDED_DIALECT_MAP = data.get("all_dialect_map", {})
        logger.info(f"✅ Loaded {len(_EXTENDED_DIALECT_MAP)} dialect entries từ CentralVietnamDataset")
    except Exception as e:
        logger.warning(f"Không load được dialect_extended.json: {e}")

# Gọi khi module load
_load_extended_dialect()


# ── Vietnamese Dialect Normalizer ─────────────────────────────────────────────

# Từ địa phương → từ phổ thông
DIALECT_WORD_MAP = {
    # ── Miền Trung / Nghệ Tĩnh ────────────────────────────────────────────
    "mần":      "ăn",       # "mần cái bánh" → "ăn cái bánh"
    "nhậu":     "ăn",
    "nác":      "nước",
    "mô":       "đâu",
    "răng":     "sao",
    "rứa":      "vậy",
    "ni":       "này",
    "tê":       "kia",
    "chừ":      "giờ",
    "tau":      "tôi",
    "mi":       "bạn",
    "eng":      "anh",
    "ả":        "chị",
    "bọ":       "bố",
    "mạ":       "mẹ",
    "nỏ":       "không",
    "khòng":    "không",
    "bénh":     "bánh",
    "bỏ mối":   "bán sỉ",
    "rót nước": "đổ nước",
    # ── Miền Nam ──────────────────────────────────────────────────────────
    "kiếm":     "mua",
    "chộp":     "mua",
    "dzô":      "vào",
    "dzề":      "về",
    "dzậy":     "vậy",
    "hổng":     "không",
    "hổng có":  "không có",
    "tui":      "tôi",
    "mình":     "tôi",
    "xài":      "dùng",
    "lẹ":       "nhanh",
    "bự":       "lớn",
    "coi":      "xem",
    "thứ":      "cái",
    # ── Số đếm / đơn vị tiền ─────────────────────────────────────────────
    "ngàn":     "nghìn",    # miền Nam: "ngàn" = nghìn
    "hết":      "hết",      # giữ nguyên
    # ── Miền Bắc ─────────────────────────────────────────────────────────
    "honda ôm": "xe ôm",
    "đi chợ":   "mua sắm",
    "tiền chợ": "tiền mua sắm",
}

DIALECT_NUMBER_MAP = {
    # Miền Nam — hăm (20-29), thứ tự: dài trước
    r"\bhăm\s*lăm\b":   "25",
    r"\bhăm\s*mốt\b":   "21",
    r"\bhăm\s*hai\b":   "22",
    r"\bhăm\s*ba\b":    "23",
    r"\bhăm\s*bốn\b":   "24",
    r"\bhăm\s*sáu\b":   "26",
    r"\bhăm\s*bảy\b":   "27",
    r"\bhăm\s*tám\b":   "28",
    r"\bhăm\s*chín\b":  "29",
    r"\bhăm\b":         "20",
    r"\bnhăm\b":        "25",
    # Số + chục + đơn vị tiền → số nghìn trực tiếp
    # "hai chục" = 20.000đ khi không có đơn vị → thêm "nghìn" ngầm
    r"\bnăm\s*chục\s*(?:nghìn|ngàn|k)?\b":  "50 nghìn",
    r"\bbốn\s*chục\s*(?:nghìn|ngàn|k)?\b":  "40 nghìn",
    r"\bba\s*chục\s*(?:nghìn|ngàn|k)?\b":   "30 nghìn",
    r"\bhai\s*chục\s*(?:nghìn|ngàn|k)?\b":  "20 nghìn",
    r"\bmột\s*chục\s*(?:nghìn|ngàn|k)?\b":  "10 nghìn",
    r"\bsáu\s*chục\s*(?:nghìn|ngàn|k)?\b":  "60 nghìn",
    r"\bbảy\s*chục\s*(?:nghìn|ngàn|k)?\b":  "70 nghìn",
    r"\btám\s*chục\s*(?:nghìn|ngàn|k)?\b":  "80 nghìn",
    r"\bchín\s*chục\s*(?:nghìn|ngàn|k)?\b": "90 nghìn",
    # mười lăm/mốt/... — PHẢI đứng trước rule "\blăm\b" đơn lẻ
    r"\bmười\s*lăm\b":  "15",
    r"\bmười\s*mốt\b":  "11",
    r"\bmười\s*hai\b":  "12",
    r"\bmười\s*ba\b":   "13",
    r"\bmười\s*bốn\b":  "14",
    r"\bmười\s*sáu\b":  "16",
    r"\bmười\s*bảy\b":  "17",
    r"\bmười\s*tám\b":  "18",
    r"\bmười\s*chín\b": "19",
    # lăm đứng một mình (sau khi đã xử lý "mười lăm", "hăm lăm")
    r"\blăm\b":         "5",
    r"\bmốt\b":         "1",
    # Đơn vị tiền
    r"\bngàn\b":        "nghìn",
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
    Ưu tiên: số đếm → từ vựng hardcoded → CentralVietnamDataset (504 entries)
    """
    result = text.lower().strip()

    # 1. Chuẩn hóa số đếm vùng miền (regex, thứ tự quan trọng — dài trước)
    for pattern, replacement in DIALECT_NUMBER_MAP.items():
        result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)

    # 2. Chuẩn hóa từ vựng hardcoded (ưu tiên cao — đã kiểm tra kỹ)
    for dialect_word, standard_word in DIALECT_WORD_MAP.items():
        result = re.sub(
            r'\b' + re.escape(dialect_word) + r'\b',
            standard_word,
            result,
            flags=re.IGNORECASE
        )

    # 3. Chuẩn hóa từ CentralVietnamDataset (504 entries — sắp xếp dài trước)
    if _EXTENDED_DIALECT_MAP:
        # Sắp xếp theo độ dài giảm dần để match cụm từ dài trước
        sorted_entries = sorted(
            _EXTENDED_DIALECT_MAP.items(),
            key=lambda x: len(x[0]),
            reverse=True
        )
        for dialect_word, standard_word in sorted_entries:
            if dialect_word in result:
                result = re.sub(
                    r'\b' + re.escape(dialect_word) + r'\b',
                    standard_word,
                    result,
                    flags=re.IGNORECASE
                )

    # 4. Chuẩn hóa "X chục" → số (nếu chưa được xử lý)
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
    # ── Hóa đơn TRƯỚC — tránh bị override bởi keyword ngắn như "ăn", "điện" ──
    "Hóa đơn":   [
        "điện lực", "tiền điện", "tiền nước", "evn", "vnpt", "viettel",
        "wifi", "internet", "điện thoại", "electric", "water bill",
        "tiền nhà", "tiền thuê", "gia trị gia tăng", "giá trị gia tăng",
        "hóa đơn điện", "hóa đơn nước",
    ],
    "Thu nhập":  [
        "lương", "thưởng", "freelance", "salary", "income", "bonus",
        "tiền công", "tiền làm",
    ],
    "Ăn uống":   [
        # Dùng cụm từ dài hơn để tránh false positive
        "phở", "cơm", "bún", "bánh mì", "cafe", "cà phê", "trà sữa",
        "nhậu", "lẩu", "pizza", "burger", "sushi", "restaurant", "food",
        "coffee", "bữa ăn", "ăn sáng", "ăn trưa", "ăn tối",
        # Thực phẩm
        "rau muống", "rau cải", "thịt heo", "thịt bò", "thịt gà",
        "rau củ", "trái cây", "hoa quả", "nước mắm", "dầu ăn",
        # Miền Nam
        "hủ tiếu", "cơm tấm", "bún bò",
        # Dialect
        "mần",
    ],
    "Di chuyển": [
        "grab", "xe ôm", "honda ôm", "xích lô", "xe lam", "xe đò",
        "xăng dầu", "petrol", "fuel", "parking", "bãi xe",
        "taxi", "uber", "gojek", "máy bay", "tàu hỏa",
    ],
    "Mua sắm":   [
        "shopee", "lazada", "tiki", "siêu thị", "vinmart", "coopmart", "bigc",
        "quần áo", "giày dép", "mua sắm",
        "kiếm", "chộp",
    ],
    "Giải trí":  [
        "phim", "game", "netflix", "spotify", "cinema", "cgv", "lotte",
        "concert", "karaoke", "coi phim",
    ],
    "Sức khỏe":  [
        "thuốc", "bác sĩ", "khám bệnh", "gym", "pharmacy", "hospital",
        "pharmacity", "guardian", "nhà thuốc",
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
            if prob >= 0.35:  # chỉ tin nếu độ tin cậy >= 35%
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

    # Fallback: hóa đơn điện/nước/viễn thông
    if re.search(r"(?:điện\s*lực|tiền\s*điện|tiền\s*nước|evn|vnpt|viettel|wifi|internet|gia\s*tri\s*gia\s*tang)", lower):
        return "Hóa đơn"

    # Fallback: hóa đơn bán lẻ/chợ
    if re.search(r"bán\s*(?:lẻ|hàng)", lower):
        return "Mua sắm"

    return "Khác"


def extract_amount(text: str) -> float:
    """
    Bóc tách số tiền từ văn bản OCR.
    Ưu tiên theo thứ tự:
      1. Dòng có nhãn tổng (Tổng TT, Tổng cộng, Total, Thành tiền...)
      2. Dòng cuối cùng có số tiền (thường là tổng)
      3. Số lớn nhất trong toàn bộ text
    """
    # ── Bước 1: Tìm dòng có nhãn tổng tiền (ưu tiên cao nhất) ───────────────
    total_patterns = [
        # Tiếng Việt — các biến thể phổ biến trên hóa đơn
        r"t[oổ]ng\s*(?:tt|thanh\s*to[aá]n|ti[eề]n|c[oộ]ng|s[lố])[:\s]*([0-9][0-9,.\s]+)",
        r"(?:th[aà]nh\s*ti[eề]n|t[oổ]ng\s*c[oộ]ng|thanh\s*to[aá]n)[:\s]*([0-9][0-9,.\s]+)",
        r"(?:total|grand\s*total)[:\s]*([0-9][0-9,.\s]+)",
        # Hóa đơn điện/nước — "Số tiền thanh toán" (chấp nhận OCR noise trên dấu)
        r"s[oôố]\s*ti[eêề]n\s*thanh\s*to[aá]n[:\s]*([0-9][0-9,.\s]+)",
        r"ti[eêề]n\s*(?:đi[eêệ]n|n[uưừ][oơớ]c|thanh\s*to[aá]n)[:\s]*([0-9][0-9,.\s]+)",
        r"(?:ph[aả]i\s*tr[aả]|c[aầ]n\s*thanh\s*to[aá]n)[:\s]*([0-9][0-9,.\s]+)",
        # Dòng kết thúc bằng số tiền sau nhãn
        r"t[oổ]ng[^0-9\n]{0,30}([0-9]{1,3}(?:[.,][0-9]{3})+)\s*[đd]?\s*$",
    ]
    for pat in total_patterns:
        m = re.search(pat, text, re.IGNORECASE | re.MULTILINE)
        if m:
            raw = m.group(1).strip().split()[0]  # lấy số đầu tiên, bỏ text thừa
            amount = _parse_number(raw)
            if amount > 0:
                logger.info(f"Tìm thấy tổng tiền (label): {amount} — pattern: {pat[:40]}")
                return amount

    # ── Bước 1b: Tìm số tiền trên dòng NGAY SAU nhãn tổng (OCR tách dòng) ───
    lines = text.split("\n")
    total_label_patterns = [
        r"s[oôố]\s*ti[eêề]n\s*thanh\s*to[aá]n",
        r"t[oổ]ng\s*(?:tt|ti[eêề]n|c[oộ]ng)",
        r"th[aà]nh\s*ti[eêề]n",
    ]
    for i, line in enumerate(lines):
        lower_line = line.lower()
        if any(re.search(p, lower_line) for p in total_label_patterns):
            # Tìm số tiền trên cùng dòng hoặc 2 dòng tiếp theo
            for j in range(i, min(i+3, len(lines))):
                search_line = lines[j]
                # Bỏ qua dòng chứa số điện thoại (1900, 0xxx...)
                if re.search(r"\b1900\b|\b0\d{9}\b", search_line):
                    continue
                # Tìm số có dấu phân cách: 1.611.643 hoặc 1611.643 (OCR mất dấu đầu)
                nums = re.findall(r"\b(\d{1,4}[.,]\d{3}(?:[.,]\d{3})*)\b", search_line)
                for n in nums:
                    amt = _parse_number(n)
                    if amt > 1000:
                        logger.info(f"Tìm thấy tổng tiền (next-line): {amt}")
                        return amt
                # Fallback: số nguyên >= 5 chữ số trên dòng đó
                plain = re.findall(r"\b(\d{5,})\b", search_line)
                for n in plain:
                    if not n.startswith("0") and not n.startswith("1900"):
                        amt = float(n)
                        if amt > 10000:
                            logger.info(f"Tìm thấy tổng tiền (next-line plain): {amt}")
                            return amt

    # ── Bước 2: Tìm số tiền dạng "45k" / "45K" ───────────────────────────────
    k_match = re.search(r"(\d+(?:[.,]\d+)?)\s*[kK]\b", text)
    if k_match:
        amount = float(k_match.group(1).replace(",", ".")) * 1000
        logger.info(f"Tìm thấy số tiền (k): {amount}")
        return amount

    # ── Bước 3: Tìm số tiền dạng "45 nghìn" / "45 ngàn" ─────────────────────
    nghin_match = re.search(r"(\d+)\s*(?:nghìn|nghin|ngàn|ngan)", text, re.IGNORECASE)
    if nghin_match:
        amount = float(nghin_match.group(1)) * 1000
        logger.info(f"Tìm thấy số tiền (nghìn): {amount}")
        return amount

    # ── Bước 4: Tìm số có dấu phân cách — lấy số xuất hiện CUỐI CÙNG ────────
    sep_matches = list(re.finditer(r"\b(\d{1,3}(?:[.,]\d{3})+)\b", text))
    if sep_matches:
        # Lọc bỏ số điện thoại và mã khách hàng
        text_clean = re.sub(r"(?:đt|tel|phone|fax)[:\s]*[\d/\-\s]+", "", text, flags=re.IGNORECASE)
        # Lọc bỏ mã số (thường có chữ lẫn số: pdo1oooo1o383, MST: 0100101114-001)
        text_clean = re.sub(r"\b[a-zA-Z]+\d[\w]*\b", "", text_clean)
        text_clean = re.sub(r"\bMST[:\s]*[\d\-]+", "", text_clean, flags=re.IGNORECASE)
        sep_matches_clean = list(re.finditer(r"\b(\d{1,3}(?:[.,]\d{3})+)\b", text_clean))
        if sep_matches_clean:
            # Lấy số xuất hiện cuối cùng (thường là tổng tiền ở cuối hóa đơn)
            last_match = sep_matches_clean[-1]
            amount = _parse_number(last_match.group(1))
            if amount > 0:
                logger.info(f"Tìm thấy số tiền (cuối cùng): {amount}")
                return amount

    # ── Bước 5: Số nguyên >= 4 chữ số (fallback) ─────────────────────────────
    plain_matches = re.findall(r"\b(\d{4,})\b", text)
    if plain_matches:
        amounts = [float(m) for m in plain_matches if not m.startswith("0")]  # bỏ số bắt đầu bằng 0 (SĐT)
        if amounts:
            best = max(amounts)
            logger.info(f"Tìm thấy số tiền (plain): {best}")
            return best

    return 0.0


def _parse_number(raw: str) -> float:
    """Chuyển chuỗi số có dấu phân cách thành float."""
    raw = raw.strip()
    if "," in raw and "." in raw:
        # 450,000.50 → dấu . là thập phân
        if raw.rfind(".") > raw.rfind(","):
            raw = raw.replace(",", "")
        else:
            # 450.000,50 → dấu , là thập phân
            raw = raw.replace(".", "").replace(",", ".")
    elif "," in raw:
        parts = raw.split(",")
        if len(parts) == 2 and len(parts[1]) == 3:
            raw = raw.replace(",", "")
        else:
            raw = raw.replace(",", ".")
    elif "." in raw:
        parts = raw.split(".")
        # Nhiều dấu chấm: 1.611.643 → 1611643
        if len(parts) > 2:
            raw = raw.replace(".", "")
        # 1 dấu chấm + 3 chữ số sau: 1611.643 hoặc 247.500 → phân nghìn
        elif len(parts) == 2 and len(parts[1]) == 3:
            raw = raw.replace(".", "")
        # 1 dấu chấm + không phải 3 chữ số: 1611.64 → thập phân (giữ nguyên)
    try:
        return float(raw)
    except ValueError:
        return 0.0


def extract_store_name(text: str) -> str:
    """
    Bóc tách tên cửa hàng từ hóa đơn.
    Bỏ qua: số điện thoại, địa chỉ, mã số, dòng chỉ có số.
    """
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    if not lines:
        return "Không rõ"

    # Các pattern cần bỏ qua
    skip_patterns = [
        r"^đt[:\s]",           # ĐT: 0277...
        r"^tel[:\s]",
        r"^phone[:\s]",
        r"^fax[:\s]",
        r"^\d[\d/\-\s]{6,}",   # dòng bắt đầu bằng số dài (SĐT, mã số)
        r"^địa chỉ",
        r"^address",
        r"^mã số thuế",
        r"^mst",
        r"^www\.",
        r"^http",
        r"hóa đơn",            # tiêu đề: HÓA ĐƠN BÁN HÀNG, HÓA ĐƠN BÁN LẺ...
        r"^invoice",
        r"^receipt",
        r"^bill",
        r"^ngày[:\s]",         # Ngày: 08/06/2018
        r"^date[:\s]",
        r"^số hd",             # Số HĐ:
        r"^số hóa đơn",
        r"^nv bán",            # NV bán hàng
        r"^người mua",
        r"^khách hàng",
        r"^mã kh",
        r"^thu ngân",          # Thu ngân:
        r"^cashier",
        r"^bán lẻ",
        r"^bán hàng",
        r"^cảm ơn",            # Cảm ơn quý khách
        r"^thank",
        r"^viết bằng chữ",     # Viết bằng chữ: Hai mươi...
    ]

    # Ưu tiên: tìm tên cửa hàng ở TRƯỚC dòng "HÓA ĐƠN" (nếu có)
    hoadon_idx = None
    for i, line in enumerate(lines[:15]):
        if re.search(r"hóa đơn", line.lower()):
            hoadon_idx = i
            break

    # Nếu có dòng "HÓA ĐƠN", tìm tên cửa hàng trong các dòng trước đó
    if hoadon_idx and hoadon_idx > 0:
        for line in lines[:hoadon_idx]:
            lower = line.lower()
            if any(re.search(p, lower) for p in skip_patterns):
                continue
            if re.match(r'^[A-Z0-9]{4,}$', line.strip()):
                continue
            if re.search(r"[a-zA-ZÀ-ỹ]", line) and 3 <= len(line) <= 80:
                return line[:60]

    # Fallback: tìm trong 10 dòng đầu
    for line in lines[:10]:
        lower = line.lower()
        if any(re.search(p, lower) for p in skip_patterns):
            continue
        if re.match(r'^[A-Z0-9]{4,}$', line.strip()):
            continue
        if re.search(r"[a-zA-ZÀ-ỹ]", line) and 3 <= len(line) <= 80:
            return line[:60]

    return "Không rõ"


def extract_date(text: str) -> str:
    """
    Bóc tách ngày từ văn bản OCR.
    Ưu tiên: ngày lập hóa đơn / hạn thanh toán → ngày có nhãn → pattern chung.
    """
    # ── Ưu tiên 1: Hạn thanh toán (hóa đơn điện/nước) ───────────────────────
    han_tt = re.search(
        r"h[aạ][nṇ]\s*thanh\s*to[aá]n[:\s]+(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
        text, re.IGNORECASE
    )
    if han_tt:
        raw = han_tt.group(1)
        m = re.match(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", raw)
        if m:
            d, mo, y = m.groups()
            if len(y) == 2: y = "20" + y
            return f"{d.zfill(2)}/{mo.zfill(2)}/{y}"

    # ── Ưu tiên 2: Ngày lập / Ngày xuất hóa đơn ─────────────────────────────
    labeled = re.search(
        r"(?:ng[aà]y\s*(?:mua|l[aậ]p|xu[aấ]t|h[oó]a\s*đ[oơ]n)?|date)[:\s]+(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
        text, re.IGNORECASE
    )
    if labeled:
        raw = labeled.group(1)
        m = re.match(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", raw)
        if m:
            d, mo, y = m.groups()
            if len(y) == 2: y = "20" + y
            return f"{d.zfill(2)}/{mo.zfill(2)}/{y}"

    # ── Ưu tiên 3: Kỳ hóa đơn dạng "tháng M/YYYY" ───────────────────────────
    ky = re.search(r"k[yỳ]\s*h[oó]a\s*đ[oơ]n[:\s]+th[aá]ng\s*(\d{1,2})[/\-.](\d{4})", text, re.IGNORECASE)
    if ky:
        mo, y = ky.groups()
        return f"01/{mo.zfill(2)}/{y}"

    # ── Ưu tiên 4: pattern ngày thông thường ─────────────────────────────────
    date_patterns = [
        r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})",   # dd/mm/yyyy
        r"(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})",   # yyyy-mm-dd
        r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})",   # dd/mm/yy
    ]
    for pat in date_patterns:
        m = re.search(pat, text)
        if m:
            groups = m.groups()
            if len(groups[0]) == 4:  # yyyy-mm-dd
                return f"{groups[2].zfill(2)}/{groups[1].zfill(2)}/{groups[0]}"
            y = groups[2]
            if len(y) == 2:
                y = "20" + y
            return f"{groups[0].zfill(2)}/{groups[1].zfill(2)}/{y}"

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
    return {
        "status": "ok",
        "service": "SmartPrice AI Engine",
        "version": "1.0.0",
        "dialect_entries": len(_EXTENDED_DIALECT_MAP),
        "dialect_source": "CentralVietnamDataset + hardcoded",
    }


@app.get("/dialect/stats")
def dialect_stats():
    """Thống kê dialect map đang dùng."""
    return {
        "hardcoded_entries": len(DIALECT_WORD_MAP),
        "extended_entries":  len(_EXTENDED_DIALECT_MAP),
        "total":             len(DIALECT_WORD_MAP) + len(_EXTENDED_DIALECT_MAP),
        "number_patterns":   len(DIALECT_NUMBER_MAP),
    }


@app.post("/dialect/normalize")
def dialect_normalize_endpoint(req: TextParseRequest):
    """
    Test endpoint: chuẩn hóa từ địa phương.
    Input:  { "text": "Mần cái bánh mỳ hết hăm lăm ngàn" }
    Output: { "original": "...", "normalized": "...", "changed": true }
    """
    original   = req.text.strip()
    normalized = normalize_dialect(original)
    return {
        "original":   original,
        "normalized": normalized,
        "changed":    normalized != original.lower(),
    }


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
    # Validate file type — chấp nhận image/* và octet-stream (C# có thể gửi không có MIME)
    if image.content_type and not (
        image.content_type.startswith("image/") or
        image.content_type == "application/octet-stream"
    ):
        raise HTTPException(status_code=400, detail="File phải là ảnh (jpg/png/webp).")

    # Đọc ảnh
    contents = await image.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File ảnh rỗng.")

    try:
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")

        # ── Tiền xử lý ảnh để OCR chính xác hơn ─────────────────────────────
        import cv2
        img_cv = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

        # 1. Upscale nếu ảnh quá nhỏ — dùng INTER_CUBIC (sắc nét hơn LANCZOS cho text)
        h_orig, w_orig = img_cv.shape[:2]
        MIN_WIDTH = 1000
        if w_orig < MIN_WIDTH:
            scale = MIN_WIDTH / w_orig
            new_w = int(w_orig * scale)
            new_h = int(h_orig * scale)
            img_cv = cv2.resize(img_cv, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
            logger.info(f"Upscaled: {w_orig}×{h_orig} → {new_w}×{new_h}")

        # 2. Chuyển grayscale
        gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)

        # 3. Tăng độ tương phản (CLAHE)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)

        # 4. Sharpen để chữ sắc nét hơn
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        sharpened = cv2.filter2D(enhanced, -1, kernel)

        # 5. Chuyển lại RGB để EasyOCR xử lý
        img_array = cv2.cvtColor(sharpened, cv2.COLOR_GRAY2RGB)
        logger.info(f"Preprocessed image: {img_array.shape}")

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
        return {
            "status":      "failed",
            "store":       "Không rõ",
            "total":       0,
            "date":        datetime.now().strftime("%d/%m/%Y"),
            "category":    "Khác",
            "confidence":  0.0,
            "invoice_id":  "",
            "raw_text":    "",
            "fail_reason": "no_text",
            "suggestions": [
                "Ảnh không chứa chữ nào có thể đọc được",
                "Hãy chụp gần hơn và đảm bảo hóa đơn nằm trong khung",
                "Bật đèn flash nếu thiếu sáng",
            ],
        }

    # Ghép toàn bộ text từ OCR
    full_text = "\n".join([item[1] for item in ocr_results])
    avg_confidence = sum(item[2] for item in ocr_results) / len(ocr_results)

    logger.info(f"Full OCR text:\n{full_text}")
    logger.info(f"Avg confidence: {avg_confidence:.2f}")

    # ── Đánh giá chất lượng ảnh ──────────────────────────────────────────────
    # Tỷ lệ ký tự hợp lệ (chữ, số, dấu câu thông thường)
    valid_chars = sum(1 for c in full_text if c.isalnum() or c in ' .,:-/\n()đĐ')
    sanity_score = valid_chars / max(len(full_text), 1)

    # Bóc tách thông tin
    store    = extract_store_name(full_text)
    total    = extract_amount(full_text)
    date     = extract_date(full_text)
    category = detect_category(full_text)

    # ── Xác định trạng thái kết quả ──────────────────────────────────────────
    has_amount = total > 0

    if avg_confidence >= 0.75 and has_amount and sanity_score >= 0.65:
        status = "success"
        suggestions = []
    elif avg_confidence >= 0.45 and sanity_score >= 0.45:
        # Đọc được nhưng không chắc chắn
        status = "low_confidence"
        suggestions = []
        if not has_amount:
            suggestions.append("Không tìm thấy số tiền — hãy đảm bảo dòng 'Tổng' hoặc 'Total' nằm trong khung")
        if avg_confidence < 0.6:
            suggestions.append("Chữ hơi mờ — thử chụp gần hơn hoặc bật đèn flash")
        if sanity_score < 0.6:
            suggestions.append("Ảnh có nhiều nhiễu — đặt hóa đơn phẳng, tránh bóng đổ")
    else:
        # Chất lượng quá thấp
        status = "failed"
        fail_reason = "low_quality" if sanity_score < 0.45 else "no_amount"
        suggestions = _build_suggestions(avg_confidence, sanity_score, has_amount)
        logger.warning(f"OCR failed: conf={avg_confidence:.2f}, sanity={sanity_score:.2f}, amount={total}")
        return {
            "status":      status,
            "store":       store or "Không rõ",
            "total":       0,
            "date":        date,
            "category":    category,
            "confidence":  round(avg_confidence, 2),
            "invoice_id":  "",
            "raw_text":    full_text[:300],
            "fail_reason": fail_reason,
            "suggestions": suggestions,
        }

    result = {
        "status":      status,
        "store":       store,
        "total":       total,
        "date":        date,
        "category":    category,
        "confidence":  round(avg_confidence, 2),
        "invoice_id":  f"INV-{datetime.now().strftime('%Y%m%d')}-{hash(full_text) % 9000 + 1000}",
        "raw_text":    full_text[:500],
        "suggestions": suggestions,
    }

    logger.info(f"OCR result: {result}")
    return result


def _build_suggestions(confidence: float, sanity: float, has_amount: bool) -> list:
    """Tạo gợi ý cụ thể dựa trên nguyên nhân thất bại."""
    tips = []
    if confidence < 0.4:
        tips.append("Ảnh quá mờ hoặc thiếu sáng — bật đèn flash và chụp lại")
    if sanity < 0.4:
        tips.append("Ảnh bị nhiễu nhiều — đặt hóa đơn phẳng trên nền sáng")
    if not has_amount:
        tips.append("Không tìm thấy số tiền — đảm bảo dòng 'Tổng cộng' nằm trong khung quét")
    tips.append("Giữ điện thoại thẳng, cách hóa đơn 15–25 cm")
    tips.append("Chức năng OCR hoạt động tốt nhất với hóa đơn in máy (không hỗ trợ chữ viết tay)")
    return tips
