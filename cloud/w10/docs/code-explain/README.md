# 📋 Hướng Dẫn Chi Tiết Các File Của Lab 1 & Lab 2 (Tuần W10)

Thư mục này chứa toàn bộ tài liệu giải thích chi tiết code và ý nghĩa của từng file được tạo ra hoặc chỉnh sửa để hoàn thành **Lab 1 (RBAC & Admission Policy)** và **Lab 2 (Secrets, Supply Chain & Platform Integration)** thuộc tuần W10 (Secure & Operate).

---

## 🗺️ Bản đồ Tài Liệu Giải Thích Chi Tiết
Tài liệu giải thích được phân bổ chi tiết theo từng bài lab và bài lab nhỏ (sub-labs):

### 🛡️ [Lab 1: RBAC & Admission Policy (Gatekeeper)](./lab1_rbac_admission.md)
*   **Lab 1.1 — Phân Quyền Người Dùng (RBAC):** Cấp quyền tối thiểu cho Alice (Dev), Bob (SRE), và Carol (Viewer) thông qua GitOps.
*   **Lab 1.2 — OPA Gatekeeper (4 Chốt Chặn Cơ Bản):** Chặn đứng các yaml vi phạm: sử dụng tag `:latest`, thiếu Resource Limits, chạy Pod bằng User Root, và chia sẻ cổng hostNetwork.
*   **Lab 1.3 — Custom Policy (Thử Thách):** Viết logic Rego tùy chỉnh thiết lập giới hạn Replicas tối thiểu/tối đa cho Deployments.

### 🔑 [Lab 2: Secrets & Supply Chain Security](./lab2_secrets_supply_chain.md)
*   **Lab 2.1 — Quản Lý Secrets Động (ESO & AWS Secrets Manager):** Xoay vòng mật khẩu Database tự động dưới 60 giây và cập nhật động vào Pod mà không cần restart Pod (Volume Mount).
*   **Lab 2.2 — Bảo Mật Chuỗi Cung Ứng (Trivy + Cosign + Sigstore):** Chặn lỗi bảo mật từ CI (Trivy Scan), ký số container image (Cosign), và cưỡng chế xác minh chữ ký trên cụm K8s (Sigstore Policy Controller).

### 🚀 [Ý Nghĩa Thực Chiến Trong CI/CD & DevOps](./cicd_significance.md)
*   Tổng quan triết lý thiết kế Defense-in-depth, Shift-Left Security và lợi ích thực tế của việc xây dựng Cluster-level Enforcement.

### 📚 [Tài Liệu Lý Thuyết Về Cơ Chế Hoạt Động](./theory_explanation.md)
*   Giải thích cơ chế hoạt động chi tiết của RBAC, OPA Gatekeeper webhooks, Rego validation, dynamic secrets volume updates, Trivy vulnerability check, Cosign cryptographic container signature, và Sigstore controller verification.

---

## 📊 Bảng Tổng Hợp Danh Sách Các File Phân Theo Lab

Dưới đây là danh sách phân loại chi tiết từng file theo phân mục Lab 1.1, 1.2, 1.3 và Lab 2.1, 2.2:

| STT | Đường dẫn file | Trạng thái | Thuộc Bài Lab | Mô tả tóm tắt |
| :--- | :--- | :--- | :--- | :--- |
| **1** | [rbac/roles.yaml](../../lab/rbac/roles.yaml) | **Tạo mới** | **Lab 1.1 (RBAC)** | Định nghĩa 3 Roles: `developer-role`, `sre-role`, và `viewer-role` |
| **2** | [rbac/rolebindings.yaml](../../lab/rbac/rolebindings.yaml) | **Tạo mới** | **Lab 1.1 (RBAC)** | Binds Alice (Dev), Bob (SRE) và Carol (Viewer) vào các Roles tương ứng |
| **3** | [rbac.yaml](../../lab/argocd/apps/rbac.yaml) | **Tạo mới** | **Lab 1.1 (RBAC)** | Khai báo ứng dụng ArgoCD tự động deploy và đồng bộ cấu hình RBAC |
| **4** | [gatekeeper.yaml](../../lab/argocd/apps/gatekeeper.yaml) | **Tạo mới** | **Lab 1.2 (Gatekeeper)** | ArgoCD App cài đặt OPA Gatekeeper Operator Helm Chart (Wave 0) |
| **5** | [templates.yaml](../../lab/gatekeeper/constraints/templates.yaml) | **Tạo mới** | **Lab 1.2 & 1.3** | Chứa `ConstraintTemplates` logic Rego cho 4 luật cơ bản (1.2) & replicas limit (1.3) |
| **6** | [constraints.yaml](../../lab/gatekeeper/constraints/constraints.yaml) | **Tạo mới** | **Lab 1.2 & 1.3** | Khởi tạo 4 Constraints chặn vi phạm bảo mật (1.2) & replicas limit constraint (1.3) |
| **7** | [gatekeeper-policies.yaml](../../lab/argocd/apps/gatekeeper-policies.yaml) | **Tạo mới** | **Lab 1.2 & 1.3** | ArgoCD App đồng bộ tự động thư mục templates và constraints (Wave 1) |
| **8** | [eso.yaml](../../lab/argocd/apps/eso.yaml) | **Tạo mới** | **Lab 2.1 (Secrets)** | ArgoCD App cài đặt External Secrets Operator (Wave 0) |
| **9** | [secret-store.yaml](../../lab/eso/secret-store.yaml) | **Tạo mới** | **Lab 2.1 (Secrets)** | Cấu hình SecretStore kết nối AWS Secrets Manager qua Access Keys |
| **10**| [external-secret.yaml](../../lab/eso/external-secret.yaml) | **Tạo mới** | **Lab 2.1 (Secrets)** | Đồng bộ DB credential từ AWS sang K8s Secret mỗi 10 giây (`refreshInterval`) |
| **11**| [eso-config.yaml](../../lab/argocd/apps/eso-config.yaml) | **Tạo mới** | **Lab 2.1 (Secrets)** | ArgoCD App đồng bộ SecretStore & ExternalSecret vào cụm (Wave 1) |
| **12**| [rollout.yaml](../../lab/app-api/rollout.yaml) | **Modify** | **Lab 1.2 & 2.1** | Cấu hình pod bảo mật (Limits + Non-Root) (1.2) & Mount volume secrets động (2.1) |
| **13**| [runbook-eso.md](../../lab/runbooks/runbook-eso.md) | **Tạo mới** | **Lab 2.1 (Secrets)** | Runbook xác minh xoay vòng mật khẩu dynamic không restart pod |
| **14**| [Dockerfile](../../lab/src/api/Dockerfile) | **Modify** | **Lab 2.2 (Supply Chain)** | Đổi sang base image `python:3.13-alpine` nhằm triệt tiêu các lỗi CVE |
| **15**| [build-push.yml](../../../.github/workflows/build-push.yml) | **Modify** | **Lab 2.2 (Supply Chain)** | Pipeline CI tự động: build, Trivy scan, Cosign sign và đẩy GitOps |
| **16**| [.trivyignore](../../../.trivyignore) | **Modify** | **Lab 2.2 (Supply Chain)** | File chứa ID các CVE được tạm hoãn chờ patch từ vendor |
| **17**| [adr-cve-exception.md](../../lab/runbooks/adr-cve-exception.md) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | ADR quy định quy trình duyệt ngoại lệ CVE tạm thời có thời hạn |
| **18**| [policy-controller.yaml](../../lab/argocd/apps/policy-controller.yaml) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | ArgoCD App cài đặt Sigstore Policy Controller (Wave 0) |
| **19**| [cluster-image-policy.yaml](../../lab/policies/cluster-image-policy.yaml) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | ClusterImagePolicy chứa khóa công khai kiểm tra chữ ký ảnh từ ghcr.io |
| **20**| [policies.yaml](../../lab/argocd/apps/policies.yaml) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | ArgoCD App đồng bộ ClusterImagePolicy lên cụm (Wave 1) |
| **21**| [cosign.pub](../../lab/signing/cosign.pub) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | Khóa công khai của Cosign dùng để verify chữ ký số của container image |
| **22**| [runbook-signature.md](../../lab/runbooks/runbook-signature.md) | **Tạo mới** | **Lab 2.2 (Supply Chain)** | Runbook tạo cặp khóa, ký số thủ công và xử lý lỗi Admission controller |
| **23**| [demo-namespace.yaml](../../lab/app-common/demo-namespace.yaml) | **Modify** | **Lab 2.2 (Supply Chain)** | Namespace demo gắn nhãn kích hoạt kiểm tra chữ ký số từ Sigstore |
| **24**| [root.yaml](../../lab/argocd/root.yaml) | **Modify** | **GitOps Core** | Ứng dụng gốc ArgoCD root trỏ và quản lý đồng bộ tất cả các App bảo mật trên |
