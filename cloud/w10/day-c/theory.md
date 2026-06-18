# 📖 Lý thuyết & Khái niệm nâng cao — Thứ 4 (D3) & Live Session
*(Platform Integration, SRE Operations, AWS Security & EKS Hardening)*

Tài liệu này hệ thống hóa toàn bộ các kiến thức, thuật ngữ kỹ thuật của **Thứ 4 (D3)** (bao gồm phần tự học Platform Integration & Cost Guard buổi sáng và buổi chiều học Live với Mentor Minh về AWS Security & EKS Hardening). Mỗi phần đều có link tài liệu chính thống và các bài Lab thực hành nhỏ (mini-labs) đi kèm để dễ dàng nắm bắt.

---

# 📑 Phần I: Thứ 4 (D3) — Platform Integration & SRE Operations

## 1. Platform Integration (Tích hợp Nền tảng)
### 💡 Khái niệm & Thuật ngữ
*   **Platform Integration:** Quá trình liên kết toàn bộ các mảnh ghép hạ tầng riêng lẻ đã xây dựng từ các tuần trước (GitOps, Observability, Canary Deployments, Cluster Security, Secrets Management) thành một hệ thống nền tảng đồng nhất (Mini-Platform).
*   **Platform Bootstrap:** Tập hợp các script, Helm charts hoặc cấu hình GitOps (ArgoCD Application of Applications pattern) giúp khởi tạo và tự động triển khai toàn bộ các dịch vụ nền tảng lên một Kubernetes cluster mới (fresh cluster) một cách tự động và nhanh chóng.

### 🔗 Nguồn tham khảo
*   [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping)
*   [Kubernetes Cluster Bootstrapping](https://kubernetes.io/docs/setup)

### 🧪 Mini Lab: Mô phỏng App-of-Apps Bootstrap bằng ArgoCD
Giả sử bạn cần triển khai nhanh nền tảng gồm GitOps, Monitoring và Security thông qua một file khai báo duy nhất.
1. Tạo file `bootstrap-platform.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-username/platform-bootstrap-repo.git'
    targetRevision: HEAD
    path: apps
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
2. Lệnh áp dụng để bootstrap hệ thống:
```bash
kubectl apply -f bootstrap-platform.yaml
```

---

## 2. Resource Management (Quản lý Tài nguyên Cluster)
Để ngăn chặn các cuộc tấn công từ chối dịch vụ (DoS) do cạn kiệt tài nguyên (Resource Exhaustion) hoặc ứng dụng chạy ngốn RAM/CPU làm ảnh hưởng đến các ứng dụng khác trên cùng một Node, Kubernetes cung cấp hai công cụ chính:

### 💡 Khái niệm & Thuật ngữ
*   **ResourceQuota (Giới hạn tài nguyên Namespace):** 
    *   Giới hạn **tổng lượng** tài nguyên (CPU, Memory, Storage) hoặc số lượng đối tượng (Pods, Services, Secrets, ConfigMaps) tối đa được phép tạo ra trong một Namespace cụ thể.
    *   Nếu một yêu cầu tạo tài nguyên vượt quá giới hạn Quota, API Server sẽ từ chối trực tiếp.
*   **LimitRange (Ràng buộc tài nguyên Container):**
    *   Đặt ra các giới hạn tối thiểu (min), tối đa (max) và giá trị mặc định (default requests & limits) cho RAM và CPU của **từng container** riêng lẻ chạy trong một Namespace.
    *   Nếu Developer tạo một Pod mà không khai báo `resources.requests` hoặc `resources.limits`, LimitRange sẽ tự động chèn các thông số mặc định này vào Pod (thông qua cơ chế Mutating Admission Webhook).

### 🔗 Nguồn tham khảo
*   [Kubernetes Resource Quotas Docs](https://kubernetes.io/docs/concepts/policy/resource-quotas)
*   [Kubernetes Limit Ranges Docs](https://kubernetes.io/docs/concepts/policy/limit-range)

### 🧪 Mini Lab: Enforce LimitRange và ResourceQuota
1. Tạo namespace thử nghiệm:
```bash
kubectl create namespace staging-env
```
2. Tạo file `quota-limits.yaml` cấu hình cả ResourceQuota và LimitRange:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: staging-env
spec:
  hard:
    pods: "3"              # Chỉ cho phép tối đa 3 pods hoạt động đồng thời
    requests.cpu: "1"      # Tổng CPU request tối đa là 1 Core
    requests.memory: 1Gi   # Tổng RAM request tối đa là 1 GiB
    limits.cpu: "2"        # Tổng CPU limit tối đa là 2 Cores
    limits.memory: 2Gi     # Tổng RAM limit tối đa là 2 GiB
---
apiVersion: v1
kind: LimitRange
metadata:
  name: staging-container-limits
  namespace: staging-env
spec:
  limits:
  - default:               # Mặc định tự động gán limit nếu pod không khai báo
      cpu: 500m
      memory: 512Mi
    defaultRequest:        # Mặc định tự động gán request nếu pod không khai báo
      cpu: 200m
      memory: 256Mi
    max:                   # Giới hạn tối đa một pod có thể cấu hình
      cpu: "1"
      memory: 1Gi
    min:                   # Giới hạn tối thiểu một pod bắt buộc phải cấu hình
      cpu: 100m
      memory: 128Mi
    type: Container
```
3. Áp dụng lên namespace:
```bash
kubectl apply -f quota-limits.yaml
```
4. Kiểm tra việc thực thi:
    * Tạo một pod không khai báo tài nguyên và xem cấu hình tự động chèn:
    ```bash
    kubectl run test-limitrange --image=nginx -n staging-env
    kubectl get pod test-limitrange -n staging-env -o yaml | grep -A 5 resources
    ```
    * Thử tạo liên tiếp 4 pods để trigger chặn từ ResourceQuota:
    ```bash
    kubectl run pod1 --image=nginx -n staging-env
    kubectl run pod2 --image=nginx -n staging-env
    kubectl run pod3 --image=nginx -n staging-env
    ```
    (Pod thứ 4 sẽ bị API Server từ chối vì vượt quá quota số lượng pod tối đa là 3).

---

## 3. AWS Cost Anomaly Detection (Giám sát chi phí bất thường)
### 💡 Khái niệm & Thuật ngữ
*   **AWS Cost Anomaly Detection:** Một dịch vụ dựa trên Machine Learning (ML) của AWS để theo dõi liên tục các chi phí phát sinh hàng ngày. Nó tự động phát hiện các chi phí bất thường (anomalies) và gửi thông báo qua Amazon SNS (Simple Notification Service) hoặc Slack/Email.
*   **Cost Monitor:** Bộ lọc định nghĩa phạm vi giám sát (ví dụ: giám sát theo từng dịch vụ AWS, theo AWS Account thành viên, theo resource Tag, hoặc theo Cost Category).
*   **Alert Subscription:** Cấu hình tần suất gửi cảnh báo (gửi ngay lập tức, báo cáo tóm tắt hàng ngày/hàng tuần) và ngưỡng chi phí vượt hạn để kích hoạt cảnh báo (ví dụ: chi phí tăng đột biến trên $10).

### 🔗 Nguồn tham khảo
*   [AWS Cost Anomaly Detection User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html)

### 🧪 Mini Lab: Tạo AWS Cost Monitor bằng AWS CLI
1. Tạo một Cost Monitor để theo dõi tất cả các dịch vụ AWS trong tài khoản:
```bash
aws ce create-anomaly-monitor \
  --anomaly-monitor '{"MonitorName": "All-Services-Cost-Monitor", "MonitorType": "DIMENSIONAL", "MonitorDimension": "SERVICE"}' \
  --region us-east-1
```
*(Lưu ý lấy giá trị `MonitorArn` từ output để cấu hình bước tiếp theo).*

2. Tạo một Alert Subscription để gửi cảnh báo qua Email/SNS khi phát hiện chi phí bất thường vượt quá $50:
```bash
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "Daily-Anomaly-Alerts",
    "Threshold": 50.0,
    "Frequency": "IMMEDIATE",
    "MonitorArnList": ["arn:aws:ce::123456789012:anomalymonitor/your-monitor-uuid"],
    "Subscribers": [
      {
        "Address": "your-email@example.com",
        "Type": "EMAIL",
        "Status": "CONFIRMED"
      }
    ]
  }' \
  --region us-east-1
```

---

## 4. Chaos Engineering (Kỹ nghệ Hỗn loạn)
### 💡 Khái niệm & Thuật ngữ
*   **Chaos Engineering:** Phương pháp thử nghiệm hệ thống bằng cách chủ động tạo ra các sự cố hỗn loạn (như tắt pod đột ngột, nghẽn mạng, quá tải CPU/RAM, hỏng ổ đĩa) nhằm kiểm tra khả năng chịu lỗi (fault tolerance), khả năng tự phục hồi (self-healing) của hệ thống và đánh giá hệ thống cảnh báo (alerting) hoạt động đúng không.
*   **Pod Kill Chaos:** Mô phỏng sự cố một container/pod đột ngột bị crash hoặc tắt nguồn.
*   **Network Latency/Loss Chaos:** Gây trễ hoặc mất gói tin mạng giữa các service để kiểm tra cơ chế Retry, Timeout và Circuit Breaker của ứng dụng.
*   **LitmusChaos / Chaos Mesh:** Các công cụ mã nguồn mở (Cloud Native Chaos Orchestrators) phổ biến dùng để định nghĩa các kịch bản thử nghiệm hỗn loạn trực tiếp trên Kubernetes dưới dạng YAML.

### 🔗 Nguồn tham khảo
*   [LitmusChaos Docs](https://docs.litmuschaos.io)
*   [Chaos Mesh Docs](https://chaos-mesh.org)

### 🧪 Mini Lab: Thử nghiệm khả năng tự phục hồi (Pod Kill)
Để kiểm tra xem cơ chế ReplicaSet của Kubernetes có tự động hồi sinh pod khi có lỗi xảy ra hay không:
1. Tạo một deployment có 3 bản sao:
```bash
kubectl create deployment web-app --image=nginx --replicas=3
```
2. Monitor danh sách pod liên tục ở một cửa sổ terminal khác:
```bash
kubectl get pods -l app=web-app -w
```
3. Mô phỏng "Pod Kill" bằng cách xóa ngẫu nhiên một Pod:
```bash
POD_NAME=$(kubectl get pods -l app=web-app -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $POD_NAME --force --grace-period=0
```
4. Quan sát: Bạn sẽ thấy Pod bị xóa ngay lập tức và ReplicaSet Controller sẽ tự động phát hiện trạng thái thiếu pod, sau đó lập tức tạo mới một Pod để duy trì đủ số lượng bản sao là 3.

---

## 5. Post-mortem & Runbook
### 💡 Khái niệm & Thuật ngữ
*   **Runbook (hoặc Playbook):** Tài liệu hướng dẫn chi tiết từng bước (step-by-step) dành cho SRE/DevOps để khắc phục một sự cố cụ thể đã được xác định từ trước (ví dụ: Runbook mở rộng dung lượng ổ đĩa khi cảnh báo disk-full 90%, Runbook khởi động lại kết nối DB).
*   **Post-mortem (Báo cáo sau sự cố):** Tài liệu phân tích chi tiết sau khi sự cố xảy ra nhằm tìm kiếm nguyên nhân gốc rễ (Root Cause Analysis - RCA), ghi nhận tác động, các bước đã xử lý và đề xuất hành động ngăn chặn sự cố tái diễn. Quy tắc cốt lõi của Post-mortem là **Blameless** (Không đổ lỗi cá nhân, tập trung vào cải tiến hệ thống).

### 🔗 Nguồn tham khảo
*   [Google SRE Postmortem Template](https://sre.google/workbook/example-postmortem)
*   [AWS Incident Response Guide](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/welcome.html)

### 🧪 Mini Lab: Tạo một Runbook khắc phục nhanh lỗi CrashLoopBackOff do cấu hình sai
Tạo một file mẫu `runbook-crashloopbackoff.md`:
```markdown
# 📕 Runbook: Xử lý Pod lỗi CrashLoopBackOff

## 📌 1. Triệu chứng & Phát hiện
*   **Cảnh báo:** Prometheus cảnh báo `KubePodCrashLooping`.
*   **Kiểm tra nhanh:** `kubectl get pods -n production` thấy trạng thái `CrashLoopBackOff`.

## 🛠️ 2. Các bước xử lý sự cố (Troubleshooting Step-by-Step)
1. **Kiểm tra Log của Pod:**
   ```bash
   kubectl logs <pod-name> -n production --tail=100
   ```
   *Nếu log hiển thị lỗi kết nối DB, chuyển sang kiểm tra mạng hoặc credential.*
2. **Kiểm tra sự kiện chi tiết của Pod (Events):**
   ```bash
   kubectl describe pod <pod-name> -n production
   ```
   *Nhìn vào mục `Events` cuối cùng xem có bị lỗi Mount Secret hoặc thiếu ConfigMap hay không.*
3. **Kiểm tra tài nguyên của Node:**
   ```bash
   kubectl top pod <pod-name> -n production
   ```
   *Nếu Pod bị kill liên tục do Out Of Memory (OOMKilled), hãy tăng cấu hình memory limits trong Deployment.*

## 📞 3. Quy trình Escalate (Leo thang)
*   Nếu lỗi không thuộc về cấu hình hạ tầng, liên hệ Lead Developer của Pod ứng dụng để debug code nguồn.
```

---

# 🛡️ Phần II: Live Session — AWS Security & EKS Hardening

## 1. AWS Security Foundation Recap (Kết nối AWS & Kubernetes)
### 💡 Khái niệm & Thuật ngữ
*   **Shared Responsibility Model (Mô hình trách nhiệm chung):** 
    *   **AWS:** Bảo mật hạ tầng vật lý, hypervisor và control plane (Security **of** the Cloud). Đối với EKS, AWS quản lý Kubernetes Master Nodes/API Server.
    *   **Khách hàng:** Bảo mật cấu hình hệ thống, dữ liệu, phân quyền mạng, IAM, container image và code chạy bên trong (Security **in** the Cloud).
*   **AWS Organizations & SCPs (Service Control Policies):** Các chính sách quản trị cấp cao nhất của AWS dùng để thiết lập quyền hạn tối đa cho các tài khoản thành viên trong tổ chức. Ví dụ: SCP có thể cấm hoàn toàn hành động xóa EKS Cluster hoặc tắt CloudTrail trên toàn bộ các AWS Accounts con.
*   **VPC Security & Network Isolation:**
    *   **Security Groups (Stateful):** Tương đương tường lửa cấp Instance/Node (kiểm soát traffic đi vào/đi ra của EKS Worker Nodes).
    *   **Network ACLs (Stateless):** Kiểm soát traffic cấp Subnet.
*   **Detection Tools (Công cụ phát hiện xâm nhập):**
    *   **AWS GuardDuty:** Sử dụng trí tuệ nhân tạo (AI) để quét liên tục CloudTrail logs, VPC Flow logs, DNS logs và phát hiện các hoạt động tấn công, đào tiền ảo hoặc rò rỉ keys.
    *   **AWS Security Hub:** Tập trung hiển thị các cảnh báo bảo mật từ các dịch vụ AWS khác nhau và kiểm tra độ tuân thủ tiêu chuẩn bảo mật (CIS, PCI-DSS).

### 🔗 Nguồn tham khảo
*   [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model)
*   [AWS Organizations SCPs Guide](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)

---

## 2. Container & EKS Security
### 💡 Khái niệm & Thuật ngữ
*   **ECR Image Scanning:** 
    *   Tính năng quét lỗ hổng ảnh tự động khi push lên AWS Elastic Container Registry (ECR).
    *   Sử dụng cơ sở dữ liệu lỗi từ Clair hoặc tích hợp sâu với Amazon Inspector để quét liên tục (Continuous Scanning) khi có CVE mới xuất hiện.
*   **IRSA (IAM Roles for Service Accounts):**
    *   Cơ chế map trực tiếp một AWS IAM Role với một Kubernetes ServiceAccount cụ thể dựa trên liên kết OIDC (OpenID Connect) Provider của EKS.
    *   Giúp loại bỏ hoàn toàn việc sử dụng Access Key/Secret Key tĩnh của IAM nhúng trong code hoặc lưu trữ trong K8s Secret. Pod ứng dụng sẽ tự động lấy token tạm thời thông qua AWS STS.
*   **Pod Security Standards (PSS) & Container Hardening:**
    *   Tiêu chuẩn bảo mật Pod của Kubernetes gồm 3 mức: `Privileged` (Không hạn chế), `Baseline` (Bảo mật cơ bản, ngăn các đặc quyền nguy hiểm), và `Restricted` (Rất nghiêm ngặt).
    *   **Container Hardening:** Cấu hình bảo mật trực tiếp trong `securityContext` của Pod:
        *   `runAsNonRoot: true`: Cấm container chạy dưới quyền root (UID 0).
        *   `readOnlyRootFilesystem: true`: Khóa hệ thống file của container thành chỉ đọc. Nếu ứng dụng bị hack, tin tặc không thể tải mã độc hoặc script tấn công vào ổ đĩa.
*   **NetworkPolicy:** 
    *   Tường lửa cấp Pod trong Kubernetes. Mặc định các Pod trong cụm có thể giao tiếp tự do với nhau. NetworkPolicy được cấu hình để chỉ cho phép traffic từ các Pod và Namespace được chỉ định đi vào (Ingress) hoặc đi ra (Egress).

### 🔗 Nguồn tham khảo
*   [AWS IRSA EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
*   [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards)
*   [Kubernetes Network Policies Docs](https://kubernetes.io/docs/concepts/services-networking/network-policies)

### 🧪 Mini Lab: Hardening Pod với Restricted Context & NetworkPolicy
1. Tạo file cấu hình Pod bảo mật `secure-pod.yaml` không chạy root, có ổ đĩa chỉ đọc và kèm NetworkPolicy khóa chặt:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-nginx
  namespace: staging-env
  labels:
    app: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 2000
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:alpine # Sử dụng ảnh không chạy root mặc định
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true            # Hệ thống file chỉ đọc
      capabilities:
        drop:
        - ALL                                 # Loại bỏ mọi đặc quyền OS mặc định
    volumeMounts:
    - name: cache-vol
      mountPath: /tmp                         # Chỉ cho ghi vào thư mục tạm được mount
  volumes:
  - name: cache-vol
    emptyDir: {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-except-specific
  namespace: staging-env
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: trusted-frontend               # Chỉ cho phép frontend gọi tới Pod này
    ports:
    - protocol: TCP
      port: 8080
```
2. Thực thi triển khai:
```bash
kubectl apply -f secure-pod.yaml
```

---

## 3. DevSecOps & Supply Chain Security
### 💡 Khái niệm & Thuật ngữ
*   **OWASP CI/CD Top 10:** Danh sách 10 rủi ro bảo mật nguy hiểm nhất trong chuỗi cung ứng CI/CD (như cấu hình pipeline sai, lộ credentials trong log, thiếu kiểm soát quyền merge code, sử dụng thư viện bên ngoài không an toàn).
*   **SLSA (Supply Chain Levels for Software Artifacts):** Khung tiêu chuẩn bảo mật giúp bảo vệ quá trình tạo phần mềm (build pipeline). Đạt SLSA Level 3 đảm bảo mã nguồn và artifact không bị thay đổi (tamper-proof) trong quá trình build.
*   **Secrets Scanning:** Quét mã nguồn trong Git để tìm kiếm các API keys, database passwords bị hardcode (sử dụng Trufflehog, GitGuardian).
*   **Exception ADR (Architecture Decision Record):** Quy trình phê duyệt bằng văn bản của đội ngũ bảo mật và kiến trúc sư hệ thống để tạm thời bỏ qua (bypass) một lỗ hổng CVE trong lúc chờ bản vá, tránh làm nghẽn pipeline CI/CD.

### 🔗 Nguồn tham khảo
*   [OWASP CI/CD Security Project](https://owasp.org/www-project-top-10-ci-cd-security-risks)
*   [SLSA Framework Specification](https://slsa.dev)

---

## 4. Incident Response (Ứng phó Sự cố Bảo mật)
### 💡 Khái niệm & Thuật ngữ
*   **Quy trình 6 bước AWS Incident Response (IR):**
    1.  **Detect (Phát hiện):** Nhận diện hành vi xâm nhập thông qua CloudTrail logs, GuardDuty alerts hoặc Prometheus metrics.
    2.  **Triage (Đánh giá):** Xác định phạm vi ảnh hưởng, mức độ nghiêm trọng và khoanh vùng tài nguyên bị xâm hại.
    3.  **Contain (Cô lập):** Cách ly nhanh tài nguyên để ngăn chặn tin tặc tiếp tục phá hoại hoặc lấy dữ liệu.
    4.  **Eradicate (Loại bỏ):** Tiêu diệt mã độc, gỡ bỏ container bị chiếm quyền, thu hồi các access keys bị lộ.
    5.  **Recover (Phục hồi):** Khôi phục hệ thống từ các bản sao lưu sạch hoặc deploy lại tài nguyên sạch bằng GitOps.
    6.  **Post-mortem (Rút kinh nghiệm):** Phân tích nguyên nhân gốc rễ và nâng cấp hệ thống phòng thủ.
*   **EC2 Isolation Pattern:** Khi EC2 bị hack, thực hiện **SG Swap** (thay thế Security Group hiện tại bằng một SG trống không cho phép inbound/outbound traffic để cô lập mạng) và thực hiện **EBS Snapshot** để lưu giữ trạng thái ổ đĩa phục vụ điều tra forensics.
*   **K8s Pod Isolation Pattern:** Khi một Pod trong Kubernetes bị tấn công:
    *   **Tháo nhãn (Label Removal):** Xóa các nhãn (labels) kết nối Pod với Kubernetes Service. Khi đó, Service/Load Balancer sẽ dừng chuyển traffic người dùng vào Pod này ngay lập tức. Pod vẫn tiếp tục chạy độc lập để SRE vào điều tra.
    *   **Cô lập mạng (Network Isolation):** Áp dụng NetworkPolicy cấm tất cả traffic vào/ra của Pod đó.

### 🔗 Nguồn tham khảo
*   [AWS Security Incident Response Guide](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/welcome.html)
*   [AWS Incident Response Playbooks samples](https://github.com/aws-samples/aws-incident-response-playbooks)

### 🧪 Mini Lab: Cô lập một Pod bị tấn công trong 5 phút đầu
Giả sử pod `web-attacker` đang chạy bị nghi ngờ phát tán traffic độc hại. Chúng ta cần cách ly Pod này khỏi traffic của người dùng mà không cần xóa Pod ngay để giữ nguyên hiện trường điều tra.

1. Giả lập Pod có nhãn đang nhận traffic từ service:
```bash
kubectl run web-attacker --image=nginx --labels="app=web-app,tier=frontend" -n staging-env
```
2. Thực hiện cô lập bằng cách thay đổi nhãn (Label Swap/Removal):
```bash
kubectl label pod web-attacker app- tier- --overwrite -n staging-env
kubectl label pod web-attacker status=quarantined --overwrite -n staging-env
```
*(Lệnh trên sẽ xóa nhãn `app` và `tier` khỏi pod, đồng thời gắn nhãn `status=quarantined`. Service hiện tại trỏ vào `app=web-app` sẽ dừng gửi traffic đến Pod này ngay lập tức).*

3. Áp dụng NetworkPolicy để khóa chặt hoàn toàn traffic mạng của Pod bị cách ly:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-quarantined-pods
  namespace: staging-env
spec:
  podSelector:
    matchLabels:
      status: quarantined
  policyTypes:
  - Ingress
  - Egress
  # Bỏ trống phần ingress và egress để cấm tuyệt đối mọi traffic inbound/outbound
```
Áp dụng policy:
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-quarantined-pods
  namespace: staging-env
spec:
  podSelector:
    matchLabels:
      status: quarantined
  policyTypes:
  - Ingress
  - Egress
EOF
```
Bây giờ Pod đã bị cô lập hoàn toàn về mặt mạng và traffic dịch vụ ứng dụng, sẵn sàng cho SRE thực hiện điều tra hoặc gỡ lỗi.
