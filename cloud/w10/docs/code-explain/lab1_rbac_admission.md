# 🛡️ Lab 1: Secure & Operate: RBAC + Admission Policy

Tài liệu này giải thích chi tiết cấu trúc thư mục, ý nghĩa mã nguồn, và cơ chế hoạt động của các chính sách bảo mật trong bài Lab 1, được phân định rõ ràng thành các bài Lab 1.1, 1.2 và 1.3.

---

## 🔑 Lab 1.1: Phân Quyền Người Dùng (RBAC)

**Mục tiêu:** Thực hiện nguyên tắc đặc quyền tối thiểu (least privilege). Thay vì tất cả mọi người đều có quyền Admin, chúng ta phân chia thành 3 vai trò có phạm vi hoạt động (scope) rõ ràng.

### 📄 File 1: [rbac/roles.yaml](../../lab/rbac/roles.yaml) (Tạo mới)
Định nghĩa các vai trò quyền hạn (Role và ClusterRole) trong cụm.

```yaml
# 1. developer-role: Giới hạn trong namespace "demo"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: demo # Chỉ hoạt động trong namespace demo
rules:
- apiGroups: [""] # Core group (Pods, Services, ConfigMaps...)
  resources: ["pods", "services"]
  verbs: ["*"] # Cho phép toàn quyền thao tác trên Pods & Services
- apiGroups: ["apps"] # Group chứa Deployments
  resources: ["deployments"]
  verbs: ["*"] # Cho phép toàn quyền thao tác trên Deployments
---
# 2. sre-role: Cho phép troubleshoot trên toàn cluster
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sre-role # Không chỉ định namespace vì là ClusterRole
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"] # SRE được quyền CRUD trên mọi Pod ở tất cả namespace để khắc phục sự cố
---
# 3. viewer-role: Quyền chỉ đọc trên toàn cluster
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer-role
rules:
- apiGroups: ["*"] # Tất cả API groups
  resources: ["*"] # Tất cả resources
  verbs: ["get", "list", "watch"] # Chỉ đọc dữ liệu, cấm thay đổi trạng thái
```

---

### 📄 File 2: [rbac/rolebindings.yaml](../../lab/rbac/rolebindings.yaml) (Tạo mới)
Thực hiện gắn các vai trò trên cho các User đại diện.

```yaml
# Gắn developer-role cho Alice (giới hạn trong namespace demo)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-developer-binding
  namespace: demo
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
---
# Gắn sre-role cho Bob trên toàn cụm
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bob-sre-binding
subjects:
- kind: User
  name: bob
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: sre-role
  apiGroup: rbac.authorization.k8s.io
---
# Gắn viewer-role cho Carol trên toàn cụm
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: carol-viewer-binding
subjects:
- kind: User
  name: carol
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewer-role
  apiGroup: rbac.authorization.k8s.io
```

---

### 📄 File 3: [argocd/apps/rbac.yaml](../../lab/argocd/apps/rbac.yaml) (Tạo mới)
Khai báo ứng dụng ArgoCD để triển khai tự động cấu hình RBAC ở trên.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rbac
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1" # Deploy ở wave 1
spec:
  project: default
  source:
    repoURL: https://github.com/nabe39/vohongduc-aws-accelerator-p2.git
    path: cloud/w10/lab/rbac # Đường dẫn chứa roles & bindings
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 🧪 Xác minh nghiệm thu Lab 1.1:
Sử dụng tính năng giả lập (Impersonation) của kubectl để kiểm tra quyền hạn thực tế:
```bash
# Alice có thể tạo deployment trong namespace demo không?
kubectl auth can-i create deployment -n demo --as alice
# -> Kết quả: yes

# Alice có thể tạo deployment trong namespace kube-system không?
kubectl auth can-i create deployment -n kube-system --as alice
# -> Kết quả: no (Do RoleBinding chỉ có hiệu lực ở namespace demo)

# Bob có thể xem pods trên toàn cụm không?
kubectl auth can-i get pods -A --as bob
# -> Kết quả: yes (Do có ClusterRoleBinding)

# Carol có thể tạo pod không?
kubectl auth can-i create pod -n demo --as carol
# -> Kết quả: no (Chỉ có quyền get, list, watch)
```

---

## 🚫 Lab 1.2: Admission Policy Với OPA Gatekeeper (4 Chốt Chặn Cơ Bản)

**Mục tiêu:** Thiết lập các chính sách bảo mật bắt buộc ở cấp cụm (Cluster-level Guardrails). Mọi yêu cầu deploy (từ con người hay GitOps) nếu không thỏa mãn luật sẽ bị chặn tại cổng API Server.

### 📄 File 4: [gatekeeper.yaml](../../lab/argocd/apps/gatekeeper.yaml) (Tạo mới)
Ứng dụng ArgoCD cài đặt OPA Gatekeeper Operator vào cụm thông qua Helm Chart chính thức.
* **Sync Wave:** `"0"` (Phải chạy sớm nhất để cụm có định nghĩa CRD trước khi nạp chính sách).
* **Namespace:** `gatekeeper-system`.

---

### 📄 File 5: [templates.yaml](../../lab/gatekeeper/constraints/templates.yaml) (Tạo mới - Trích đoạn 4 chính sách cơ bản)
ConstraintTemplates chứa mã nguồn Rego định nghĩa logic kiểm tra lỗi.

1.  **Chốt chặn cấm tag `latest` (`K8sDisallowedTags`):**
    *   **Logic Rego:** Duyệt qua tất cả các container. Nếu thẻ tag của image trùng với giá trị cấm trong tham số (`tags` chứa `latest`) hoặc không khai báo tag (mặc định hiểu là latest), logic sẽ trả lỗi chặn deploy.
2.  **Chốt chặn bắt buộc CPU & Memory Limits (`K8sRequiredResources`):**
    *   **Logic Rego:** Kiểm tra khối `resources.limits`. Nếu thiếu `cpu` hoặc `memory` được định nghĩa trong danh sách tham số, Rego sẽ thông báo container không hợp lệ.
3.  **Chốt chặn cấm chạy Pod bằng User Root (`K8sPSPAllowedUsers`):**
    *   **Logic Rego:** Đọc trường `securityContext.runAsNonRoot` và `securityContext.runAsUser`. Nếu người dùng không chỉ định chạy non-root hoặc gán UID = 0 (Root), pod sẽ bị từ chối khởi chạy.
4.  **Chốt chặn cấm sử dụng mạng vật lý node (`K8sPSPHostNetworkingPorts`):**
    *   **Logic Rego:** Kiểm tra trường `spec.hostNetwork`. Nếu đặt thành `true`, Rego sẽ từ chối để tránh container escape chiếm quyền cạc mạng vật lý của Node.

---

### 📄 File 6: [constraints.yaml](../../lab/gatekeeper/constraints/constraints.yaml) (Tạo mới - Trích đoạn 4 Constraints cơ bản)
Khởi tạo cấu hình tham số cụ thể và loại trừ (exclude) các namespace hệ thống để tránh lỗi cụm.

```yaml
# 1. Enforce cấm tag latest
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedTags
metadata:
  name: disallow-latest-tag
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    excludedNamespaces: ["kube-system", "gatekeeper-system", "external-secrets", "argocd", "monitoring"]
  parameters:
    tags: ["latest"]
---
# 2. Enforce limits tài nguyên
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: require-resource-limits
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    excludedNamespaces: ["kube-system", "gatekeeper-system", "external-secrets", "argocd", "monitoring"]
  parameters:
    limits: ["cpu", "memory"]
---
# 3. Enforce chạy Non-Root
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPSPAllowedUsers
metadata:
  name: disallow-root-user
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    excludedNamespaces: ["kube-system", "gatekeeper-system", "external-secrets", "argocd", "monitoring"]
  parameters:
    runAsUser:
      rule: MustRunAsNonRoot
---
# 4. Enforce cấm sử dụng HostNetwork
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPSPHostNetworkingPorts
metadata:
  name: disallow-host-network
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    excludedNamespaces: ["kube-system", "gatekeeper-system", "external-secrets", "argocd", "monitoring"]
  parameters:
    hostNetwork: false
```

---

### 📄 File 7: [gatekeeper-policies.yaml](../../lab/argocd/apps/gatekeeper-policies.yaml) (Tạo mới)
Ứng dụng ArgoCD đồng bộ tự động thư mục chứa templates và constraints bảo mật.
* **Sync Wave:** `"1"` (Chạy sau khi Operator ở wave 0 đã cài xong CRDs).

---

### 🧪 Xác minh nghiệm thu Lab 1.2:
Thử deploy pod vi phạm bằng lệnh:
```bash
# Thử chạy pod không có resource limits
kubectl run test-pod --image=nginx:alpine -n demo
# -> Kết quả kỳ vọng: Bị từ chối
# Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: container <test-pod> does not have <cpu, memory> limits defined
```

---

## 🎯 Lab 1.3: Custom Policy - Giới Hạn Replicas (Challenge)

**Mục tiêu:** Viết một chính sách tùy chỉnh (Custom Rego Policy) của riêng bạn. Ở đây bài Lab yêu cầu **giới hạn số lượng bản sao (replicas) của Deployment** chỉ được phép nằm trong khoảng từ `1` đến `5` pod.

### 📄 File 8: [templates.yaml](../../lab/gatekeeper/constraints/templates.yaml) (Chỉnh sửa bổ sung template Custom)
Định nghĩa schema nhận vào dải min/max replicas và logic Rego.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sreplicalimits
  annotations:
    argocd.argoproj.io/sync-wave: '1'
spec:
  crd:
    spec:
      names:
        kind: K8sReplicaLimits
      validation:
        openAPIV3Schema:
          type: object
          properties:
            ranges:
              type: array
              items:
                type: object
                properties:
                  min_replicas: { type: integer }
                  max_replicas: { type: integer }
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sreplicalimits

        object_name = input.review.object.metadata.name
        object_kind = input.review.kind.kind

        # Vi phạm xảy ra nếu cấu hình spec.replicas không thỏa mãn hàm kiểm tra dải số lượng
        violation[{"msg": msg}] {
            spec := input.review.object.spec
            not input_replica_limit(spec)
            msg := sprintf("The provided number of replicas is not allowed for %v: %v. Allowed ranges: %v", [object_kind, object_name, input.parameters])
        }

        # Hàm kiểm tra giá trị replicas có nằm trong dải min_replicas và max_replicas không
        input_replica_limit(spec) {
            provided := spec.replicas
            count(input.parameters.ranges) > 0
            range := input.parameters.ranges[_]
            value_within_range(range, provided)
        }

        value_within_range(range, value) {
            range.min_replicas <= value
            range.max_replicas >= value
        }
```

---

### 📄 File 9: [constraints.yaml](../../lab/gatekeeper/constraints/constraints.yaml) (Chỉnh sửa bổ sung Constraint Custom)
Áp dụng giới hạn Replicas cụ thể cho đối tượng Deployment.

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sReplicaLimits
metadata:
  name: replica-limits
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"] # Chỉ áp dụng kiểm tra lên Deployment
    excludedNamespaces: ["kube-system", "gatekeeper-system", "external-secrets", "argocd", "monitoring"]
  parameters:
    ranges:
    - min_replicas: 1
      max_replicas: 5 # Replicas chỉ được phép chạy từ 1 đến 5 pod
```

---

### 🧪 Xác minh nghiệm thu Lab 1.3:
Thử chỉnh sửa số lượng replicas của một deployment trong namespace `demo`:
```bash
# Thử scale deployment api lên 6 replicas
kubectl scale rollout api --replicas=6 -n demo
# -> Kết quả kỳ vọng: Bị chặn hoàn toàn
# Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: The provided number of replicas is not allowed for Rollout/Deployment...
```
*(Lưu ý: Rollout của ArgoCD kế thừa schema Deployment và cũng sẽ tự động bị chặn nếu vi phạm).*
