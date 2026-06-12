# 📄 Giải thích Code: [namespace.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/namespace.yaml)

File manifest này định nghĩa Namespace trong Kubernetes để nhóm các tài nguyên của ứng dụng chạy thử nghiệm (Demo) lại với nhau, tránh xung đột với các ứng dụng khác trong cluster.

---

## 1. Nội dung Code

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  annotations: { argocd.argoproj.io/sync-wave: "-1" }
```

---

## 2. Giải thích chi tiết từng dòng

*   `apiVersion: v1`: Khai báo phiên bản API của Kubernetes được sử dụng để tạo đối tượng này. `v1` là phiên bản core/mặc định của Namespace.
*   `kind: Namespace`: Xác định loại tài nguyên K8s cần tạo là một **Namespace** (Không gian tên ảo). Nó giúp cô lập các tài nguyên (Pods, Services, ConfigMaps...) giữa các môi trường khác nhau.
*   `metadata`: Chứa các thông tin định danh của tài nguyên.
    *   `name: demo`: Đặt tên cho Namespace này là `demo`. Mọi workload của lab (như frontend `web` và backend `api`) sẽ được deploy vào namespace này.
    *   `annotations`: Các nhãn chú thích bổ sung không dùng để query mà dùng cho các công cụ tích hợp (ở đây là ArgoCD).
        *   `argocd.argoproj.io/sync-wave: "-1"`: Khai báo **Sync Wave** cho ArgoCD. Giá trị `-1` (nhỏ hơn mặc định là `0` và `1`) chỉ thị cho ArgoCD biết cần phải **tạo Namespace này trước tiên** trong quá trình đồng bộ hóa. Điều này đảm bảo khi các tài nguyên khác chạy ở các wave sau (như ConfigMap ở wave 0, Deployment ở wave 1) deploy vào namespace `demo` thì namespace này đã tồn tại sẵn trên cluster.

---

## 3. Liên kết trong dự án

*   Namespace `demo` này là đích đến (destination) của hầu hết các cấu hình triển khai, ví dụ như ứng dụng web định nghĩa trong [web.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/web.yaml) và ứng dụng api trong [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml).
*   Được tham chiếu bởi cấu hình ứng dụng con trong [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/api.yaml) và [web.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/web.yaml) ở trường `destination.namespace: demo`.
