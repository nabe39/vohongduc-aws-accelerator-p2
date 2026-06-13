# 📄 Giải thích Code: [web.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/web.yaml)

File manifest này định nghĩa ba tài nguyên Kubernetes dành cho ứng dụng **frontend web**: một **ConfigMap** lưu trữ cấu hình, một **Deployment** quản lý các bản chạy (Pods), và một **Service** định tuyến traffic.

---

## 1. Thành phần 1: ConfigMap (`web-config`)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "0"
data:
  MESSAGE: "hello from gitops"
```

### Giải thích:
*   `kind: ConfigMap`: Đối tượng dùng để tách cấu hình (dạng Key-Value) ra khỏi container image để dễ dàng quản trị mà không cần build lại image.
*   `namespace: demo`: Đặt trong namespace `demo` (sau khi namespace được tạo ở wave -1).
*   `argocd.argoproj.io/sync-wave: "0"`: Tạo ở **Sync Wave 0**. ConfigMap phải được tạo trước Deployment (ở wave 1) để khi Pod chạy lên có cấu hình nạp sẵn.
*   `data`: Chứa biến cấu hình `MESSAGE` với giá trị `"hello from gitops"`.

---

## 2. Thành phần 2: Deployment (`web`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: w9-api:1
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
        envFrom:
        - configMapRef:
            name: web-config
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
```

### Giải thích:
*   `kind: Deployment`: Khai báo bộ điều khiển giúp quản lý số lượng và trạng thái của các Pod chạy ứng dụng web.
*   `argocd.argoproj.io/sync-wave: "1"`: Tạo ở **Sync Wave 1**, chạy sau khi ConfigMap đã có sẵn.
*   `spec.replicas: 2`: Chạy cố định **2 bản sao (Pods)** của ứng dụng để đảm bảo tính sẵn sàng cao và phân tải.
*   `spec.selector.matchLabels`: Deployment sẽ quản lý các Pods có nhãn `app: web`.
*   `template`: Bản thiết kế để sinh ra các Pod.
    *   `metadata.labels.app: web`: Đóng nhãn cho Pod được sinh ra là `app: web`. Nhãn này cực kỳ quan trọng để Service và ServiceMonitor tìm thấy Pod.
    *   `image: w9-api:1`: Sử dụng image `w9-api` phiên bản `1` (Flask application được build cục bộ).
    *   `imagePullPolicy: IfNotPresent`: Chỉ thị K8s lấy image trực tiếp từ Docker cache của Minikube (được nạp bằng lệnh `minikube image load`) thay vì cố gắng kéo từ DockerHub, tránh lỗi kéo image thất bại.
    *   `containerPort: 8080`: Ứng dụng Flask chạy và lắng nghe ở cổng `8080` bên trong container.
    *   `envFrom`: Nạp toàn bộ các cặp Key-Value từ ConfigMap `web-config` thành các biến môi trường (Environment Variables) trong container.
    *   `readinessProbe`: Lớp kiểm tra sức khỏe trước khi đưa Pod vào nhận traffic từ Service.
        *   `httpGet.path: /healthz`: Gửi HTTP GET request định kỳ tới endpoint `/healthz` ở cổng `8080`. Nếu trả về mã status `200 OK`, Pod được xác định là sẵn sàng hoạt động.

---

## 3. Thành phần 3: Service (`web`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

### Giải thích:
*   `kind: Service`: Tạo ra một điểm truy cập mạng ổn định (ClusterIP) đại diện cho nhóm 2 Pods của web.
*   `argocd.argoproj.io/sync-wave: "2"`: Tạo ở **Sync Wave 2**, sau khi các Pods ở Deployment wave 1 đã được khởi động.
*   `metadata.labels.app: web`: Nhãn của Service này, giúp Prometheus `ServiceMonitor` có thể tự động phát hiện và cấu hình thu thập metric.
*   `spec.selector.app: web`: Định tuyến tất cả traffic đi vào Service này đến các Pods có nhãn `app: web`.
*   `ports`: Cấu hình chuyển hướng cổng.
    *   `port: 80`: Cổng lắng nghe của Service ở ngoài (cổng HTTP chuẩn). Người dùng truy cập qua `http://web/` (port 80).
    *   `targetPort: 8080`: Service sẽ forward (chuyển tiếp) traffic đi vào cổng 80 tới cổng `8080` thực tế của container Flask.
