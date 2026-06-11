# Hướng dẫn chạy dự án W9 (GitOps & Observability & Canary)

Dự án này tích hợp các kiến thức và thực hành cốt lõi của tuần W9 bao gồm:
*   **GitOps & CI/CD** (ArgoCD, App-of-Apps, Sync Waves).
*   **Observability** (OpenTelemetry SDK, Prometheus, Grafana, Loki, ServiceMonitor).
*   **Progressive Delivery** (Argo Rollouts, Canary deployment, Manual promote & abort).

---

## 📌 Yêu cầu hệ thống (Prerequisites)
*   **Docker Desktop** (Đã khởi động).
*   **WSL 2** (Ubuntu 20.04 hoặc 24.04).
*   **Minikube**, **kubectl**, **git** đã cài đặt trong WSL.

---

## 🚀 Phần 1: Hướng dẫn chạy dự án lần đầu (Step-by-Step)

### Bước 1: Khởi động Minikube với cấu hình tài nguyên đủ lớn
Vì hệ thống chạy đồng thời ArgoCD, Argo Rollouts và Prometheus Stack nên cần cấp đủ CPU và RAM cho Minikube:
```bash
minikube start -p w9 --cpus=4 --memory=6g
```

### Bước 2: Build Docker Image và nạp vào Minikube
Di chuyển vào thư mục dự án và build image ứng dụng Flask (chứa exporter Prometheus). Sau đó nạp trực tiếp image này vào cụm Minikube mà không cần đẩy lên DockerHub:
```bash
# Di chuyển đến thư mục k8s
cd cloud/w9/lab/gitops/k8s

# Build image cho app Flask
docker build -t w9-api:1 ./app/

# Nạp image vào minikube w9
minikube image load w9-api:1 -p w9
```
*Kiểm tra lại xem image đã sẵn sàng chưa bằng lệnh:*
```bash
minikube image ls -p w9 | grep w9-api
```

### Bước 3: Cài đặt ArgoCD lên Cluster
Cài đặt ArgoCD thủ công một lần duy nhất lên cluster qua manifest chính thức:
```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
*Đợi cho đến khi các Pod trong namespace `argocd` chuyển sang trạng thái `Running`:*
```bash
kubectl get pods -n argocd -w
```

### Bước 4: Khởi chạy mô hình App-of-Apps (Root Application)
Áp dụng file cấu hình `root.yaml` để ArgoCD tự động nhận diện và cài đặt các ứng dụng con (`web`, `argo-rollouts`, `kube-prometheus-stack`):
```bash
kubectl apply -f argocd/root.yaml
```
*Sau khi apply `root.yaml`, ArgoCD sẽ tự động đồng bộ (Sync) các file cấu hình ứng dụng con nằm trong thư mục `argocd/apps/` lên cluster.*

> [!NOTE]
> *   **Namespace `demo`** được cấu hình chạy trước tiên (`sync-wave: "-1"`).
> *   **ConfigMap** và **Secret** chạy ở `sync-wave: "0"`.
> *   **Deployment** chạy ở `sync-wave: "1"`.
> *   **Service** chạy ở `sync-wave: "2"`.

### Bước 5: Cài đặt Argo Rollouts CLI Plugin (WSL)
Để theo dõi và điều khiển quá trình Canary Rollout một cách trực quan, hãy cài đặt plugin `kubectl-argo-rollouts` trong WSL:
```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### Bước 6: Khai báo ứng dụng API (Argo Rollout) lên ArgoCD
Để đưa ứng dụng API chạy dưới dạng **Rollout** thay vì Deployment thông thường, hãy tạo file khai báo Application cho `api` trong thư mục `argocd/apps/api.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nabe39/vohongduc-aws-accelerator-p2.git
    path: cloud/w9/lab/gitops/k8s/k8s-api
    targetRevision: feat/lab2-w9  # Nhánh git của bạn
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
Sau đó commit và push file này lên repository Git của bạn. ArgoCD sẽ tự động phát hiện và deploy tài nguyên Rollout của API (`k8s-api/api.yaml` và `k8s-api/servicemonitor.yaml`) vào namespace `demo`.

### Bước 7: Mở Port-Forward để truy cập các Dashboard
Chạy các lệnh port-forward ở các tab terminal khác nhau để kết nối vào các dịch vụ từ trình duyệt máy local (Windows):
```bash
# 1. Truy cập ArgoCD UI (https://localhost:8080)
# Tài khoản mặc định: admin
# Lấy mật khẩu: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Truy cập Prometheus UI (http://localhost:9090)
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090

# 3. Truy cập Grafana UI (http://localhost:3000)
# Tài khoản mặc định: admin / prom-operator
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000
```

### Bước 8: Tạo lưu lượng tải giả lập (Load Generator)
Tạo một Pod chạy vòng lặp gửi request liên tục đến API để Prometheus có dữ liệu vẽ biểu đồ:
```bash
kubectl -n demo run load --image=busybox --restart=Never -- sh -c "while true; do wget -qO- api:8080/; done"
```

### Bước 9: Thực hiện Canary Rollout bằng tay (Lab 4)
1. Mở file `cloud/w9/lab/gitops/k8s/k8s-api/api.yaml` và thay đổi giá trị `VERSION` từ `"v1"` sang `"v2"`.
2. Commit và push lên Git:
   ```bash
   git commit -am "Deploy api version v2" && git push
   ```
3. Chạy lệnh theo dõi tiến trình Canary dạng sơ đồ cây:
   ```bash
   kubectl argo rollouts get rollout api -n demo --watch
   ```
4. Quan sát thấy tiến trình dừng lại ở **25%** (`Status: Paused`). 1 Pod mới chạy bản `v2` và 3 Pod cũ chạy bản `v1`.
5. Đưa ra quyết định:
   * **Nếu chạy tốt (Promote):** Cho phép lên tiếp bản mới:
     ```bash
     kubectl argo rollouts promote api -n demo
     ```
   * **Nếu phát hiện lỗi (Abort):** Hủy bỏ, rollback ngay lập tức về bản cũ:
     ```bash
     kubectl argo rollouts abort api -n demo
     ```

---

## 🔄 Phần 2: Cách khởi động lại dự án sau khi tắt máy (Restart Guide)

Khi bạn đã hoàn thành các bước thiết lập ở trên, nếu tắt máy/khởi động lại máy tính, bạn **không cần cài đặt lại** bất kỳ tài nguyên nào từ đầu. ArgoCD có cơ chế tự động đồng bộ (Self-Heal & Auto Sync) nên toàn bộ ứng dụng sẽ tự động phục hồi về trạng thái cũ dựa trên Git.

Hãy làm theo các bước sau để khởi động lại nhanh nhất:

### Bước 1: Khởi động Docker Desktop
Hãy đảm bảo phần mềm **Docker Desktop** trên Windows đã được khởi động và chạy ổn định.

### Bước 2: Khởi động lại Cluster Minikube
Mở terminal WSL và khởi chạy lại profile minikube cũ:
```bash
minikube start -p w9
```
*Minikube sẽ tự động khởi tạo lại máy ảo, gắn cổng mạng và khởi chạy các container hệ thống đã có sẵn.*

### Bước 3: Kiểm tra trạng thái của các dịch vụ
Chờ khoảng 2-3 phút để toàn bộ Pod hệ thống khởi chạy ổn định, sau đó chạy lệnh kiểm tra:
```bash
kubectl get pods -A
```
*Đảm bảo toàn bộ Pod trong các namespace `argocd`, `demo`, `monitoring` và `argo-rollouts` đều ở trạng thái `Running` hoặc `Completed`.*

> [!TIP]
> **Tại sao không cần apply lại file YAML?**
> Vì cấu hình đồng bộ tự động (Auto Sync) của ArgoCD đã được lưu trữ trong cluster. Khi cluster chạy lại, ArgoCD controller sẽ tự động quét repository Git và đồng bộ mọi thay đổi mới nhất về cụm.

### Bước 4: Mở lại các Port-Forward cần thiết
Do IP/Port của Minikube thay đổi sau khi khởi chạy lại, các kết nối port-forward cũ từ máy Windows sẽ bị ngắt. Bạn cần chạy lại các lệnh sau ở các tab terminal ẩn để truy cập lại Dashboard:
```bash
# Mở cổng ArgoCD UI (https://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Mở cổng Prometheus UI (http://localhost:9090)
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090 &

# Mở cổng Grafana UI (http://localhost:3000)
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000 &
```
*(Thêm ký tự `&` ở cuối lệnh để chạy ngầm tiến trình port-forward mà không cần mở nhiều tab terminal).*

### Bước 5: Tiếp tục làm việc
* Bây giờ toàn bộ hệ thống đã chạy lại bình thường. Bạn có thể chỉnh sửa mã nguồn, đẩy lên Git và quan sát ArgoCD tự động đồng bộ như bình thường.
* Nếu muốn quản lý tải giả lập hoặc kiểm tra hệ thống, hãy làm theo hướng dẫn chi tiết ở phần dưới đây.

---

## 🔍 Hướng dẫn quản lý Traffic giả lập & Kiểm tra hệ thống

### 1. Quản lý lưu lượng tải giả lập (Load Generator)
*   **Tạo tải giả lập:** Chạy một Pod gửi request liên tục (mỗi giây một lần) vào ứng dụng `api`:
    ```bash
    kubectl -n demo run load-test --image=busybox --restart=Never -- sh -c "while true; do wget -qO- http://api:8080/; sleep 1; done"
    ```
*   **Theo dõi hoạt động của tải:** Xem logs từ Pod load-test để xác định xem traffic có được gửi thành công không:
    ```bash
    kubectl logs -n demo load-test --tail=10
    ```
    *Kết quả đúng:* Sẽ liên tục in ra phản hồi từ API dạng `{"ok":true,"version":"v1"}`.
*   **Xóa tải giả lập (Dừng gửi traffic):** 
    ```bash
    kubectl -n demo delete pod load-test
    ```

### 2. Các lệnh kiểm tra và xác minh nhanh
*   **Kiểm tra trạng thái đồng bộ của ArgoCD:**
    ```bash
    kubectl get applications -n argocd
    ```
    *Đảm bảo các ứng dụng (bao gồm `api` và `web`) đều báo trạng thái `Synced` và `Healthy`.*
*   **Kiểm tra tài nguyên K8s của ứng dụng `api`:**
    ```bash
    kubectl get all -n demo -l app=api
    ```
    *Đảm bảo các Pods của `api` ở trạng thái `Running` và Service `api` đang lắng nghe ở cổng `8080`.*
*   **Theo dõi trực tiếp quá trình Canary Rollout:**
    ```bash
    kubectl argo rollouts get rollout api -n demo --watch
    ```
*   **Kiểm tra logs của ứng dụng `api`:**
    ```bash
    kubectl logs -n demo -l app=api --tail=20
    ```
