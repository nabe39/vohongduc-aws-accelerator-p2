# 📄 Giải thích Code: [root.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/root.yaml)

File manifest này định nghĩa **Root Application** (Ứng dụng gốc) của mô hình **App-of-Apps** trong ArgoCD. Nó đóng vai trò là "mỏ neo" quản lý vòng đời của tất cả các ứng dụng thành phần khác trong dự án.

---

## 1. Nội dung Code

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: 
  name: root 
  namespace: argocd 
spec:
  project: default
  source:
    repoURL: https://github.com/nabe39/vohongduc-aws-accelerator-p2.git
    path: cloud/w9/lab/gitops/k8s/argocd/apps
  destination: 
    server: https://kubernetes.default.svc
    namespace: argocd 
  syncPolicy: 
    automated: 
      prune: true 
      selfHeal: true
```

---

## 2. Giải thích chi tiết từng trường cấu hình

*   `apiVersion: argoproj.io/v1alpha1`: Sử dụng API định nghĩa tài nguyên của ArgoCD Project.
*   `kind: Application`: Xác định tài nguyên cần tạo là một **Application** của ArgoCD (Custom Resource Definition - CRD).
*   `metadata`:
    *   `name: root`: Đặt tên ứng dụng gốc này là `root`.
    *   `namespace: argocd`: Bắt buộc phải deploy vào namespace `argocd` vì đây là nơi Controller của ArgoCD chạy để quét và quản lý các Application khác.
*   `spec`: Phần mô tả hành vi đồng bộ.
    *   `project: default`: Gán ứng dụng vào project mặc định (`default`) của ArgoCD.
    *   `source`: Khai báo nguồn mã nguồn cấu hình mong muốn (Desired State).
        *   `repoURL`: Link git repository chứa toàn bộ mã nguồn và cấu hình dự án của bạn (`https://github.com/nabe39/vohongduc-aws-accelerator-p2.git`).
        *   `path: cloud/w9/lab/gitops/k8s/argocd/apps`: Thư mục trong git repo chứa các file YAML định nghĩa các ứng dụng con. ArgoCD Root sẽ tự động đọc tất cả các tệp YAML trong thư mục này và tạo ra các ứng dụng con tương ứng.
    *   `destination`: Khai báo đích đến để deploy.
        *   `server: https://kubernetes.default.svc`: Deploy vào chính Kubernetes Cluster nội bộ đang chạy ArgoCD (In-Cluster).
        *   `namespace: argocd`: Tạo các tài nguyên ứng dụng con (Application K8s resources) trong namespace `argocd`.
    *   `syncPolicy`: Cơ chế tự động đồng bộ.
        *   `automated`: Kích hoạt đồng bộ tự động mà không cần bấm nút "Sync" thủ công trên UI.
        *   `prune: true`: Tự động xóa bỏ các tài nguyên trên cluster nếu chúng đã bị xóa khỏi Git repository. Giúp giữ sạch hệ thống.
        *   `selfHeal: true`: Tự động khôi phục cấu hình trên cluster về giống Git khi phát hiện có ai đó can thiệp thay đổi thủ công trên cluster (Anti-Drift).
