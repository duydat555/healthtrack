# Báo cáo kiểm thử bảo mật cơ bản (OWASP) — Issue #76

**Ngày rà soát:** 2026-11-11
**Phạm vi:** API FastAPI, JWT, quyền sở hữu bản ghi và cách app Flutter hiển thị dữ liệu.
**Môi trường:** test tự động chạy trên cơ sở dữ liệu SQLite trong bộ nhớ; không gửi payload tấn công đến cloud hoặc dữ liệu người dùng thật.

## Kết quả

| Hạng mục | Cách kiểm tra | Kết quả |
|---|---|---|
| IDOR / phân quyền theo chủ sở hữu | Hai tài khoản gọi đọc, sửa, xóa bản ghi của nhau; kiểm tra weights, water, steps, meals, sleep, goals, medications và CRUD cơ sở. Các bản ghi ngoài quyền trả 404 hoặc danh sách rỗng. | Đạt theo các test `test_*` tương ứng trong `backend/tests/` và `test_crud_base.py`. Không thấy truy cập chéo trong các luồng đã kiểm tra. |
| SQL injection | Gửi chuỗi SQL-shaped vào tên hồ sơ khi đăng ký; kiểm tra giá trị được giữ như dữ liệu, đăng ký tài khoản tiếp theo và đăng nhập vẫn hoạt động. Email đăng nhập được kiểm tra bằng Pydantic `EmailStr`; truy vấn tài khoản dùng SQLAlchemy ORM. | Đạt trong test `test_sql_injection_shaped_profile_value_is_stored_as_data` ở `backend/tests/test_security_owasp.py`. Không thấy thực thi SQL ngoài ý muốn. |
| XSS | Gửi chuỗi `<script>` trong tên hồ sơ; xác nhận API trả JSON và giữ nguyên chuỗi dữ liệu. Rà soát chỗ hiển thị tên trong Flutter: dùng widget `Text`, không dùng HTML renderer. | Không thấy điểm thực thi script trong API/app Flutter đã rà soát. Backend API không tự HTML-escape chuỗi JSON; nếu thêm web client, client phải encode output theo ngữ cảnh. |
| Rate limit đăng nhập | Gửi số lần đăng nhập sai bằng ngưỡng cấu hình rồi thêm một lần; kiểm tra HTTP 429 và header `Retry-After`. | Đạt theo `backend/tests/test_rate_limit_timing.py`; mặc định 10 lượt / 60 giây mỗi IP. Bộ đếm lưu trong bộ nhớ tiến trình, vì vậy không đồng bộ giữa nhiều worker/instance. |
| JWT và mật khẩu | Kiểm tra token hết hạn, sai secret/algorithm/type, thiếu claim, dữ liệu rác; kiểm tra bcrypt hash và cấu hình secret production. | Đạt theo `backend/tests/test_security.py`. |

## Giới hạn và việc theo dõi

- Đây là kiểm tra cơ bản trong phạm vi issue, không phải pentest độc lập hay chứng nhận OWASP.
- Rate limit phù hợp khi backend chạy một tiến trình. Nếu triển khai nhiều worker/instance, cần dùng kho dùng chung như Redis và kiểm tra cấu hình proxy/IP trước khi tăng quy mô. Đây là giới hạn triển khai đã biết, chưa tái hiện thành lỗi trên cấu hình một instance hiện tại.
- Không phát hiện lỗ hổng cần mở issue khắc phục mới trong lần rà soát này. Vì vậy không tạo issue phụ. Nếu phát hiện khi chạy lại trên môi trường triển khai, ghi bằng chứng không chứa bí mật/dữ liệu sức khỏe và tạo issue riêng.

## Lệnh chạy lại

Từ thư mục `backend`:

```powershell
..\.venv\Scripts\python.exe -m pytest tests/test_security_owasp.py tests/test_security.py tests/test_rate_limit_timing.py tests/test_weights.py tests/test_water.py tests/test_sleep.py tests/test_steps.py tests/test_meals.py tests/test_goals.py tests/test_medications.py -q
```

Kết quả thực tế mỗi lần chạy cần được ghi kèm commit và thời điểm trong PR. Báo cáo này chưa khẳng định trạng thái bảo mật của dịch vụ cloud; nó tóm tắt rà soát mã nguồn và kiểm thử cục bộ.

**Lần chạy trong nhánh #76:** 83 test liên quan đến injection, JWT, rate limit và quyền sở hữu bản ghi đạt (`83 passed in 86.07s`); Ruff check và format cho test mới cũng đạt. Đây là kiểm thử cục bộ, không phải kiểm tra xâm nhập trên cloud.
