# Quy trình Git

1. Nhận issue, kéo sang cột **In Progress** trên GitHub Projects.
2. `git checkout -b feat/<số-issue>-<mô-tả>` từ `main` mới nhất.
3. Commit nhỏ, thường xuyên, theo Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
4. Push và mở PR, điền mẫu PR, ghi `Closes #<số-issue>`; issue chuyển sang **In Review**.
5. Người duyệt kiểm tra, để lại nhận xét; tác giả sửa theo nhận xét.
6. Khi có 1 approval và CI xanh thì **Squash and merge**; issue tự đóng và sang **Done**.

**Branch protection trên `main`:** bắt buộc PR, 1 approval, CI xanh, không push thẳng.

**Cột board:** Backlog, Ready, In Progress, In Review, Done.
