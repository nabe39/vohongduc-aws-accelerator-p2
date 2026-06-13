# 📄 Giải thích Code: [api.yaml (ArgoCD App)](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/api.yaml)

File manifest này định nghĩa cấu hình ArgoCD Application cho thành phần **API (Backend) Service**. Đây là một ứng dụng con được quản lý bởi Root Application.

---

## 1. Nội dung Code

```yaml
# file: argocd/apps/api.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: api, namespace: argocd }
spec:
  project: default
  source: { repoURL: https://github.com/nabe39/vohongduc-aws-accelerator-p2.git, path: cloud/w9/lab/gitops/k8s/k8s-api }
  destination: { server: https://kubernetes.default.svc, namespace: demo }
  syncPolicy: { automated: { prune: true, selfHeal: true } }
```

---

## 2. Giải thích chi tiết cấu hình

*   `kind: Application`: Đây là một tài nguyên ứng dụng con của ArgoCD.
*   `metadata.name: api`: Đặt tên ứng dụng con này là `api`. Tên này sẽ hiển thị trên giao diện quản trị ArgoCD UI.
*   `metadata.namespace: argocd`: Được định nghĩa và quản trị trong namespace của ArgoCD.
*   `spec.source`: Cấu hình nguồn chứa manifest Kubernetes của ứng dụng API.
    *   `repoURL`: Link git repository chứa mã nguồn cấu hình.
    *   `path: cloud/w9/lab/gitops/k8s/k8s-api`: Thư mục chứa các file manifest YAML liên quan trực tiếp đến ứng dụng API bao gồm: [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml) (Rollout & Service), [analysis.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/analysis.yaml) (AnalysisTemplate), [prom-rules.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/prom-rules.yaml) (SLO alert) và [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml).
*   `spec.destination`: Đích deploy thực tế của ứng dụng API.
    *   `server`: Deploy vào cluster Kubernetes nội bộ.
    *   `namespace: demo`: Triển khai các pod, service, rollout của API vào namespace `demo` (được tách biệt với namespace `argocd` và `monitoring`).
*   `spec.syncPolicy`: Tự động đồng bộ hóa.
    *   `automated.prune: true`: Tự động xóa các manifest K8s thừa trong namespace `demo` nếu trên Git repo thư mục `k8s-api` đã xóa đi.
    *   `automated.selfHeal: true`: Tự động đồng bộ ngược lại từ Git nếu ai đó gõ lệnh sửa đổi nóng trên cluster.
