# DEMO SCRIPT — SmartPrice AI
### Thuyết trình trước Hội đồng

---

## PHẦN 1: MỞ ĐẦU — Vấn đề & Bối cảnh
*[Thời gian: ~2 phút | Không cần thao tác trên app]*

---

**[Mở đầu — đặt vấn đề]**

> "Thưa hội đồng, mỗi ngày chúng ta chi tiêu hàng chục lần — từ ly cà phê buổi sáng, đến bữa trưa, đến chuyến Grab về nhà. Nhưng cuối tháng, khi nhìn lại tài khoản, câu hỏi quen thuộc lại xuất hiện: *'Tiền đi đâu hết vậy?'"*

**[Nêu hạn chế của giải pháp hiện tại]**

> "Các ứng dụng quản lý tài chính hiện nay yêu cầu người dùng phải: mở app, chọn hạng mục, nhập số tiền, nhập ghi chú, rồi nhấn lưu — ít nhất 5 thao tác cho mỗi giao dịch. Kết quả là hơn 70% người dùng bỏ cuộc sau 2 tuần vì quá bất tiện."

**[Giới thiệu giải pháp]**

> "SmartPrice AI giải quyết vấn đề này bằng một câu nói. Chỉ cần gõ hoặc nói *'Ăn phở bò 45k'* — hệ thống AI sẽ tự động nhận diện số tiền, phân loại hạng mục và lưu vào cơ sở dữ liệu. Toàn bộ quá trình dưới 5 giây."

---

## PHẦN 2: DEMO TRỰC TIẾP
*[Thời gian: ~5 phút | Thao tác trực tiếp trên thiết bị/emulator]*

---

### 2.1 — Màn hình Dashboard
*[Mở app, hiển thị DashboardScreen]*

> "Đây là màn hình chính của người dùng. Ngay lập tức, họ thấy **tổng số dư** hiện tại và **biểu đồ Neon** thể hiện xu hướng chi tiêu 7 ngày gần nhất — không cần vào menu, không cần tìm kiếm."

> "Phía dưới là danh sách giao dịch gần nhất, được sắp xếp theo thời gian thực. Mỗi giao dịch hiển thị hạng mục, ghi chú và màu sắc phân biệt thu/chi rõ ràng."

*[Chỉ vào ô nhập liệu AI phía trên]*

> "Và đây là trái tim của hệ thống — ô nhập liệu AI. Tôi sẽ demo ngay bây giờ."

---

### 2.2 — Luồng Smart Input *(điểm nhấn chính)*
*[Nhấn vào ô nhập liệu → chuyển sang SmartInputScreen]*

> "Tôi vừa mở màn hình nhập liệu thông minh. Giao diện được thiết kế như một cuộc hội thoại — thân thiện và tự nhiên."

**[Gõ vào TextField: "Ăn phở bò 45k"]**

> "Tôi nhập đúng như cách tôi nói chuyện hàng ngày: *'Ăn phở bò 45k'*. Không cần chọn hạng mục, không cần format đặc biệt."

*[Nhấn Send — bubble người dùng xuất hiện bên phải, loading xuất hiện bên trái]*

> "Tin nhắn của tôi xuất hiện bên phải — giống hệt ứng dụng chat. Phía bên trái, AI đang xử lý..."

*[Sau 2 giây — AiPreviewCard xuất hiện]*

> "Và đây là kết quả. AI đã nhận diện được:
> - **Số tiền: 45.000 đồng**
> - **Hạng mục: Ăn uống** — được phân loại tự động từ từ khóa 'phở'
> - **Ghi chú: Ăn phở bò** — được trích xuất từ câu nhập
> - **Độ chính xác: 92%**"

> "Hệ thống không chỉ đọc số — nó *hiểu* ngữ cảnh."

**[Nhấn "Lưu giao dịch"]**

> "Tôi xác nhận. Giao dịch được ghi vào MongoDB ngay lập tức."

---

### 2.3 — Kết quả phản ánh trên Dashboard
*[Quay lại DashboardScreen — kéo để refresh]*

> "Quay lại Dashboard — giao dịch vừa nhập đã xuất hiện trong danh sách gần đây. Biểu đồ 7 ngày cũng cập nhật điểm dữ liệu của hôm nay."

> "Toàn bộ luồng từ lúc tôi gõ đến lúc dữ liệu hiển thị trên biểu đồ: **dưới 5 giây**."

---

### 2.4 — *(Tùy chọn)* Cảnh báo ngân sách
*[Mở BudgetScreen nếu có thời gian]*

> "Hệ thống còn theo dõi ngân sách theo hạng mục. Khi chi tiêu vượt 80% hạn mức — ví dụ hạng mục Ăn uống đã dùng 87% — thanh tiến trình chuyển sang **màu đỏ cảnh báo** tự động. Người dùng biết ngay mình cần điều chỉnh chi tiêu."

---

## PHẦN 3: TỔNG KẾT — Kiến trúc Khép kín
*[Thời gian: ~2 phút | Có thể dùng slide sơ đồ kiến trúc]*

---

**[Trình bày vòng khép kín]**

> "Điều tôi muốn nhấn mạnh là tính **khép kín hoàn toàn** của hệ thống. Hãy nhìn vào vòng lặp này:"

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   [1] INPUT          [2] AI PROCESSING    [3] STORAGE   │
│   Flutter App   →    Python FastAPI    →   MongoDB      │
│   "Ăn phở 45k"       NLP Engine            Database     │
│                       ↓                                 │
│   [4] VISUALIZATION  ←─────────────────────────────────  │
│   Neon Dashboard                                        │
│   Biểu đồ 7 ngày                                        │
│   Cảnh báo ngân sách                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

> "**Bước 1 — Input:** Người dùng nhập bằng ngôn ngữ tự nhiên trên Flutter Mobile App. Không cần training, không cần học cách dùng."

> "**Bước 2 — AI Processing:** ASP.NET Core Backend nhận request và chuyển tiếp đến Python AI Engine. Engine thực hiện NLP để bóc tách Amount, Category và Note từ câu văn thô."

> "**Bước 3 — Storage:** Dữ liệu đã được cấu trúc hóa được lưu vào MongoDB — linh hoạt, không cần schema cứng nhắc, phù hợp với dữ liệu tài chính đa dạng."

> "**Bước 4 — Visualization:** Flutter Dashboard đọc dữ liệu từ API, tính toán xu hướng time-series và hiển thị biểu đồ Neon trực quan. Vòng lặp hoàn tất."

**[Kết luận]**

> "SmartPrice AI không chỉ là một ứng dụng ghi chép — đây là một **hệ thống tài chính thông minh** nơi dữ liệu chảy liên tục từ hành động của người dùng đến insight có giá trị, hoàn toàn tự động."

> "Cảm ơn hội đồng đã lắng nghe. Tôi sẵn sàng trả lời câu hỏi."

---

## PHỤ LỤC — Câu hỏi thường gặp từ Hội đồng

| Câu hỏi | Gợi ý trả lời |
|---|---|
| *"Độ chính xác NLP thực tế là bao nhiêu?"* | "Với tập dữ liệu tiếng Việt hiện tại, mô hình đạt ~85-90% trên các câu phổ biến. Hệ thống luôn hiển thị confidence score và cho phép user chỉnh sửa trước khi lưu." |
| *"Nếu không có mạng thì sao?"* | "Kiến trúc hiện tại yêu cầu kết nối. Offline mode với local queue là tính năng có thể phát triển trong giai đoạn tiếp theo." |
| *"Dữ liệu người dùng có an toàn không?"* | "Mỗi user chỉ truy cập được dữ liệu của chính mình qua userId. Admin có quyền xem tổng hợp nhưng không can thiệp vào giao dịch cá nhân." |
| *"Tại sao chọn MongoDB thay vì SQL?"* | "Dữ liệu giao dịch có cấu trúc linh hoạt — mỗi hạng mục có thể có metadata khác nhau. MongoDB cho phép mở rộng schema mà không cần migration." |
| *"Có thể mở rộng thêm tính năng gì?"* | "OCR hóa đơn, đồng bộ ngân hàng qua Open Banking API, và dự báo chi tiêu bằng mô hình time-series LSTM." |
