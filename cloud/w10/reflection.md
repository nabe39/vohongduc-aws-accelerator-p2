# [W10] Secure & Operate: RBAC + Secrets + Platform Integration

> **Tài liệu gốc:** [W10_phase2_announcement_cloud.md](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/docs/W10_phase2_announcement_cloud.md)
>
> **Mục tiêu chính của W10:** Hardening và bảo mật cluster ở cấp độ Cluster Level (không phụ thuộc vào cam kết của developer). Kết thúc tuần, học viên sẽ có một **mini platform end-to-end** sẵn sàng cho capstone (W11-W12) gồm GitOps + Observability + Canary + Security, deploy lên một fresh cluster trong dưới 2 giờ.

---

## 📅 Thứ 2 (D1) — RBAC & Admission Policy

### 💡 Kiến thức cơ bản
- **Kubernetes RBAC (Role-Based Access Control):**
  - Hiểu cách phân quyền trong Kubernetes bằng cách sử dụng:
    - `Role` và `RoleBinding` (giới hạn phạm vi trong một namespace).
    - `ClusterRole` và `ClusterRoleBinding` (phạm vi toàn bộ cluster).
  - Quản lý `ServiceAccount` cho các ứng dụng chạy trong pod để giao tiếp với API Server.
- **Kiểm tra quyền hạn:**
  - Sử dụng lệnh `kubectl auth can-i` để debug nhanh và xác thực quyền hạn của một user/service account cụ thể.
- **Admission Controllers & Policy Enforcement:**
  - **OPA (Open Policy Agent) & Gatekeeper:**
    - Sử dụng ngôn ngữ **Rego** để định nghĩa các policy (luật).
    - Phân biệt giữa `ConstraintTemplate` (định nghĩa schema và logic kiểm tra bằng Rego) và `Constraint` (áp dụng template đó vào các tài nguyên cụ thể).
    - Phân biệt chế độ chạy: `audit` (chỉ ghi log cảnh báo vi phạm) và `enforce` (chặn trực tiếp yêu cầu tạo/cập nhật tài nguyên vi phạm).
  - **ValidatingAdmissionPolicy (K8s 1.30+):**
    - Giải pháp native mới của Kubernetes thay thế cho webhook bên ngoài, giúp cấu hình trực tiếp validation policies bằng CEL (Common Expression Language) mà không cần deploy thêm OPA/Gatekeeper.
  - **Kyverno:** Giải pháp thế thế cho Gatekeeper, định nghĩa policy bằng YAML thuần túy, không cần học ngôn ngữ Rego.

### 🧪 Lab / Cấu trúc thư mục thực hành
- Thư mục làm việc: [cloud/w10/day-a/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-a)
  - Phân quyền RBAC: `rbac/` (Thiết lập 3 roles chính: `developer`, `sre`, `viewer`).
  - Định nghĩa Policy: `policies/` (Cấu hình OPA/Gatekeeper và ValidatingAdmissionPolicy).

### 🔗 Link tài liệu chính thống
- [Kubernetes RBAC Docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac)
- [OPA (Open Policy Agent) Docs & Rego Intro](https://www.openpolicyagent.org/docs)
- [Gatekeeper Docs (Template & Constraint)](https://open-policy-agent.github.io/gatekeeper)
- [ValidatingAdmissionPolicy (Native K8s 1.30+)](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy)
- [Kyverno Docs](https://kyverno.io/docs)

---

## 📅 Thứ 3 (D2) — Secrets Rotation & Supply Chain Security

### 💡 Kiến thức cơ bản
- **Secrets Management & Auto Rotation:**
  - **AWS Secrets Manager:** Dịch vụ quản lý thông tin nhạy cảm của AWS hỗ trợ tự động xoay vòng (rotation) mật khẩu, API key.
  - **External Secrets Operator (ESO):** Đồng bộ hóa các secrets từ AWS Secrets Manager vào Kubernetes Secrets thông qua Custom Resource Definitions (CRDs). Cấu hình `refreshInterval` để tự động cập nhật secret định kỳ mà không cần khởi động lại Pod (rotate secret < 60s no-restart).
  - **Sealed Secrets:** Giải pháp mã hóa secrets thành file an toàn để commit lên Git công khai (GitOps), giải mã trực tiếp trên cluster bởi controller chuyên biệt.
- **Supply Chain Security:**
  - **Trivy Image Scan:** Quét lỗ hổng (CVE) của container image trong pipeline CI/CD, cấu hình fail-on khi phát hiện lỗ hổng mức độ `HIGH`/`CRITICAL`.
  - **Cosign / Sigstore:** Ký số cho container image (key-based hoặc keyless OIDC).
  - **Admission Webhook Verify Signature:** Chặn hoặc từ chối các image không được ký số (unsigned image) tại admission level khi deploy vào cluster.
  - **Exception Policy CVE / Exception ADR:** Quy trình xử lý và bỏ qua có thời hạn đối với một số CVE cụ thể bằng tài liệu Architecture Decision Record (ADR).
- **Secrets Scanning:** Quét mã nguồn trong CI để tránh rò rỉ secret lên Git (Git Guardian, Trufflehog).
- **SLSA Framework:** Bộ tiêu chuẩn đánh giá độ an toàn và tin cậy của chuỗi cung ứng phần mềm (Supply Chain Levels).

### 🧪 Lab / Cấu trúc thư mục thực hành
- Thư mục làm việc: [cloud/w10/day-b/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b)
  - Tích hợp ESO: `eso/`
  - Ký số và xác thực: `signing/`
  - Quét lỗ hổng CI: `ci-trivy/`

### 🔗 Link tài liệu chính thống
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager)
- [External Secrets Operator (ESO)](https://external-secrets.io/latest)
- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Trivy Docs](https://aquasecurity.github.io/trivy)
- [Cosign / Sigstore Overview](https://docs.sigstore.dev/cosign/overview)
- [Kyverno Verify Images Policy](https://kyverno.io/policies/?policytypes=verifyImages)
- [SLSA Framework (v1.0 levels)](https://slsa.dev)

---

## 📅 Thứ 4 (D3) — Platform Integration & Cost Guard

### 💡 Kiến thức cơ bản
- **Platform Integration:** Tích hợp toàn bộ các phần hạ tầng và công cụ đã xây dựng từ W8 đến W10 (GitOps, Observability, Canary, Security) thành một bộ bootstrap thống nhất.
- **Resource Management & Policy:**
  - **ResourceQuota:** Giới hạn tổng dung lượng tài nguyên (CPU, Memory, Pods,...) được phép sử dụng trong một namespace.
  - **LimitRange:** Thiết lập giá trị mặc định và giới hạn min/max cho `requests` và `limits` của từng container trong pod.
- **AWS Cost Anomaly Detection:** Sử dụng Machine Learning để giám sát chi phí AWS hàng ngày, phát hiện và gửi cảnh báo tự động khi phát sinh chi phí bất thường.
- **Chaos Engineering:** Thử nghiệm độ bền của hệ thống bằng cách cố ý gây lỗi (kill pod, nghẽn mạng) sử dụng các công cụ như LitmusChaos hoặc Chaos Mesh.
- **Post-mortem & Runbook:**
  - Viết tài liệu khắc phục sự cố (Runbook/Playbook) theo mẫu chuẩn SRE của Google để xử lý sự cố nhanh chóng.

### 🧪 Lab / Cấu trúc thư mục thực hành
- Thư mục làm việc: [cloud/w10/day-c/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-c)
  - Khởi tạo nền tảng: `platform-bootstrap/`
  - Tài liệu vận hành: `runbooks/`

### 🔗 Link tài liệu chính thống
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas)
- [Kubernetes Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range)
- [AWS Cost Anomaly Detection](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html)
- [Litmus Chaos](https://litmuschaos.io) & [Chaos Mesh](https://chaos-mesh.org)
- [Runbook template (Google SRE Workbook)](https://sre.google/workbook/example-postmortem)

---

## 🛡️ Thứ 5 & Thứ 6 (Review / Live / Lab Day) — AWS Security & Incident Response

> [!NOTE]
> Phần kiến thức nâng cao, kết nối các mảnh ghép bảo mật từ AWS Layer xuống K8s Layer phục vụ cho buổi Live Mentor Minh và bài Lab thực tế dọn dẹp cụm Kubernetes bị tấn công.

### 💡 Kiến thức bổ sung & Ôn tập (Review)

#### 1. AWS Security Foundation Recap (Phase 1 Refresher)
*Trước khi đi sâu vào hệ thống K8s, cần vững lại các khái niệm bảo mật AWS:*
- **Shared Responsibility Model:** Trách nhiệm của AWS (bảo mật phần cứng, hạ tầng vật lý) vs Khách hàng (bảo mật dữ liệu, OS, mạng, IAM cấu hình).
- **AWS Well-Architected - Security Pillar:** Các nguyên lý cốt lõi về bảo mật đám mây.
- **AWS Organizations & SCPs (Service Control Policies):** Chặn các quyền nguy hiểm hoặc trái phép ở cấp root của toàn bộ tổ chức (AWS Accounts).
- **IAM Best Practices:** Áp dụng nguyên tắc đặc quyền tối thiểu (least privilege), luân phiên credentials, sử dụng IAM Roles thay cho IAM Users tĩnh.
- **VPC Security & Detection:**
  - Cấu hình phân mảnh mạng: Security Group (stateful) và Network ACL (stateless).
  - Tích hợp WAF/Shield chống DDoS và Web Attacks.
  - Sử dụng AWS GuardDuty, Security Hub, Macie, Inspector để phát hiện hành vi bất thường, rò rỉ dữ liệu nhạy cảm và quét lỗ hổng EC2/ECR.
  - Theo dõi log với CloudTrail (API calls) và CloudWatch Logs.

#### 2. Container & K8s Security (Mới - Tương ứng Lab F-02/F-04)
- **ECR Image Scanning:** Tự động quét lỗ hổng ảnh khi được push lên AWS ECR.
- **IRSA (IAM Roles for Service Accounts):**
  - Cơ chế map trực tiếp AWS IAM Role với K8s Service Account bằng OIDC provider.
  - Tránh việc nhúng trực tiếp AWS Access Key/Secret Key tĩnh vào trong Pod.
- **K8s Pod Security Standards (PSS):**
  - Cấu hình 3 mức độ bảo mật cho Pod: `Privileged`, `Baseline`, và `Restricted`.
  - Cấu hình Container Hardening:
    - Bắt buộc chạy non-root: `runAsNonRoot: true`
    - Đặt hệ thống file chỉ đọc: `readOnlyRootFilesystem: true`
- **NetworkPolicy:** Khóa chặt traffic nội bộ giữa các Pod trong cluster (chỉ cho phép những kết nối cần thiết).
- **EKS Audit Logs:** Đẩy logs hoạt động của Kubernetes API Server về CloudWatch Logs để phục vụ điều tra bảo mật.

#### 3. DevSecOps & Supply Chain Security (Mới - Tương ứng Lab F-03/F-05/F-06)
- **OWASP CI/CD Top 10:** Nhận diện 10 rủi ro bảo mật hàng đầu trong quy trình tích hợp và triển khai liên tục.
- **SLSA Supply Chain Levels:** Từng bước tăng cường độ tin cậy của mã nguồn từ lúc code đến khi chạy production.
- *Thực hiện quét Trivy, ký ảnh Cosign và áp dụng admission webhook để từ chối các image chưa được ký.*

#### 4. Incident Response on AWS (Mới & Quan trọng cho Runbook)
*Quy trình ứng phó sự cố bảo mật theo tiêu chuẩn AWS:*
- **Quy trình 6 bước ứng phó sự cố (AWS IR Playbook 6-step):**
  1. **Detect (Phát hiện):** Nhận diện hành vi xâm nhập thông qua CloudTrail, GuardDuty, hoặc cảnh báo Prometheus/Grafana.
  2. **Triage (Đánh giá):** Xác định mức độ nghiêm trọng và khoanh vùng tài nguyên bị ảnh hưởng.
  3. **Contain (Cô lập):**
     - Cách ly nhanh chóng. Ví dụ đối với EC2: Thay đổi Security Group sang SG cô lập (SG swap), tắt các kết nối mạng ngoài, và chụp nhanh EBS snapshot để lưu trữ phân tích sau (EBS snapshot).
     - Đối với K8s Pod bị hack: Cô lập pod bằng NetworkPolicy, xóa nhãn (remove labels) để đưa pod ra khỏi Service (ngăn tiếp tục nhận traffic), hoặc cô lập node/namespace tùy theo phạm vi ảnh hưởng.
  4. **Eradicate (Loại bỏ):** Tiêu diệt mã độc, gỡ bỏ container/pod bị tấn công.
  5. **Recover (Phục hồi):** Khôi phục hệ thống từ các bản sao sạch hoặc chạy lại GitOps pipeline để deploy lại tài nguyên.
  6. **Post-mortem (Rút kinh nghiệm):** Phân tích nguyên nhân gốc rễ (Root Cause), cập nhật quy trình và hoàn thiện Runbook tránh lặp lại sự cố.
- **Automation Remediation:** Cấu hình EventBridge bắt các sự cố từ GuardDuty/Security Hub kích hoạt AWS Lambda tự động cô lập tài nguyên bị xâm hại (auto-isolate).
- **Amazon Detective:** Hỗ trợ điều tra, liên kết các sự kiện bảo mật để tìm ra nguyên nhân gốc rễ một cách nhanh chóng.

### 🧪 Lab Thực Chiến (Thứ 5 & Thứ 6)
- Thư mục làm việc: [cloud/w10/lab/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/lab)
- Nội dung Lab: **"6-risk cluster cleanup + cluster-level enforcement"** (Dọn dẹp cụm cluster có 6 rủi ro bảo mật chính và triển khai chặn vi phạm tự động ở mức cluster).

### 🔗 Link tài liệu chính thống & Ôn tập (Review)
- **AWS Security Foundation:**
  - [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model)
  - [AWS Well-Architected — Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar)
  - [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
  - [AWS Organizations + SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- **Container & K8s Security:**
  - [EKS Best Practices Guide — Security](https://aws.github.io/aws-eks-best-practices/security/docs)
  - [AWS ECR Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
  - [AWS IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
  - [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards)
  - [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies)
- **DevSecOps:**
  - [OWASP CI/CD Top 10 Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks)
  - [SLSA Supply Chain Levels Spec](https://slsa.dev/spec/v1.0/levels)
- **Incident Response on AWS:**
  - [AWS Security Incident Response Guide](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/welcome.html)
  - [AWS Incident Response Playbooks (GitHub samples)](https://github.com/aws-samples/aws-incident-response-playbooks)
  - [Amazon Detective User Guide](https://docs.aws.amazon.com/detective/latest/userguide/what-is-detective.html)
  - [Automating Security Response Pattern (EventBridge + Lambda)](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/automate-security-responses-using-aws-lambda-and-eventbridge.html)
