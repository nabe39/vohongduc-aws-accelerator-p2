# 📄 Giải thích Code: [alertmanager.env](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/alertmanager.env)

File cấu hình môi trường này chứa các thông số nhạy cảm dùng để xác thực SMTP với Gmail và địa chỉ email nhận cảnh báo.

---

## 1. Nội dung Code

```env
# Địa chỉ Gmail dùng làm cổng gửi cảnh báo đi (SMTP Sender)
SMTP_USER="ducvh.22git@vku.udn.vn"

# Mật khẩu ứng dụng Gmail (Gmail App Password)
SMTP_PASSWORD="tqqh ysvp qacm logk"

# Địa chỉ email nhận tin nhắn cảnh báo (SMTP Receiver)
ALERT_TO_EMAIL="vohongduc000@gmail.com"
```

---

## 2. Giải thích chi tiết từng biến

*   `SMTP_USER`: Khai báo email gửi đi. Email này cần được đăng ký với nhà cung cấp SMTP (ở đây là Gmail).
*   `SMTP_PASSWORD`: Mật khẩu ứng dụng Gmail gồm 16 ký tự viết liền không dấu cách. Mật khẩu này được sinh ra từ cài đặt tài khoản Google để cho phép các ứng dụng ngoài đăng nhập gửi mail một cách bảo mật mà không cần nhập mật khẩu chính của tài khoản.
*   `ALERT_TO_EMAIL`: Email của kỹ sư trực vận hành hệ thống, nơi nhận các email cảnh báo khi có sự cố SLO xảy ra.

---

## 3. Vai trò bảo mật của file `.env`

*   **Ngăn chặn rò rỉ mã nguồn:** File này chứa thông tin mật khẩu nhạy cảm của cá nhân, do đó nó bắt buộc phải được đưa vào file `.gitignore` để không bị push lên repository công khai trên GitHub.
*   **Trở thành nguồn cung cấp tham số cho Script:** File này sẽ được đọc bởi script [apply_env.py](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/apply_env.py) để tự động nạp các thông số bảo mật này vào các file cấu hình YAML của Helm trước khi triển khai hệ thống lên Kubernetes. Điều này giúp mã nguồn triển khai chung vẫn giữ được tính tổng quát và an toàn.
