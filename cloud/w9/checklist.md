# Bảng Đánh Giá & Checklist Dự Án W9 (GitOps, Observability & Canary)

Tài liệu này đánh giá hiện trạng dự án dựa trên các tiêu chí chấm điểm tuần **W9** và cung cấp Checklist chi tiết các phần việc cần làm tiếp theo để hoàn thiện dự án đạt yêu cầu tối đa.

---

## 📊 Bảng Đánh Giá Hiện Trạng (Requirement Matrix)

| Tiêu chí đạt yêu cầu (ĐẠT - phải đủ cả 4) | Hiện trạng trong Repo | Trạng thái | Chi tiết kỹ thuật & Đánh giá |
| :--- | :--- | :---: | :--- |
| **1. Thay đổi qua Git & ArgoCD Synced** | Có đầy đủ cấu hình ArgoCD `root.yaml` và các Application con (`web`, `api`, `argo-rollouts`, `kube-prometheus-stack`) với chế độ `auto-sync` và `self-heal`. | **ĐÃ ĐẠT** (Met) | Toàn bộ tài nguyên được quản lý theo mô hình App-of-Apps. Trạng thái thực tế đồng bộ tự động với Git, không bị cấu hình sai lệch (drift). |
| **2. `git revert` rollback < 5 phút** | Cơ chế GitOps được kích hoạt đầy đủ. Khi có lỗi, việc revert commit trên Git sẽ kích hoạt ArgoCD đồng bộ ngược lại phiên bản cũ ngay lập tức. | **ĐÃ ĐẠT** (Met) | Quy trình rollback qua Git hoàn toàn khả thi và thực thi tự động dưới 1-2 phút nhờ cấu hình `automated.prune` và `selfHeal`. |
| **3. 1 SLO + 1 alert gửi về email cá nhân** | Chưa có file cấu hình PrometheusRule quy định SLO & Alertmanager chưa được cấu hình gửi mail. | **CHƯA ĐẠT** (Unmet) | Cần cấu hình thêm Alertmanager (SMTP credentials, receiver email) và định nghĩa ít nhất 1 rule SLO (ví dụ: HTTP Success Rate) trong cụm. |
| **4. Canary tự động abort & rollback** | File `k8s-api/api.yaml` mới chỉ cấu hình canary cơ bản với việc tạm dừng thủ công (`pause: {}`), chưa liên kết tự động đánh giá. | **CHƯA ĐẠT** (Unmet) | Cần tạo tài nguyên `AnalysisTemplate` chạy các truy vấn Prometheus để tự động kiểm tra tỷ lệ lỗi (Error Rate) và tự động dừng (abort) rollout nếu vượt ngưỡng. |

---

## 📋 Checklist Chi Tiết & Hướng Dẫn Triển Khai (To-Do List)

Dưới đây là các đầu việc chi tiết cần làm để đáp ứng đầy đủ yêu cầu:

### [x] Nhiệm vụ 1: Cấu hình Canary Auto-Abort (Quan trọng nhất)
*   **[x] Tạo tài nguyên `AnalysisTemplate`:** Định nghĩa một template đo lường tỷ lệ thành công của HTTP Request (Success Rate) từ metric Prometheus của ứng dụng `api`.
    *   *Metric đề xuất:* `flask_http_request_total` (do `prometheus_flask_exporter` cung cấp).
    *   *Query PromQL mẫu:*
        ```promql
        sum(rate(flask_http_request_total{status!~"5..", job="api-servicemonitor"}[2m])) 
        / 
        sum(rate(flask_http_request_total{job="api-servicemonitor"}[2m]))
        ```
    *   *Ngưỡng chấp nhận (Threshold):* `>= 0.95` (Success rate tối thiểu 95%).
*   **[x] Liên kết `AnalysisTemplate` vào `api` Rollout:** 
    *   Chỉnh sửa file `cloud/w9/lab/gitops/k8s/k8s-api/api.yaml`, thay thế bước `pause: {}` đầu tiên bằng việc tham chiếu đến `AnalysisTemplate` vừa tạo để chạy phân tích thời gian thực trong lúc tiến hành Canary.
    *   Cấu hình tham số `args` truyền vào template để xác định đúng service cần đo.

---

### [x] Nhiệm vụ 2: Thiết lập SLO & Alerting gửi về Email cá nhân
*   **[x] Định nghĩa SLO bằng `PrometheusRule`:**
    *   Tạo file `cloud/w9/lab/gitops/k8s/k8s-api/prom-rules.yaml` chứa định nghĩa cảnh báo khi tỷ lệ thành công giảm xuống dưới 95% trong 5 phút.
*   **[x] Cấu hình gửi Mail trong `kube-prometheus-stack`:**
    *   Cập nhật cấu hình Helm values trong file `cloud/w9/lab/gitops/k8s/argocd/apps/kube-prometheus-stack.yaml` để thêm thông số cấu hình Alertmanager (SMTP, Email gửi nhận).
    *   *Cấu hình SMTP tham khảo (ví dụ với Gmail SMTP):*
        ```yaml
        alertmanager:
          config:
            global:
              smtp_smarthost: 'smtp.gmail.com:587'
              smtp_from: 'alertmanager-noreply@gmail.com'
              smtp_auth_username: '<EMAIL_CUA_BAN>@gmail.com'
              smtp_auth_password: '<APP_PASSWORD_GMAIL>'
            route:
              receiver: 'email-receiver'
            receivers:
            - name: 'email-receiver'
              email_configs:
              - to: '<EMAIL_NHAN_CANH_BAO>@gmail.com'
                send_resolved: true
        ```

---

### [ ] Nhiệm vụ 3: Cập nhật README & Báo cáo minh chứng
*   **[ ] Bổ sung phần giải thích Query & Ngưỡng:**
    *   Viết tài liệu giải thích rõ câu lệnh PromQL dùng để đo SLO, lý do chọn khoảng thời gian 2m/5m và tại sao chọn ngưỡng 95%.
*   **[ ] Thực hiện test lỗi (Inject Error) để quay video/chụp ảnh:**
    *   Cập nhật version mới của `api` đồng thời đổi `ERROR_RATE` lên `0.5` (lỗi 50%) trong file `api.yaml`.
    *   Push thay đổi lên Git để kích hoạt Canary.
    *   Ghi lại logs/màn hình hoặc chụp ảnh quá trình:
        1. Canary Rollout tiến hành và tự động thất bại (`Degraded` / `Aborted`) do tỷ lệ lỗi vượt ngưỡng.
        2. Hệ thống tự động rollback lại bản `v1` an toàn.
        3. Email cảnh báo SLO gửi về hòm thư cá nhân của bạn.
