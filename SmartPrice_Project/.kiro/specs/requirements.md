TÀI LIỆU ĐẶC TẢ HỆ THỐNG SMARTPRICE AI
1. Phân quyền & Nền tảng (Actors & Platforms)
Người dùng (User): Sử dụng Mobile App (Flutter) để quản lý tài chính cá nhân, nhập liệu nhanh bằng AI.

Quản trị viên (Admin): Sử dụng Web Dashboard (Flutter Web) để giám sát toàn bộ dữ liệu hệ thống và hoạt động của người dùng.

2. Đặc tả Luồng nghiệp vụ (Business Workflows)
2.1. Luồng Nhập liệu thông minh (Smart Input - Mobile)
Bước 1: User nhập câu nói tự nhiên (VD: "Ăn phở bò 45k") hoặc gửi ảnh hóa đơn tại màn hình Nhập liệu.

Bước 2: Flutter App gửi yêu cầu đến ASP.NET Core Backend.

Bước 3: Backend chuyển tiếp đến Python AI Engine để thực hiện NLP/OCR bóc tách dữ liệu (Amount, Category, Note).

Bước 4: Hệ thống trả về kết quả JSON. Mobile App hiển thị Smart Preview Card để User xác nhận.

Bước 5: User nhấn "Lưu", dữ liệu được ghi vào MongoDB.

2.2. Luồng Phân tích & Cảnh báo (Analytics & Alerts - Mobile)
Bước 1: User mở Dashboard, App gọi API lấy dữ liệu chi tiêu theo thời gian.

Bước 2: Hệ thống tính toán số dư và xu hướng từ bộ dữ liệu Time-series.

Bước 3: Hiển thị Biểu đồ Neon (Line/Pie Chart) trực quan.

Bước 4: Nếu chi tiêu một hạng mục vượt 80% ngân sách, hệ thống kích hoạt cảnh báo đỏ trên UI.

2.3. Luồng Giám sát Hệ thống (Global Monitoring - Web Admin)
Bước 1: Admin đăng nhập vào Web Dashboard bằng tài khoản có quyền Quản trị.

Bước 2: Hệ thống truy vấn toàn bộ giao dịch từ tất cả User trong MongoDB.

Bước 3: Hiển thị dữ liệu dưới dạng Master Data Table với các bộ lọc nâng cao (theo User, Ngày, Số tiền).

Bước 4: Admin theo dõi hiệu suất bóc tách của AI thông qua các bản ghi hệ thống (Logs).

3. Danh sách màn hình chi tiết (UI Specifications)
3.1. Giao diện Mobile (Dành cho User)
Dashboard (Home): Hiển thị số dư Neon, biểu đồ biến động 7 ngày và các giao dịch gần đây.

Smart Input: Ô chat AI tích hợp Microphone, hiển thị Card kết quả dự đoán từ AI để xác nhận nhanh.

Transaction History: Danh sách toàn bộ chi tiêu cá nhân, có bộ lọc theo ngày và hạng mục.

Smart Analytics: Biểu đồ tròn phân tích tỉ lệ chi tiêu và dòng văn bản dự báo tài chính tương lai.

Budget Planning: Thiết lập hạn mức chi tiêu và thanh tiến trình (Progress Bar) theo dõi ngân sách.

Settings: Tùy chỉnh thông tin cá nhân và giao diện (Dark/Light Mode).

3.2. Giao diện Web (Dành cho Admin)
Admin Overview: Trang tổng quan hiển thị tổng số User, tổng lượng giao dịch và biểu đồ tăng trưởng hệ thống.

Master Data Management: Bảng dữ liệu khổng lồ hiển thị tất cả giao dịch của mọi người dùng. Hỗ trợ tìm kiếm, lọc và xuất file Excel.

User Management: Danh sách quản lý tài khoản người dùng, cho phép xem chi tiết hoạt động hoặc khóa tài khoản vi phạm.

AI Monitor & Logs: Trang kỹ thuật hiển thị các câu lệnh thực tế mà AI đã xử lý để Admin đánh giá độ chính xác của mô hình NLP.

4. Kiến trúc Dữ liệu & Công nghệ (Technical Stack)
Frontend: Flutter (Mobile & Web).

Backend: ASP.NET Core 8.0 (Web API).

AI Service: Python (FastAPI, NLP Engine).

Database: MongoDB (Lưu trữ Transactions, Users, Budgets).

Theme: Neon Dark Mode (Giao diện hiện đại, tương lai).