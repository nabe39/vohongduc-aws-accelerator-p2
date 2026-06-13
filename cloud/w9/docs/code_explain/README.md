# 📚 Chỉ Mục Tài Liệu Giải Thích Mã Nguồn (Code Explanations Index)

Thư mục này chứa các tài liệu giải thích chi tiết từng dòng code và cấu hình của dự án nhằm giúp bạn hiểu rõ vai trò và cách hoạt động của từng tệp tin trong thư mục `lab`.

---

## 📂 Danh sách tài liệu giải thích chi tiết

### 1. Cấu hình Kubernetes nền tảng (Base K8s Manifests)
*   🌐 **[namespace_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/namespace_yaml.md)**: Giải thích cách định nghĩa không gian tên ảo `demo` và thứ tự ưu tiên Sync Wave.
*   🖥️ **[web_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/web_yaml.md)**: Giải thích cấu hình ConfigMap, Deployment và Service của Frontend Web.

### 2. Ứng dụng & Cấu hình Docker (Application & Image)
*   🐍 **[app_app_py.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/app_app_py.md)**: Giải thích mã nguồn API Flask, cách xuất metrics và cơ chế giả lập lỗi (Error Injection).
*   🐳 **[app_Dockerfile.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/app_Dockerfile.md)**: Giải thích quy trình đóng gói ứng dụng Python vào container Docker gọn nhẹ.

### 3. Cấu hình ArgoCD GitOps (App-of-Apps Pattern)
*   🌳 **[argocd_root_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/argocd_root_yaml.md)**: Giải thích Root Application quản lý toàn bộ hệ thống.
*   🔌 **[argocd_apps_argo_rollouts_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/argocd_apps_argo_rollouts_yaml.md)**: Giải thích cách ArgoCD tự động cài đặt Argo Rollouts Controller từ Helm Chart ngoài.
*   📊 **[argocd_apps_kube_prometheus_stack_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/argocd_apps_kube_prometheus_stack_yaml.md)**: Giải thích cách ArgoCD cài đặt Prometheus stack và cách cấu hình quét metrics toàn cụm.
*   💻 **[argocd_apps_web_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/argocd_apps_web_yaml.md)**: Giải thích ứng dụng con quản lý Frontend Web.
*   ⚙️ **[argocd_apps_api_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/argocd_apps_api_yaml.md)**: Giải thích ứng dụng con quản lý Backend API.

### 4. Triển khai API, Giám sát và Rollout (API, Prometheus & Canary)
*   📈 **[k8s_api_api_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/k8s_api_api_yaml.md)**: Giải thích cách khai báo Rollout K8s, các bước chia traffic Canary (Canary Steps) và Service định tuyến backend.
*   🔍 **[k8s_api_analysis_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/k8s_api_analysis_yaml.md)**: Giải thích AnalysisTemplate kết nối Prometheus để đo Success Rate và tự động Abort/Rollback.
*   📡 **[k8s_api_servicemonitor_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/k8s_api_servicemonitor_yaml.md)**: Giải thích ServiceMonitor giúp Prometheus Operator tự phát hiện điểm thu thập metric.
*   🚨 **[k8s_api_prom_rules_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/k8s_api_prom_rules_yaml.md)**: Giải thích PrometheusRule định nghĩa điều kiện cảnh báo vi phạm SLO (Tỷ lệ thành công < 95% trong 5 phút).

### 5. Cấu hình bảo mật SMTP & Script tiện ích (Security & Utilities)
*   🔑 **[alertmanager_env.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/alertmanager_env.md)**: Giải thích file môi trường lưu thông số đăng nhập Gmail SMTP.
*   🛠️ **[apply_env_py.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/apply_env_py.md)**: Giải thích script Python tự động điền các thông số bảo mật vào Helm Values của Kube-Prometheus-Stack.
*   ✉️ **[alertmanager_local_yaml.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/docs/code_explain/alertmanager_local_yaml.md)**: Giải thích luật định tuyến cảnh báo của Alertmanager về email cá nhân.
