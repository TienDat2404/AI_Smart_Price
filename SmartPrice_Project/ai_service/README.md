# SmartPrice AI Engine

FastAPI server cung cấp OCR và NLP cho SmartPrice.
Hỗ trợ tiếng Việt vùng miền (Bắc / Trung / Nam) với **504 entries** từ CentralVietnamDataset.

## Cài đặt

```bash
cd ai_service

# Tạo virtual environment (khuyến nghị)
python -m venv venv
venv\Scripts\activate   # Windows
# source venv/bin/activate  # Linux/Mac

# Cài dependencies
pip install fastapi uvicorn easyocr pillow numpy python-multipart scikit-learn
```

## Bước 1: Build dialect map (chạy 1 lần)

```bash
# Tải dataset tiếng Việt vùng miền từ CentralVietnamDataset
python build_dialect_map.py
# → Tạo ra dialect_extended.json (504 entries)
```

## Bước 2: Train NLP model (tùy chọn)

```bash
# Train model phân loại hạng mục từ nlp_train.txt
python train_nlp.py
# → Tạo ra nlp_model.pkl (accuracy ~97%)
```

## Bước 3: Chạy server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Server chạy tại: http://localhost:8000

## Test dialect normalization

```bash
# Kiểm tra các test case vùng miền
python test_dialect_standalone.py
```

## API Endpoints

| Endpoint | Mô tả |
|---|---|
| `GET /` | Health check + dialect stats |
| `GET /dialect/stats` | Thống kê dialect map |
| `POST /dialect/normalize` | Test chuẩn hóa từ địa phương |
| `POST /parse/text` | NLP bóc tách chi tiêu từ văn bản |
| `POST /parse/image` | OCR bóc tách hóa đơn từ ảnh |

## Test cases vùng miền

| Câu nói | Vùng | Kết quả |
|---|---|---|
| "Sáng nay uống cà phê hết hăm lăm ngàn" | Miền Nam | 25.000đ / Ăn uống |
| "Mần cái bánh mỳ mười lăm ngàn" | Miền Trung | 15.000đ / Ăn uống |
| "Đi xe ôm hết hai chục" | Miền Bắc | 20.000đ / Di chuyển |
| "Tui xài hết năm chục ngàn mua đồ" | Miền Nam | 50.000đ / Mua sắm |

## Nguồn dữ liệu

- **CentralVietnamDataset**: [github.com/trituenhantaoio/CentralVietnamDataset](https://github.com/trituenhantaoio/CentralVietnamDataset) — 504 từ/câu phương ngữ miền Trung
- **nlp_train.txt**: 1000 câu tiếng Việt tự sinh để train NLP classifier
- **EasyOCR**: Pre-trained model nhận diện chữ tiếng Việt/Anh
