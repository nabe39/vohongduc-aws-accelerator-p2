# 📄 Giải thích Code: [kube-prometheus-stack.yaml (ArgoCD App)](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/kube-prometheus-stack.yaml)

File manifest này định nghĩa cấu hình ArgoCD Application để cài đặt **Kube-Prometheus-Stack** (bộ công cụ giám sát chuẩn Cloud Native bao gồm Prometheus, Grafana, Alertmanager) qua Helm Chart chính thức.

---

## 1. Nội dung Code

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 65.1.1
    helm:
      values: |
        # repo: + ruleSelector, grafana adminPassword
        prometheus:
          prometheusSpec:
            serviceMonitorSelectorNilUsesHelmValues: false
        alertmanager:
          alertmanagerSpec:
            configSecret: alertmanager-smtp-config
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

---

## 2. Giải thích chi tiết cấu hình và các tham số ghi đè quan trọng

*   `kind: Application`: Khai báo đây là một ứng dụng con quản lý bởi ArgoCD Root.
*   `spec.source`: Cấu hình nguồn Helm Chart.
    *   `repoURL: https://prometheus-community.github.io/helm-charts`: Đường dẫn repository của cộng đồng Prometheus.
    *   `chart: kube-prometheus-stack`: Helm chart chứa toàn bộ stack Prometheus Operator, Prometheus Server, Alertmanager, Grafana và Node Exporter.
    *   `targetRevision: 65.1.1`: Khóa cứng phiên bản chart `65.1.1` để tránh phát sinh lỗi tương thích khi chạy thực tế.
    *   `helm.values`: Phần ghi đè các tham số cực kỳ quan trọng cho bài lab.
        *   `prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues: false`: Mặc định, Prometheus chỉ scrape (thu thập metrics) của các ServiceMonitors có nhãn trùng với Helm release này. Đặt trường này về `false` sẽ tắt bộ lọc nhãn mặc định, cho phép Prometheus **tìm kiếm và thu thập dữ liệu từ tất cả các ServiceMonitor chạy trên toàn cụm K8s**, bất kể nhãn release là gì. Điều này giúp cho file [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml) trong namespace `demo` được Prometheus phát hiện tự động.
        *   `alertmanager.alertmanagerSpec.configSecret: alertmanager-smtp-config`: Chỉ định Alertmanager đọc file cấu hình bảo mật SMTP gửi mail của nó từ Kubernetes Secret có tên là `alertmanager-smtp-config`. Cấu hình này giúp giấu kín mật khẩu email SMTP, bảo vệ thông tin cá nhân.
*   `spec.destination.namespace: monitoring`: Deploy toàn bộ stack giám sát vào namespace chuyên dụng `monitoring` để gom nhóm các công cụ quản trị.
*   `spec.syncPolicy.syncOptions`: Tự động tạo namespace `monitoring` (`CreateNamespace=true`) và sử dụng Server-Side Apply (`ServerSideApply=true`) để cài đặt các Custom Resource Definitions (CRDs) cực lớn của Prometheus Operator.
