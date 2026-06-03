"""
Script train model NLP phân loại hạng mục chi tiêu.

Bước 1 — Tạo dữ liệu (nếu chưa có):
    python re_gen_data.py

Bước 2 — Train model:
    python train_nlp.py

Kết quả: nlp_model.pkl (~200KB) — main.py tự load khi khởi động.
"""

import os
import json
import pickle
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, accuracy_score
import numpy as np

# ── Đường dẫn ─────────────────────────────────────────────────────────────────
DATA_JSON = os.path.join("..", "datasets", "nlp_data.json")
DATA_TXT  = os.path.join("..", "datasets", "nlp_train.txt")
MODEL_OUT = "nlp_model.pkl"


def load_from_json(path: str):
    """Load từ nlp_data.json (format mới)."""
    texts, labels = [], []
    if not os.path.exists(path):
        return texts, labels

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    for item in data.get("data", []):
        text = item.get("raw_text", "").strip()
        cat  = item.get("entities", {}).get("category", "").strip()
        if text and cat and cat != "Khác":
            texts.append(text)
            labels.append(cat)

    print(f"📂 Đọc từ JSON: {len(texts)} câu")
    return texts, labels


def load_from_txt(path: str):
    """Load từ nlp_train.txt (format: câu | item: X, price: Y)."""
    texts, labels = [], []

    ITEM_TO_CAT = {
        # Ăn uống
        "ăn phở": "Ăn uống", "uống cafe": "Ăn uống", "mua trà sữa": "Ăn uống",
        "ăn cơm": "Ăn uống", "ăn bún bò": "Ăn uống", "ăn bánh mì": "Ăn uống",
        "mua đồ ăn sáng": "Ăn uống", "order grab food": "Ăn uống",
        "ăn lẩu": "Ăn uống", "uống sinh tố": "Ăn uống", "mua bánh ngọt": "Ăn uống",
        "ăn bún riêu": "Ăn uống", "uống nước mía": "Ăn uống",
        "ăn hủ tiếu": "Ăn uống", "mua cà phê sữa đá": "Ăn uống",
        "ăn cơm tấm sườn": "Ăn uống", "order pizza": "Ăn uống",
        "ăn burger": "Ăn uống", "mua sushi": "Ăn uống",
        "nhậu với bạn bè": "Ăn uống", "kiếm cái ăn": "Ăn uống",
        "ăn cơm bình dân": "Ăn uống", "uống cà phê vợt": "Ăn uống",
        "ăn bánh xèo": "Ăn uống", "mần cái bánh": "Ăn uống",
        "ăn bún thịt nướng": "Ăn uống", "uống chè": "Ăn uống",
        "ăn bát bún mọc": "Ăn uống", "uống bia hơi": "Ăn uống",
        "ăn tối với gia đình": "Ăn uống",
        # Di chuyển
        "đổ xăng xe máy": "Di chuyển", "đi grab": "Di chuyển",
        "đi taxi": "Di chuyển", "mua vé bus": "Di chuyển",
        "đi xe ôm": "Di chuyển", "đặt be": "Di chuyển",
        "thuê xe tự lái": "Di chuyển", "mua vé tàu": "Di chuyển",
        "đi máy bay": "Di chuyển", "gửi xe": "Di chuyển",
        "sửa xe": "Di chuyển", "thay lốp xe": "Di chuyển",
        "đi gojek": "Di chuyển", "mua vé xe khách": "Di chuyển",
        "đổ xăng ô tô": "Di chuyển", "đặt grab bike": "Di chuyển",
        "đi xích lô": "Di chuyển", "mua vé metro": "Di chuyển",
        "đi honda ôm": "Di chuyển", "thuê xe lam": "Di chuyển",
        "đi xe đò": "Di chuyển",
        # Mua sắm
        "mua quần áo": "Mua sắm", "mua giày": "Mua sắm",
        "mua túi xách": "Mua sắm", "mua sắm shopee": "Mua sắm",
        "mua đồ lazada": "Mua sắm", "đi siêu thị": "Mua sắm",
        "mua đồ vinmart": "Mua sắm", "mua điện thoại": "Mua sắm",
        "mua laptop": "Mua sắm", "mua tai nghe": "Mua sắm",
        "mua mỹ phẩm": "Mua sắm", "mua đồ dùng nhà bếp": "Mua sắm",
        "mua sách": "Mua sắm", "mua đồ chơi cho con": "Mua sắm",
        "mua quà tặng": "Mua sắm", "đi chợ": "Mua sắm",
        "mua rau củ quả": "Mua sắm", "mua thịt cá": "Mua sắm",
        "mua đồ gia dụng": "Mua sắm", "kiếm cái áo mới": "Mua sắm",
        "chộp đôi giày": "Mua sắm",
        # Giải trí
        "xem phim cgv": "Giải trí", "chơi game": "Giải trí",
        "đăng ký netflix": "Giải trí", "mua vé concert": "Giải trí",
        "đi karaoke": "Giải trí", "mua vé xem bóng đá": "Giải trí",
        "đăng ký spotify": "Giải trí", "mua sách truyện": "Giải trí",
        "đi du lịch": "Giải trí", "chơi bowling": "Giải trí",
        "đi công viên": "Giải trí", "xem phim rạp": "Giải trí",
        "mua vé lotte cinema": "Giải trí", "đi chơi escape room": "Giải trí",
        "mua thẻ game": "Giải trí", "nạp game": "Giải trí",
        "coi phim với bạn": "Giải trí",
        # Sức khỏe
        "mua thuốc": "Sức khỏe", "khám bác sĩ": "Sức khỏe",
        "đi gym": "Sức khỏe", "mua vitamin": "Sức khỏe",
        "khám răng": "Sức khỏe", "mua kính": "Sức khỏe",
        "đi spa": "Sức khỏe", "mua thực phẩm chức năng": "Sức khỏe",
        "cắt tóc": "Sức khỏe", "mua dầu gội": "Sức khỏe",
        "đăng ký yoga": "Sức khỏe", "mua băng cứu thương": "Sức khỏe",
        "tiêm vaccine": "Sức khỏe", "khám tổng quát": "Sức khỏe",
        "mua thuốc cảm cúm": "Sức khỏe", "đặt khám online": "Sức khỏe",
        # Hóa đơn
        "trả tiền điện": "Hóa đơn", "trả tiền nước": "Hóa đơn",
        "nạp internet": "Hóa đơn", "trả tiền điện thoại": "Hóa đơn",
        "trả tiền thuê nhà": "Hóa đơn", "nạp wifi": "Hóa đơn",
        "trả tiền gas": "Hóa đơn", "trả phí dịch vụ chung cư": "Hóa đơn",
        "đóng học phí": "Hóa đơn", "trả tiền gửi xe tháng": "Hóa đơn",
        "nạp tiền điện thoại": "Hóa đơn", "mua thẻ điện thoại": "Hóa đơn",
        "trả hóa đơn điện lực": "Hóa đơn", "đóng bảo hiểm": "Hóa đơn",
        # Thu nhập
        "nhận lương tháng": "Thu nhập", "nhận thưởng tết": "Thu nhập",
        "nhận tiền freelance": "Thu nhập", "bán hàng online": "Thu nhập",
        "nhận tiền làm thêm": "Thu nhập", "nhận tiền trợ cấp": "Thu nhập",
        "nhận hoa hồng bán hàng": "Thu nhập",
        "chuyển tiền vào tài khoản": "Thu nhập",
        # Legacy
        "trà sữa": "Ăn uống", "cafe": "Ăn uống", "cơm tấm": "Ăn uống",
        "sửa xe": "Di chuyển", "đổ xăng": "Di chuyển",
        "mua áo": "Mua sắm", "tiền điện": "Hóa đơn",
    }

    if not os.path.exists(path):
        return texts, labels

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("|")
            sentence = parts[0].strip()
            if len(parts) >= 2:
                meta = parts[1]
                item = ""
                for seg in meta.split(","):
                    if "item:" in seg:
                        item = seg.split("item:")[-1].strip()
                        break
                category = ITEM_TO_CAT.get(item)
                if category:
                    texts.append(sentence)
                    labels.append(category)

    print(f"📂 Đọc từ TXT: {len(texts)} câu")
    return texts, labels


def train(texts, labels):
    from collections import Counter
    dist = Counter(labels)
    print(f"\n📊 Dữ liệu: {len(texts)} câu, {len(dist)} hạng mục")
    for cat, n in sorted(dist.items()):
        print(f"   {cat}: {n}")

    if len(texts) < 20:
        print("❌ Cần ít nhất 20 câu để train!")
        return None, None

    # Chia train/test 80/20
    X_train, X_test, y_train, y_test = train_test_split(
        texts, labels, test_size=0.2, random_state=42,
        stratify=labels if min(dist.values()) >= 2 else None
    )

    # TF-IDF dùng cả word và char ngram
    vectorizer = TfidfVectorizer(
        analyzer="char_wb",
        ngram_range=(2, 5),
        max_features=8000,
        sublinear_tf=True,
        min_df=1,
    )
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec  = vectorizer.transform(X_test)

    # Train Logistic Regression — thường tốt hơn Naive Bayes cho text tiếng Việt
    print("\n🤖 Train Logistic Regression...")
    clf = LogisticRegression(
        max_iter=1000,
        C=5.0,
        solver="lbfgs",
    )
    clf.fit(X_train_vec, y_train)

    # Đánh giá
    y_pred = clf.predict(X_test_vec)
    acc = accuracy_score(y_test, y_pred)
    print(f"\n✅ Accuracy trên test set: {acc*100:.1f}%")

    # Cross-validation
    scores = cross_val_score(clf, vectorizer.transform(texts), labels, cv=5)
    print(f"✅ Cross-validation (5-fold): {scores.mean()*100:.1f}% ± {scores.std()*100:.1f}%")

    print("\n📈 Chi tiết từng hạng mục:")
    print(classification_report(y_test, y_pred))

    return vectorizer, clf


def test_model(vectorizer, clf):
    test_cases = [
        ("Hôm nay ăn phở bò hết 50k",         "Ăn uống"),
        ("Đổ xăng xe máy 80 nghìn",             "Di chuyển"),
        ("Mua áo mới shopee 200k",               "Mua sắm"),
        ("Tiền điện tháng này 150k",             "Hóa đơn"),
        ("Uống cafe sáng 35k",                   "Ăn uống"),
        ("Sửa xe đạp 45k",                       "Di chuyển"),
        ("Mua trà sữa 65k",                      "Ăn uống"),
        ("Xem phim cgv với bạn 100k",            "Giải trí"),
        ("Khám bác sĩ hết 200k",                 "Sức khỏe"),
        ("Nhận lương tháng này 8 triệu",         "Thu nhập"),
        ("Sáng nay uống cà phê hết hăm lăm ngàn", "Ăn uống"),
        ("Đi xe ôm hết hai chục",                "Di chuyển"),
        ("Mần cái bánh mỳ mười lăm ngàn",        "Ăn uống"),
    ]

    print("\n🧪 Test model với câu thực tế:")
    print("-" * 60)
    correct = 0
    for text, expected in test_cases:
        vec = vectorizer.transform([text])
        pred = clf.predict(vec)[0]
        proba = clf.predict_proba(vec).max()
        ok = "✅" if pred == expected else "❌"
        if pred == expected:
            correct += 1
        print(f"  {ok} '{text}'")
        print(f"     → {pred} ({proba*100:.0f}%) | expected: {expected}\n")

    print(f"Tổng đúng: {correct}/{len(test_cases)} ({correct/len(test_cases)*100:.0f}%)")


if __name__ == "__main__":
    print("=" * 60)
    print("  SmartPrice NLP Model Trainer v2")
    print("=" * 60)

    # Ưu tiên load từ JSON (dataset mới)
    texts, labels = load_from_json(DATA_JSON)

    # Fallback txt nếu JSON không đủ
    if len(texts) < 50:
        t2, l2 = load_from_txt(DATA_TXT)
        texts += t2
        labels += l2

    if not texts:
        print("❌ Không có dữ liệu! Hãy chạy: python re_gen_data.py trước")
        exit(1)

    # Train
    vectorizer, clf = train(texts, labels)
    if vectorizer is None:
        exit(1)

    # Lưu model
    with open(MODEL_OUT, "wb") as f:
        pickle.dump({"vectorizer": vectorizer, "clf": clf}, f)
    size_kb = os.path.getsize(MODEL_OUT) / 1024
    print(f"\n💾 Model lưu: {MODEL_OUT} ({size_kb:.0f} KB)")

    # Test
    test_model(vectorizer, clf)

    print("\n✅ Xong! Restart AI Engine để dùng model mới.")
    print("   python -m uvicorn main:app --host 0.0.0.0 --port 8000")
