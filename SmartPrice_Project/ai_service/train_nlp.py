"""
Script train model NLP phân loại hạng mục chi tiêu.
Dùng dữ liệu từ datasets/nlp_train.txt (1000 câu tiếng Việt).

Chạy 1 lần để tạo model:
    cd ai_service
    python train_nlp.py

Sau khi train xong, file nlp_model.pkl sẽ được tạo ra.
main.py sẽ tự động load model này thay vì dùng keyword dict.
"""

import os
import pickle
import json
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score

# ── Đường dẫn ─────────────────────────────────────────────────────────────────
DATA_TXT  = os.path.join("..", "datasets", "nlp_train.txt")
DATA_JSON = os.path.join("..", "datasets", "nlp_data.json")
MODEL_OUT = "nlp_model.pkl"

# ── Map item → category (từ nlp_data.json) ────────────────────────────────────
ITEM_TO_CATEGORY = {
    "trà sữa":    "Ăn uống",
    "cafe":       "Ăn uống",
    "cơm tấm":    "Ăn uống",
    "sửa xe":     "Di chuyển",
    "đổ xăng":    "Di chuyển",
    "mua áo":     "Mua sắm",
    "tiền điện":  "Hóa đơn",
}


def load_data_from_txt(path: str):
    """
    Đọc nlp_train.txt — mỗi dòng có dạng:
    "Hôm nay ăn phở hết 50k | item: phở, price: 50000"
    """
    texts, labels = [], []

    if not os.path.exists(path):
        print(f"❌ Không tìm thấy file: {path}")
        return texts, labels

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            parts = line.split("|")
            if len(parts) < 2:
                continue

            sentence = parts[0].strip()

            # Lấy item từ phần sau dấu |
            # Ví dụ: "item: trà sữa, price: 215000"
            meta = parts[1].strip()
            item = ""
            for seg in meta.split(","):
                if "item:" in seg:
                    item = seg.split("item:")[-1].strip()
                    break

            category = ITEM_TO_CATEGORY.get(item, "Khác")
            if category != "Khác":  # bỏ qua mẫu không có category rõ ràng
                texts.append(sentence)
                labels.append(category)

    return texts, labels


def train(texts, labels):
    """
    Train TF-IDF + Naive Bayes classifier.

    TF-IDF (Term Frequency - Inverse Document Frequency):
    - Chuyển câu văn thành vector số
    - analyzer="char_wb": dùng n-gram ký tự (tốt cho tiếng Việt có dấu)
    - ngram_range=(2,4): lấy chuỗi 2-4 ký tự liên tiếp

    Naive Bayes:
    - Thuật toán phân loại đơn giản, nhanh, hiệu quả với text
    - Tính xác suất P(category | text) cho mỗi hạng mục
    - Trả về hạng mục có xác suất cao nhất
    """
    print(f"\n📊 Dữ liệu: {len(texts)} câu, {len(set(labels))} hạng mục")
    print(f"   Phân bố: {dict(zip(*[list(x) for x in zip(*[(l, labels.count(l)) for l in set(labels)])]))}")

    # Chia train/test 80/20
    X_train, X_test, y_train, y_test = train_test_split(
        texts, labels, test_size=0.2, random_state=42, stratify=labels
    )

    # Bước 1: TF-IDF vectorizer
    print("\n🔧 Đang tạo TF-IDF features...")
    vectorizer = TfidfVectorizer(
        analyzer="char_wb",    # n-gram ký tự — tốt cho tiếng Việt
        ngram_range=(2, 4),    # chuỗi 2-4 ký tự
        max_features=5000,     # giới hạn 5000 features
        sublinear_tf=True,     # dùng log(tf) thay vì tf
    )
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec  = vectorizer.transform(X_test)

    # Bước 2: Train Naive Bayes
    print("🤖 Đang train Naive Bayes...")
    clf = MultinomialNB(alpha=0.1)  # alpha: Laplace smoothing
    clf.fit(X_train_vec, y_train)

    # Bước 3: Đánh giá
    y_pred = clf.predict(X_test_vec)
    acc = accuracy_score(y_test, y_pred)
    print(f"\n✅ Accuracy: {acc*100:.1f}%")
    print("\n📈 Chi tiết:")
    print(classification_report(y_test, y_pred))

    return vectorizer, clf


def save_model(vectorizer, clf, path: str):
    """Lưu model vào file .pkl để main.py load lại."""
    with open(path, "wb") as f:
        pickle.dump({"vectorizer": vectorizer, "clf": clf}, f)
    size_kb = os.path.getsize(path) / 1024
    print(f"💾 Model đã lưu: {path} ({size_kb:.0f} KB)")


def test_model(vectorizer, clf):
    """Test nhanh với một số câu mẫu."""
    test_cases = [
        "Hôm nay ăn phở bò hết 50k",
        "Đổ xăng xe máy 80 nghìn",
        "Mua áo mới 200k",
        "Tiền điện tháng này 150k",
        "Uống cafe sáng 35k",
        "Sửa xe đạp 45k",
        "Mua trà sữa 65k",
    ]

    print("\n🧪 Test model:")
    print("-" * 50)
    for text in test_cases:
        vec = vectorizer.transform([text])
        pred = clf.predict(vec)[0]
        proba = clf.predict_proba(vec).max()
        print(f"  '{text}'")
        print(f"  → {pred} ({proba*100:.0f}% tin cậy)\n")


if __name__ == "__main__":
    print("=" * 50)
    print("  SmartPrice NLP Model Trainer")
    print("=" * 50)

    # 1. Load dữ liệu
    print(f"\n📂 Đọc dữ liệu từ: {DATA_TXT}")
    texts, labels = load_data_from_txt(DATA_TXT)

    if not texts:
        print("❌ Không có dữ liệu để train!")
        exit(1)

    # 2. Train
    vectorizer, clf = train(texts, labels)

    # 3. Lưu model
    save_model(vectorizer, clf, MODEL_OUT)

    # 4. Test
    test_model(vectorizer, clf)

    print("\n✅ Hoàn tất! Chạy main.py để dùng model mới.")
    print(f"   Model: {os.path.abspath(MODEL_OUT)}")
