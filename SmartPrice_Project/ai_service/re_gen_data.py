import datetime
import random
import os

# Tạo thư mục datasets nếu chưa có (đi ngược ra ngoài thư mục gốc)
data_dir = os.path.join("..", "datasets")
if not os.path.exists(data_dir):
    os.makedirs(data_dir)

def gen_nlp_data():
    items = ["cơm tấm", "cafe", "đổ xăng", "tiền điện", "mua áo", "trà sữa", "sửa xe"]
    with open(os.path.join(data_dir, "nlp_train.txt"), "w", encoding="utf-8") as f:
        for _ in range(1000):
            item = random.choice(items)
            price = random.randint(20, 500) * 1000
            f.write(f"Hôm nay ăn {item} hết {price}đ | item: {item}, price: {price}\n")

def gen_ocr_data():
    with open(os.path.join(data_dir, "ocr_samples.txt"), "w", encoding="utf-8") as f:
        for i in range(100):
            f.write(f"Hóa đơn #{i+100} | Cửa hàng ABC | Tổng: {random.randint(50, 200)}k | Ngày: 2026-04-11\n")

def gen_timeseries_data():
    start_date = datetime.date(2026, 1, 1)
    with open(os.path.join(data_dir, "finance_series.txt"), "w", encoding="utf-8") as f:
        for i in range(90):
            curr_date = start_date + datetime.timedelta(days=i)
            spend = random.randint(50, 150) * 1000
            f.write(f"{curr_date} | {spend}\n")

if __name__ == "__main__":
    gen_nlp_data()
    gen_ocr_data()
    gen_timeseries_data()
    print(f"--- THÀNH CÔNG ---")
    print(f"Dữ liệu đã được tạo lại tại: {os.path.abspath(data_dir)}")