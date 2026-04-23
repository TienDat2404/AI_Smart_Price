from underthesea import word_tokenize
import os

# Đường dẫn file dữ liệu
data_path = os.path.join("..", "datasets", "nlp_train.txt")

def test_parse():
    print("--- ĐANG KIỂM TRA DỮ LIỆU NLP ---")
    
    # Đọc thử 5 dòng đầu tiên từ file dữ liệu
    if os.path.exists(data_path):
        with open(data_path, "r", encoding="utf-8") as f:
            lines = f.readlines()[:5]
            
        for line in lines:
            # Tách lấy phần câu nói trước dấu gạch đứng |
            sentence = line.split("|")[0].strip()
            
            # Sử dụng underthesea để tách từ tiếng Việt
            tokens = word_tokenize(sentence)
            
            print(f"Câu gốc: {sentence}")
            print(f"Tách từ: {tokens}")
            print("-" * 20)
    else:
        print("Không tìm thấy file dữ liệu tại: ", data_path)

if __name__ == "__main__":
    test_parse()