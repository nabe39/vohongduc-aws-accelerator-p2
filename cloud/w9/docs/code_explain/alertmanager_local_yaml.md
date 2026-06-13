# 📄 Giải thích Code: [alertmanager-local.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/alertmanager-local.yaml)

File cấu hình này thiết lập các luật xử lý cảnh báo, cơ chế gom nhóm và thông số gửi email SMTP Gmail của **Alertmanager** khi chạy cục bộ.

---

## 1. Nội dung Code

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager-noreply@gmail.com'
  smtp_auth_username: 'ducvh.22git@vku.udn.vn'
  smtp_auth_password: 'tqqh ysvp qacm logk'
  smtp_require_tls: true
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'null'
  routes:
  - matchers:
    - alertname = ApiLowSuccessRateSLO
    receiver: 'email-receiver'
receivers:
- name: 'null'
- name: 'email-receiver'
  email_configs:
  - to: 'vohongduc000@gmail.com'
    send_resolved: true
```

---

## 2. Giải thích chi tiết từng phần

### 2.1 Cấu hình toàn cục (`global`)
*   `resolve_timeout: 5m`: Nếu sau 5 phút kể từ khi lỗi không xuất hiện nữa mà Alertmanager không nhận được cập nhật từ Prometheus, Alertmanager sẽ coi lỗi này đã được khắc phục (**Resolved**) và gửi mail báo kết quả.
*   `smtp_smarthost: 'smtp.gmail.com:587'`: Địa chỉ máy chủ SMTP của Google và cổng gửi mail (587 hỗ trợ giao thức TLS bảo mật).
*   `smtp_from: 'alertmanager-noreply@gmail.com'`: Địa chỉ email người gửi hiển thị trên mail cảnh báo.
*   `smtp_auth_username`: Địa chỉ tài khoản Gmail thật dùng để đăng nhập và làm cổng gửi thư đi (`ducvh.22git@vku.udn.vn`).
*   `smtp_auth_password`: Mật khẩu ứng dụng Gmail (App Password) đã được khởi tạo để xác thực bảo mật (`tqqh ysvp qacm logk`).
*   `smtp_require_tls: true`: Yêu cầu mã hóa giao thức kết nối bằng TLS để bảo vệ thông tin email gửi đi.

### 2.2 Định tuyến cảnh báo (`route`)
*   `group_by: ['alertname']`: Gom nhóm các cảnh báo có cùng tên (`alertname`) vào chung một thông báo duy nhất để giảm thiểu số lượng email rác gửi dồn dập.
*   `group_wait: 10s`: Khoảng thời gian chờ đợi thu thập thêm các lỗi cùng nhóm trước khi gửi đi thông báo đầu tiên (ở đây là 10 giây).
*   `group_interval: 10s`: Khoảng thời gian chờ để gửi thông báo cho nhóm cảnh báo mới vừa được sinh ra.
*   `repeat_interval: 1h`: Nếu lỗi đó vẫn tiếp diễn và chưa được khắc phục, Alertmanager sẽ đợi **1 giờ** mới gửi email nhắc lại lỗi, tránh làm tràn ngập hòm thư (Alert Fatigue).
*   `receiver: 'null'`: Người nhận mặc định. Các cảnh báo không được chỉ định cụ thể sẽ bị chuyển tới receiver `null` (nghĩa là bỏ qua, không gửi đi đâu cả).
*   `routes`: Các đường dẫn định tuyến tùy biến.
    *   `matchers.alertname = ApiLowSuccessRateSLO`: Định nghĩa một bộ lọc. Nếu tên cảnh báo khớp chính xác với `ApiLowSuccessRateSLO`.
    *   `receiver: 'email-receiver'`: Chuyển tiếp cảnh báo này tới receiver có tên `email-receiver` để kích hoạt gửi mail.

### 2.3 Cấu hình người nhận (`receivers`)
*   `name: 'null'`: Định nghĩa một receiver rỗng không làm gì cả, dùng để chứa các alert không cần quan tâm.
*   `name: 'email-receiver'`: Khai báo receiver gửi email thực tế.
    *   `to: 'vohongduc000@gmail.com'`: Email đích của quản trị viên hệ thống để nhận thông báo cảnh báo.
    *   `send_resolved: true`: Gửi thêm một email thông báo khi lỗi được giải quyết (hệ thống hoạt động ổn định trở lại).
