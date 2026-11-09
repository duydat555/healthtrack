# Đặc tả API (v1)

Tiền tố `/api/v1`. Tài liệu tương tác tại `/docs` (Swagger). Cần bổ sung chi tiết request/response khi từng endpoint hoàn thành.

| Nhóm | Endpoint | Trạng thái |
|---|---|---|
| Hệ thống | `GET /health` | Đã có |
| Xác thực | `POST /auth/register` (201, 409 nếu trùng email) | Đã có |
| Xác thực | `POST /auth/login` (body `email`, `password`), `POST /auth/refresh` (body `refresh_token`); trả `access_token`, `refresh_token`; sai thông tin trả 401 | Đã có |
| Người dùng | `GET /users/me`, `PATCH /users/me` (cần header `Authorization: Bearer <access_token>`, thiếu token trả 401) | Đã có |
| Cân nặng/BMI | `GET/POST /weights`, `PATCH/DELETE /weights/{id}`; BMI tự tính từ chiều cao hồ sơ; `GET` hỗ trợ `from`, `to`, `limit`, `offset`; chỉ thấy dữ liệu của mình (người khác trả 404) | Đã có |
| Nước uống | `GET/POST /water`, `PATCH/DELETE /water/{id}` | Phase 2 |
| Giấc ngủ | `GET/POST /sleep`, `PATCH/DELETE /sleep/{id}` | Phase 2 |
| Bước chân | `GET/POST /steps`, `PATCH/DELETE /steps/{id}` | Phase 2 |
| Bữa ăn | `GET/POST /meals`, `PATCH/DELETE /meals/{id}` | Phase 2 |
| Thuốc | `GET/POST /medications`, `POST /medications/{id}/logs` | Phase 2 |
| Mục tiêu | `GET/POST /goals`, `PATCH/DELETE /goals/{id}` | Phase 2 |
| Thống kê | `GET /stats/summary`, `GET /stats/trend?metric=&range=` | Phase 4 |
| Nhắc nhở | `GET/POST /reminders`, `PATCH/DELETE /reminders/{id}` | Phase 4 |

**Quy ước:** JSON; lỗi trả `{"detail": "..."}` kèm mã HTTP đúng (400, 401, 403, 404, 422); danh sách hỗ trợ `limit`, `offset`, `from`, `to`.
