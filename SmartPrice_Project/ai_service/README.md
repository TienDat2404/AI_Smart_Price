# SmartPrice AI Engine

FastAPI server cung cấp OCR và NLP cho SmartPrice.

## Cài đặt

```bash
cd ai_service

# Tạo virtual environment (khuyến nghị)
python -m venv venv
venv\Scripts\activate   # Windows
# source venv/bin/activate  # Linux/Mac

# Cài dependencies
pip install fastapi uvicorn easyocr pillow numpy python-multipart
```

> **Lưu ý:** `easyocr` sẽ tự tải model (~500MB) lần đầu chạy.

## Chạy server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Server chạy tại: http://localhost:8000

## Test nhanh

```bash
# Health check
curl http://localhost:8000/

# Test OCR với ảnh hóa đơn
curl -X POST http://localhost:8000/parse/image \
  -F "image=@path/to/invoice.jpg"

# Test NLP
curl -X POST http://localhost:8000/parse/text \
  -H "Content-Type: application/json" \
  -d '{"text": "Hôm nay ăn phở hết 50k"}'
```

## Kết quả OCR mẫu

```json
{
  "store": "WinMart Quận 1",
  "total": 125000.0,
  "date": "24/04/2026",
  "category": "Mua sắm",
  "confidence": 0.87,
  "invoice_id": "INV-20260424-5432"
}
```
