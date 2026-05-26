"""
Script tích hợp CentralVietnamDataset vào DIALECT_WORD_MAP.
Đọc words.csv + sentences.csv → tạo dialect_extended.json

Chạy:
    cd ai_service
    python build_dialect_map.py
"""

import csv
import json
import os
import re

WORDS_CSV     = "CentralVietnamDataset/words.csv"
SENTENCES_CSV = "CentralVietnamDataset/sentences.csv"
OUTPUT_JSON   = "dialect_extended.json"

# Từ khóa tài chính — chỉ giữ lại từ liên quan đến chi tiêu/tiền bạc
FINANCE_RELATED_STANDARD = {
    # Động từ
    "ăn", "uống", "mua", "bán", "trả", "lấy", "đi", "về", "làm",
    "xài", "dùng", "tiêu", "kiếm", "nhận", "gửi", "rút", "nạp",
    # Danh từ tài chính
    "tiền", "đồng", "nghìn", "triệu", "tỷ", "xu",
    "chợ", "cửa hàng", "siêu thị", "nhà hàng", "quán",
    "xe", "xăng", "thuốc", "điện", "nước",
    # Thời gian
    "hôm nay", "hôm qua", "sáng", "trưa", "tối", "chiều",
    "tuần", "tháng", "năm",
    # Số đếm
    "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín", "mười",
    "mươi", "trăm", "nghìn", "ngàn", "chục",
}


def is_finance_relevant(standard_word: str) -> bool:
    """Kiểm tra từ phổ thông có liên quan đến tài chính không."""
    sw = standard_word.lower().strip()
    # Kiểm tra trực tiếp
    if sw in FINANCE_RELATED_STANDARD:
        return True
    # Kiểm tra chứa từ khóa
    for kw in FINANCE_RELATED_STANDARD:
        if kw in sw:
            return True
    return False


def clean_word(w: str) -> str:
    """Làm sạch từ: bỏ dấu câu thừa, khoảng trắng."""
    w = w.strip()
    w = re.sub(r'[?!.,;:()\[\]{}"\']', '', w)
    w = re.sub(r'\s+', ' ', w).strip()
    return w.lower()


def load_csv_map(filepath: str) -> dict:
    """Đọc CSV 2 cột: dialect,standard → dict."""
    result = {}
    if not os.path.exists(filepath):
        print(f"⚠️  Không tìm thấy: {filepath}")
        return result

    with open(filepath, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or ',' not in line:
                continue
            # Tách tại dấu phẩy đầu tiên
            idx = line.index(',')
            dialect  = clean_word(line[:idx])
            standard = clean_word(line[idx+1:])

            if dialect and standard and dialect != standard:
                result[dialect] = standard

    return result


def build_extended_map():
    print("=" * 50)
    print("  SmartPrice Dialect Map Builder")
    print("=" * 50)

    # 1. Load từ cả 2 file
    words_map     = load_csv_map(WORDS_CSV)
    sentences_map = load_csv_map(SENTENCES_CSV)

    print(f"\n📂 words.csv:     {len(words_map)} entries")
    print(f"📂 sentences.csv: {len(sentences_map)} entries")

    # 2. Merge (sentences_map ưu tiên vì ngắn gọn hơn)
    merged = {**words_map, **sentences_map}
    print(f"📊 Sau merge:     {len(merged)} entries")

    # 3. Lọc: chỉ giữ từ đơn (1-3 từ) để tránh match sai
    filtered = {}
    for dialect, standard in merged.items():
        word_count = len(dialect.split())
        if 1 <= word_count <= 3:
            filtered[dialect] = standard

    print(f"🔍 Sau lọc độ dài: {len(filtered)} entries")

    # 4. Tách thành 2 nhóm: tài chính và tổng quát
    finance_map = {}
    general_map = {}
    for dialect, standard in filtered.items():
        if is_finance_relevant(standard):
            finance_map[dialect] = standard
        else:
            general_map[dialect] = standard

    print(f"💰 Liên quan tài chính: {len(finance_map)} entries")
    print(f"📝 Tổng quát:           {len(general_map)} entries")

    # 5. Lưu JSON
    output = {
        "metadata": {
            "source": "CentralVietnamDataset (github.com/trituenhantaoio)",
            "total_entries": len(filtered),
            "finance_entries": len(finance_map),
            "general_entries": len(general_map),
        },
        "finance_dialect_map": finance_map,
        "general_dialect_map": general_map,
        "all_dialect_map": filtered,
    }

    with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Đã lưu: {OUTPUT_JSON}")

    # 6. Preview
    print("\n📋 Mẫu từ tài chính:")
    for i, (d, s) in enumerate(list(finance_map.items())[:10]):
        print(f"   '{d}' → '{s}'")

    print("\n📋 Mẫu từ tổng quát:")
    for i, (d, s) in enumerate(list(general_map.items())[:10]):
        print(f"   '{d}' → '{s}'")

    return filtered


if __name__ == "__main__":
    build_extended_map()
    print("\n✅ Hoàn tất! Chạy main.py để dùng dialect map mở rộng.")
