# 📄 Giải thích Code: [web.yaml (ArgoCD App)](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/web.yaml)

File manifest này định nghĩa cấu hình ArgoCD Application cho thành phần **Web (Frontend) Service**. Đây là một ứng dụng con được quản lý bởi Root Application.

---

## 1. Nội dung Code

```yaml
# file: argocd/apps/web.yaml (tạo folder argocd/apps/)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: web, namespace: argocd }
spec:
  project: default
  source: { repoURL: https://github.com/nabe39/vohongduc-aws-accelerator-p2.git, path: cloud/w9/lab/gitops/k8s }
  destination: { server: https://kubernetes.default.svc, namespace: demo }
  syncPolicy: { automated: { prune: true, selfHeal: true } }
```

---

## 2. Giải thích chi tiết cấu hình

*   `kind: Application`: Xác định đây là một ứng dụng con quản lý bởi ArgoCD Root.
*   `metadata.name: web`: Đặt tên ứng dụng hiển thị là `web`.
*   `spec.source.path: cloud/w9/lab/gitops/k8s`: Thư mục trong git chứa cấu hình K8s cho Web Service bao gồm: [web.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/web.yaml) (ConfigMap, Deployment, Service) và [namespace.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/namespace.yaml).
*   `spec.destination.namespace: demo`: Triển khai toàn bộ tài nguyên frontend web vào namespace `demo` để chạy song hành và kết nối mạng nội bộ với backend `api`.
*   `spec.syncPolicy`: Tự động đồng bộ hóa.
    *   `automated.prune: true`: Tự động dọn dẹp các tài nguyên thừa trên cluster nếu trên Git repo thư mục `k8s` đã xóa chúng đi.
    *   `automated.selfHeal: true`: Tự động khôi phục cấu hình trên cluster về giống Git khi phát hiện có ai đó can thiệp thay đổi thủ công trên cluster.
