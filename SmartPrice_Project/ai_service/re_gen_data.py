"""
Tạo dataset NLP chất lượng cho SmartPrice.
Chạy: python re_gen_data.py
Kết quả: ../datasets/nlp_train.txt
"""

import random, os, json

random.seed(42)

CATEGORIES = {
    "Ăn uống": [
        # Phổ thông
        "ăn phở", "uống cafe", "mua trà sữa", "ăn cơm", "ăn bún bò",
        "ăn bánh mì", "mua đồ ăn sáng", "ăn tối với gia đình", "order grab food",
        "ăn lẩu", "uống sinh tố", "mua bánh ngọt", "ăn bún riêu",
        "uống nước mía", "ăn hủ tiếu", "mua cà phê sữa đá",
        "ăn cơm tấm sườn", "order pizza", "ăn burger", "mua sushi",
        # Miền Nam
        "nhậu với bạn bè", "kiếm cái ăn", "ăn cơm bình dân",
        "uống cà phê vợt", "ăn bánh xèo",
        # Miền Trung
        "mần cái bánh", "ăn bún thịt nướng", "uống chè",
        # Miền Bắc
        "ăn bát bún mọc", "uống bia hơi",
    ],
    "Di chuyển": [
        "đổ xăng xe máy", "đi grab", "đi taxi", "mua vé bus",
        "đi xe ôm", "đặt be", "thuê xe tự lái", "mua vé tàu",
        "đi máy bay", "gửi xe", "sửa xe", "thay lốp xe",
        "đi gojek", "mua vé xe khách", "đổ xăng ô tô",
        "đặt grab bike", "đi xích lô", "mua vé metro",
        # Vùng miền
        "đi honda ôm", "thuê xe lam", "đi xe đò",
    ],
    "Mua sắm": [
        "mua quần áo", "mua giày", "mua túi xách", "mua sắm shopee",
        "mua đồ lazada", "đi siêu thị", "mua đồ vinmart",
        "mua điện thoại", "mua laptop", "mua tai nghe",
        "mua mỹ phẩm", "mua đồ dùng nhà bếp", "mua sách",
        "mua đồ chơi cho con", "mua quà tặng", "đi chợ",
        "mua rau củ quả", "mua thịt cá", "mua đồ gia dụng",
        # Vùng miền
        "kiếm cái áo mới", "chộp đôi giày",
    ],
    "Giải trí": [
        "xem phim cgv", "chơi game", "đăng ký netflix",
        "mua vé concert", "đi karaoke", "mua vé xem bóng đá",
        "đăng ký spotify", "mua sách truyện", "đi du lịch",
        "chơi bowling", "đi công viên", "xem phim rạp",
        "mua vé lotte cinema", "đi chơi escape room",
        "mua thẻ game", "nạp game",
        # Vùng miền
        "coi phim với bạn",
    ],
    "Sức khỏe": [
        "mua thuốc", "khám bác sĩ", "đi gym", "mua vitamin",
        "khám răng", "mua kính", "đi spa", "mua thực phẩm chức năng",
        "cắt tóc", "mua dầu gội", "đăng ký yoga",
        "mua băng cứu thương", "tiêm vaccine", "khám tổng quát",
        "mua thuốc cảm cúm", "đặt khám online",
    ],
    "Hóa đơn": [
        "trả tiền điện", "trả tiền nước", "nạp internet",
        "trả tiền điện thoại", "trả tiền thuê nhà",
        "nạp wifi", "trả tiền gas", "trả phí dịch vụ chung cư",
        "đóng học phí", "trả tiền gửi xe tháng",
        "nạp tiền điện thoại", "mua thẻ điện thoại",
        "trả hóa đơn điện lực", "đóng bảo hiểm",
    ],
    "Thu nhập": [
        "nhận lương tháng", "nhận thưởng tết", "nhận tiền freelance",
        "bán hàng online", "nhận tiền làm thêm",
        "nhận tiền trợ cấp", "nhận hoa hồng bán hàng",
        "chuyển tiền vào tài khoản",
    ],
}

AMOUNT_TEMPLATES = [
    "{amount}đ", "{amount} đồng", "{amount}k", "hết {amount}",
    "mất {amount}", "tốn {amount}", "chi {amount}",
    "trả {amount}", "thanh toán {amount}",
]

TIME_TEMPLATES = [
    "hôm nay", "sáng nay", "trưa nay", "tối nay", "chiều nay",
    "hôm qua", "tuần này", "tháng này", "",
]

SENTENCE_TEMPLATES = [
    "{time} {action} hết {amount}k",
    "{time} {action} {amount}k",
    "{action} {amount}k {time}",
    "{action} tốn {amount}k",
    "vừa {action} hết {amount}k",
    "chi {amount}k cho {action}",
    "mất {amount}k {action}",
    "{action} {amount}.000đ",
    "{action} {amount}k hôm nay",
    "{time} chi {amount}k {action}",
    "{action} mất {amount}.000 đồng",
    "thanh toán {action} {amount}k",
    "{action} {amount}",
]

def rand_amount():
    """Tạo số tiền ngẫu nhiên thực tế."""
    buckets = [
        (10, 100, 5),     # 10k-100k, bội 5k
        (100, 500, 10),   # 100k-500k, bội 10k
        (500, 2000, 50),  # 500k-2M, bội 50k
    ]
    bmin, bmax, step = random.choice(buckets)
    n = random.randrange(bmin, bmax, step)
    return n

def make_sentence(category, action, amount):
    tpl = random.choice(SENTENCE_TEMPLATES)
    time = random.choice(TIME_TEMPLATES)
    s = tpl.format(action=action, amount=amount, time=time)
    # Dọn khoảng trắng thừa
    s = " ".join(s.split()).strip()
    return s

def generate():
    records = []

    def remove_accents(s):
        """Tạo phiên bản không dấu để augment dataset."""
        import unicodedata
        nfkd = unicodedata.normalize('NFKD', s)
        return ''.join(c for c in nfkd if not unicodedata.combining(c))

    for cat, actions in CATEGORIES.items():
        target = 50
        per_action = max(1, target // len(actions))
        for action in actions:
            for _ in range(per_action):
                amount = rand_amount()
                sentence = make_sentence(cat, action, amount)
                records.append({
                    "text": sentence,
                    "category": cat,
                    "item": action,
                    "amount": amount * 1000 if amount < 10000 else amount,
                })
                # Augment: thêm phiên bản không dấu (50% xác suất)
                if random.random() < 0.5:
                    no_accent = remove_accents(sentence)
                    if no_accent != sentence:
                        records.append({
                            "text": no_accent,
                            "category": cat,
                            "item": action,
                            "amount": amount * 1000 if amount < 10000 else amount,
                        })

    random.shuffle(records)
    return records

def save_txt(records, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(f"{r['text']} | item: {r['item']}, price: {r['amount']}\n")
    print(f"✅ Đã lưu {len(records)} câu → {path}")

def save_json(records, path):
    data = {
        "metadata": {
            "total_records": len(records),
            "categories": list(CATEGORIES.keys()),
            "description": "Auto-generated training data for SmartPrice NLP",
        },
        "data": [
            {
                "id": i+1,
                "raw_text": r["text"],
                "intent": "add_transaction",
                "entities": {
                    "item": r["item"],
                    "price": r["amount"],
                    "category": r["category"],
                }
            }
            for i, r in enumerate(records)
        ],
        "category_mapping": {
            action: cat
            for cat, actions in CATEGORIES.items()
            for action in actions
        }
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✅ Đã lưu JSON → {path}")

if __name__ == "__main__":
    records = generate()
    save_txt(records, "../datasets/nlp_train.txt")
    save_json(records, "../datasets/nlp_data.json")
    print(f"\n📊 Tổng: {len(records)} câu")
    print("   Phân bố:")
    from collections import Counter
    c = Counter(r["category"] for r in records)
    for cat, n in sorted(c.items()):
        print(f"   {cat}: {n} câu")
