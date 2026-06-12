# 📄 Giải thích Code: [argo-rollouts.yaml (ArgoCD App)](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/argo-rollouts.yaml)

File manifest này định nghĩa cấu hình ArgoCD Application để tự động cài đặt **Argo Rollouts Controller** lên Kubernetes cluster thông qua Helm Chart chính thức.

---

## 1. Nội dung Code

```yaml
# file: argocd/apps/argo-rollouts.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-rollouts
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-rollouts
    targetRevision: 2.37.7
    helm:
      values: |
        # override values here as YAML
        controller:
          replicaCount: 1
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-rollouts
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

---

## 2. Giải thích chi tiết cấu hình

*   `kind: Application`: Khai báo đây là một ứng dụng con quản lý bởi ArgoCD Root.
*   `metadata.name: argo-rollouts`: Đặt tên hiển thị ứng dụng là `argo-rollouts`.
*   `spec.source`: Cấu hình nguồn từ Helm Repository ngoài thay vì thư mục Git nội bộ.
    *   `repoURL: https://argoproj.github.io/argo-helm`: Đường dẫn của kho lưu trữ Helm charts chính thức từ dự án Argo.
    *   `chart: argo-rollouts`: Tên gói ứng dụng (Helm Chart) cần cài đặt là `argo-rollouts`.
    *   `targetRevision: 2.37.7`: Phiên bản Helm chart cụ thể được cài đặt để đảm bảo tính ổn định và nhất quán giữa các môi trường (Immutable Versioning).
    *   `helm.values`: Ghi đè các thông số mặc định của Helm chart bằng định dạng YAML block.
        *   `controller.replicaCount: 1`: Chỉ chạy duy nhất **1 Pod điều khiển (Controller)** để tiết kiệm CPU và RAM trong cụm chạy Minikube cục bộ (mặc định Helm có thể chạy nhiều hơn).
*   `spec.destination.namespace: argo-rollouts`: Deploy toàn bộ tài nguyên của bộ điều khiển Rollouts vào namespace riêng biệt có tên `argo-rollouts`.
*   `spec.syncPolicy`: Cấu hình đồng bộ.
    *   `syncOptions`:
        *   `CreateNamespace=true`: Chỉ thị cho ArgoCD tự động tạo namespace `argo-rollouts` trên cluster nếu nó chưa tồn tại trước khi cài đặt Helm Chart.
        *   `ServerSideApply=true`: Sử dụng tính năng apply từ phía Kubernetes Server (Server-Side Apply). Tính năng này giúp bỏ qua một số xung đột về schema YAML và cải thiện tốc độ apply manifest khi làm việc với các Custom Resource Definitions (CRDs) lớn.
