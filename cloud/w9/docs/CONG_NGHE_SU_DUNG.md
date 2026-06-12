# 🛠️ Các Công Nghệ Sử Dụng & Lý Do Lựa Chọn (Technology Stack & Rationale)

Dự án sử dụng một bộ công nghệ hiện đại theo chuẩn **Cloud Native** và **SRE (Site Reliability Engineering)**. Dưới đây là phân tích chi tiết về từng công nghệ được áp dụng và lý do tại sao chúng được chọn thay vì các phương pháp truyền thống.

---

## Bảng Tổng Quan Công Nghệ (Tech Stack Matrix)

| Công nghệ | Vai trò trong dự án | Lý do lựa chọn | File cấu hình liên quan |
| :--- | :--- | :--- | :--- |
| **Kubernetes (Minikube)** | Hạ tầng điều phối Container (Orchestration) | Tiêu chuẩn công nghiệp, tự động khôi phục, khám phá dịch vụ (Service Discovery). | [namespace.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/namespace.yaml), [web.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/web.yaml) |
| **ArgoCD** | Trực quan hóa & CD theo mô hình GitOps | Khớp trạng thái Git tự động, chống lệch cấu hình (Anti-Drift), hỗ trợ App-of-Apps. | [root.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/root.yaml), thư mục [apps/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps) |
| **Argo Rollouts** | Phân phối tăng tiến (Progressive Delivery) | Hỗ trợ phát hành Canary và tự động Abort/Rollback dựa trên chất lượng metric thời gian thực. | [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml), [analysis.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/analysis.yaml) |
| **Prometheus** | Thu thập và lưu trữ Metrics (TSDB) | Khả năng pull metrics linh hoạt, ngôn ngữ PromQL mạnh mẽ để tính SLO & Canary. | [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml), [prom-rules.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/prom-rules.yaml) |
| **Alertmanager** | Định tuyến và gửi Cảnh Báo (Alerting) | Tích hợp sâu với Prometheus, hỗ trợ gom nhóm (grouping), chống trùng lặp và gửi mail qua SMTP. | [alertmanager-local.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/alertmanager-local.yaml) |
| **Flask & Prometheus Exporter** | Ứng dụng Backend & Xuất Metrics | Nhẹ, dễ tích hợp sẵn exporter xuất metric chuẩn Prometheus (`/metrics`). | [app.py](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/app/app.py), [Dockerfile](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/app/Dockerfile) |

---

## Phân Tích Sâu Lý Do Lựa Chọn Từng Công Nghệ

### 1. Tại Sao Lại Chọn GitOps Với ArgoCD?
* **Vấn đề của CD truyền thống (e.g. Jenkins, GitLab CI chạy lệnh `kubectl apply`):**
  * **Rủi ro bảo mật:** Cần cấp quyền admin cluster (`kubeconfig`) cho công cụ CI bên ngoài. Nếu CI bị hack, cluster cũng bị thỏa hiệp.
  * **Lệch cấu hình (Configuration Drift):** Một ai đó sửa manifest bằng lệnh `kubectl edit` trực tiếp trên cluster, mã nguồn trên Git không được cập nhật, dẫn tới trạng thái thật lệch so với Git mà không ai biết.
  * **Khó khăn khi rollback:** Phải chạy lại các pipeline cũ phức tạp, đôi khi gặp lỗi do môi trường thay đổi.
* **Giải pháp từ ArgoCD:**
  * **Mô hình Pull-based:** ArgoCD chạy bên trong cluster (In-Cluster Agent) và kéo cấu hình từ Git về. Không cần phơi bày API Server ra ngoài cho các công cụ CI.
  * **Chế độ Tự sửa lỗi (Self-Heal):** Khi phát hiện có ai đó sửa đổi thủ công trên cluster (Drift), ArgoCD ngay lập tức khôi phục (sync ngược lại) về đúng thiết kế trên Git.
  * **Mô hình App-of-Apps:** Giúp quản lý cấu trúc hạ tầng dạng phân cấp (Root Application quản lý các Child Applications). Điều này giúp triển khai toàn bộ nền tảng (Platform) chỉ bằng một câu lệnh duy nhất.

### 2. Tại Sao Phải Dùng Argo Rollouts Thay Vì Deployment Mặc Định Của Kubernetes?
* **Vấn đề của Kubernetes Deployment (`strategy: RollingUpdate`):**
  * Không hỗ trợ phân chia traffic theo tỷ lệ chính xác (chỉ có thể tăng giảm số lượng replica).
  * Không tích hợp cơ chế tự động đánh giá sức khỏe phiên bản mới thông qua metrics (chỉ kiểm tra container chạy/không chạy bằng Liveness/Readiness probes).
  * Khi bản mới bị lỗi logic (ví dụ trả về mã lỗi 500 nhưng pod vẫn chạy), `RollingUpdate` vẫn tiếp tục thay thế hết các pod cũ, dẫn tới sập toàn hệ thống. Rollback lúc này bắt buộc phải can thiệp thủ công.
* **Giải pháp từ Argo Rollouts:**
  * Cho phép chia nhỏ traffic theo trọng số tùy ý (ví dụ: bắt đầu với **25%** traffic).
  * Định nghĩa các bước phát hành thông minh (canary steps) kết hợp thời gian pause.
  * **AnalysisTemplate:** Đây là tính năng đột phá, cho phép kết nối trực tiếp vào Prometheus để kiểm tra SLO thời gian thực. Nếu phát hiện tỉ lệ lỗi tăng quá ngưỡng thiết lập, hệ thống tự động **Abort và Rollback** ngay dưới 2 phút, giảm thiểu tối đa tầm ảnh hưởng lỗi (Blast Radius) đối với khách hàng thực tế.

### 3. Tại Sao Sử Dụng Prometheus & ServiceMonitor?
* **Vấn đề của Prometheus truyền thống:**
  * Phải cấu hình tĩnh (Static Config) danh sách IP/Domain của các target cần scrape trong file cấu hình chính của Prometheus. Mỗi lần thêm microservice mới, phải sửa cấu hình Prometheus và khởi động lại.
* **Giải pháp từ Prometheus Operator (ServiceMonitor):**
  * Áp dụng tư duy **Declarative Monitoring**. Người phát triển ứng dụng tự định nghĩa một tài nguyên [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml) đi kèm với ứng dụng của họ.
  * Prometheus Operator tự động quét toàn cluster, tìm các ServiceMonitor có nhãn khớp (`release: kube-prometheus-stack`), rồi tự động cập nhật danh sách scrape target của Prometheus mà không cần can thiệp vào Prometheus Server.

### 4. Tại Sao Chọn Cấu Hình Email SMTP Gmail Trong Alertmanager?
* **Tính thực tế trong vận hành:** Email là kênh thông báo phổ biến, chính thức và dễ tiếp cận nhất cho các đội ngũ vận hành vừa và nhỏ.
* **Sự tách biệt cấu hình:** Thiết lập định tuyến linh hoạt (Routing). Các lỗi thường gặp có thể được bỏ qua (`null` receiver), nhưng cảnh báo vi phạm SLO quan trọng như `ApiLowSuccessRateSLO` sẽ được định tuyến cụ thể đến Email của kỹ sư chịu trách nhiệm (`email-receiver`).
* **Sử dụng Mật khẩu ứng dụng (App Password):** Đảm bảo tính bảo mật cho tài khoản Gmail chính chủ khi chạy trong môi trường tự động hóa mà không cần tắt xác thực 2 lớp (2FA).

---

## Sự Kết Hợp Và Đồng Bộ Giữa Các Công Nghệ

Sự ăn khớp giữa các công nghệ được thể hiện qua sơ đồ tích hợp sau:

```
[ Git Repository ]
       │
       ▼ (Pull-based Sync)
   [ ArgoCD ] ───► Quản lý vòng đời tài nguyên K8s
       │
       ├─► Tạo [ Argo Rollout ] ───► Điều khiển lưu lượng (Traffic Routing)
       │         │
       │         ▼ (Kích hoạt phân tích)
       ├─► Tạo [ AnalysisTemplate ] ◄─┐
       │                              │ (Truy vấn chất lượng)
       ├─► Tạo [ ServiceMonitor ]     │
       │         │                    │
       │         ▼ (Scrape target)    │
       └─► Tạo [ PrometheusRule ]     │
                 │                    │
                 ▼                    ▼
           [ Prometheus Server ] ─────┘
                 │
                 ▼ (Gửi Alert khi SLO vi phạm)
           [ Alertmanager ] ───► [ Gmail SMTP ] ───► [ Email Vận Hành ]
```
