# 📄 Giải thích Code: [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml)

File manifest này định nghĩa hai tài nguyên cốt lõi cho Backend API: một **Rollout** của Argo Rollouts (thay thế cho Deployment truyền thống) và một **Service** định tuyến mạng.

---

## 1. Thành phần 1: Rollout (`api`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata: 
  name: api
  namespace: demo
  labels: 
    app: api
spec:
  replicas: 4
  selector: 
    matchLabels: 
      app: api
  template:
    metadata: 
      labels: 
        app: api
    spec:
      containers:
      - name: api
        image: w9-api:1
        imagePullPolicy: IfNotPresent
        ports: [ { name: http, containerPort: 8080 } ]
        env:
        - { name: ERROR_RATE, value: "1" }
        - { name: VERSION,    value: "v5" }
        readinessProbe: { httpGet: { path: /healthz, port: 8080 } }
  strategy:
    canary:
      analysis:
        templates:
        - templateName: api-success-rate
      steps:
      - setWeight: 25
      - pause: { duration: 3m }
      - setWeight: 50
      - pause: { duration: 1m }
      - setWeight: 100
```

### Giải thích chi tiết:
*   `kind: Rollout`: Đối tượng tùy biến của Argo Rollouts, thay thế hoàn toàn Deployment mặc định để hỗ trợ kỹ thuật phát hành tăng tiến Canary.
*   `spec.replicas: 4`: Hệ thống luôn duy trì **4 Pods** hoạt động ổn định trong trạng thái bình thường.
*   `spec.template.spec.containers`:
    *   `image: w9-api:1`: Sử dụng image API chạy server Flask đã build cục bộ.
    *   `imagePullPolicy: IfNotPresent`: Lấy image từ Minikube cache local.
    *   `ports`: Container chạy trên cổng 8080 và được đặt tên cổng là `http`.
    *   `env`: Nạp các biến môi trường cấu hình cho server Flask:
        *   `ERROR_RATE: "1"`: **Lưu ý quan trọng.** Đặt giá trị bằng `1` (100% lỗi) để cố tình kích hoạt lỗi nhằm kiểm tra xem cơ chế Canary có tự động Abort và Rollback hay không. Trong thực tế chạy thật, giá trị này sẽ bằng `"0"`.
        *   `VERSION: "v5"`: Đánh dấu phiên bản hiện tại là `v5`.
    *   `readinessProbe`: K8s sẽ thăm dò cổng HTTP `/healthz` trước khi cho phép Pod nhận traffic.
*   `spec.strategy.canary`: Cấu hình chiến lược Canary.
    *   `analysis`: Liên kết phân tích.
        *   `templates`: Chỉ định sử dụng khuôn mẫu phân tích chất lượng có tên là `api-success-rate` đã định nghĩa trong file [analysis.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/analysis.yaml). Phân tích này sẽ chạy nền song song ngay khi Rollout bắt đầu.
    *   `steps`: Định nghĩa các bước tăng tải và dừng nghỉ của traffic.
        *   `- setWeight: 25`: Bước 1. Điều phối **25%** tổng traffic sang phiên bản mới (tương đương chạy 1 Pod mới và 3 Pods cũ).
        *   `- pause: { duration: 3m }`: Tạm dừng bước 1 trong **3 phút** để chạy Analysis đánh giá metric từ Prometheus.
        *   `- setWeight: 50`: Bước 2. Nếu sau 3 phút bước 1 an toàn, tăng lưu lượng lên **50%** traffic (2 Pods mới, 2 Pods cũ).
        *   `- pause: { duration: 1m }`: Tạm dừng bước 2 trong **1 phút** để tiếp tục phân tích chất lượng.
        *   `- setWeight: 100`: Bước 3. Chuyển hoàn toàn **100%** traffic sang bản mới, tắt bỏ các Pods bản cũ. Hoàn tất rollout.

---

## 2. Thành phần 2: Service (`api`)

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: demo
  labels:
    app: api
spec:
  selector:
    app: api
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

### Giải thích chi tiết:
*   `kind: Service`: Tạo ra một địa chỉ IP ảo ổn định để định tuyến các request đi vào nhóm Pods của API.
*   `metadata.labels.app: api`: Gắn nhãn cho Service. Nhãn này sẽ được dùng bởi Prometheus [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml) để tìm kiếm và quét dữ liệu metrics tự động.
*   `spec.selector.app: api`: Kết nối và chia tải traffic tới tất cả các Pods (cả bản cũ và bản Canary mới) đang được quản lý bởi Rollout có nhãn `app: api`.
*   `ports`: Chuyển tiếp cổng. Lắng nghe ở cổng `8080` của Service và đẩy trực tiếp vào cổng `8080` của container Flask.
