# 📖 Tài Liệu Lý Thuyết: Cơ Chế Hoạt Động Của Các Kỹ Thuật (Lab 1 & 2)

Tài liệu này giải thích chi tiết cơ chế hoạt động chiều sâu của các công nghệ được áp dụng từ Lab 1.1 đến Lab 2.2.

---

## 🔑 1. Cơ Chế Hoạt Động Của RBAC (Lab 1.1)

Kubernetes API Server xử lý mọi yêu cầu thông qua ba bước chính: **Authentication** (Xác thực danh tính), **Authorization** (Phân quyền hành động), và **Admission Control** (Kiểm soát đầu vào). **RBAC** (Role-Based Access Control) hoạt động ở bước 2: **Authorization**.

```
[Request] ➡️ [1. Authentication] ➡️ [2. Authorization (RBAC)] ➡️ [3. Admission Control] ➡️ [etcd]
```

### 🔹 Cách K8s xác định quyền hạn:
1.  **Chủ thể (Subjects):** Là đối tượng thực hiện yêu cầu, gồm 3 loại:
    *   **User:** Người dùng thực tế (đăng nhập bằng certificate, OIDC...).
    *   **Group:** Nhóm người dùng.
    *   **ServiceAccount (SA):** Danh tính dành riêng cho các ứng dụng chạy bên trong Pod.
2.  **Định nghĩa quyền (Roles & ClusterRoles):** 
    *   Là một tập hợp các quy tắc gồm: **apiGroups** (nhóm API cần truy cập), **resources** (tài nguyên cụ thể như pods, services, deployments), và **verbs** (hành động được phép như `get`, `list`, `create`, `delete`).
    *   `Role` giới hạn trong **1 Namespace**. `ClusterRole` áp dụng trên **toàn cụm** (hoặc cho tài nguyên phi namespace như Nodes, Namespaces).
3.  **Liên kết quyền (RoleBindings & ClusterRoleBindings):**
    *   Đóng vai trò như một chiếc "cầu nối" để gán vai trò (Role/ClusterRole) cho Chủ thể (User/SA).

### 🧪 Cơ chế impersonation (`--as <user>`):
Khi bạn chạy lệnh `kubectl auth can-i create pod --as alice`, API Server sẽ nhận diện bạn là Admin nhưng giả lập header yêu cầu của `alice`. API Server sẽ tra cứu xem có bất kỳ `RoleBinding` hay `ClusterRoleBinding` nào trỏ tới subject `alice` cho phép verb `create` trên resource `pods` hay không và trả về kết quả `yes` hoặc `no`.

---

## 🚫 2. Cơ Chế Admission Controller & OPA Gatekeeper (Lab 1.2 & 1.3)

Sau khi yêu cầu vượt qua chốt chặn RBAC, nó sẽ đi tới **Admission Control**. Đây là chốt chặn cuối cùng kiểm tra xem nội dung khai báo (manifest) của tài nguyên có an toàn hay không trước khi ghi vào database `etcd`.

```
[Authorization Pass] ➡️ [Mutating Webhooks] ➡️ [Validating Webhooks (Gatekeeper)] ➡️ [Write to etcd]
                                                   (Từ chối nếu vi phạm)
```

### 🔹 Cách OPA Gatekeeper hoạt động:
Gatekeeper hoạt động như một **Validating Admission Webhook**:
1.  Khi có yêu cầu ghi manifest (ví dụ `kubectl apply`), API Server gửi một JSON payload chứa toàn bộ thông tin tài nguyên (`AdmissionReview`) tới Gatekeeper webhook.
2.  Gatekeeper nạp payload này vào biến đặc biệt `input.review.object` trong động cơ Rego.
3.  **ConstraintTemplate:** Định nghĩa một cấu trúc dữ liệu CRD mới trên Kubernetes (ví dụ: `K8sDisallowedTags`) và chứa mã logic bằng ngôn ngữ Rego để đánh giá payload `input.review.object`.
4.  **Constraint:** Là hiện thân cụ thể chứa các tham số đầu vào (ví dụ: cấm tag `latest`) áp dụng cho các namespace được chỉ định.
5.  Nếu logic Rego phát hiện điều kiện vi phạm, nó sẽ sinh ra một thông báo lỗi và gửi ngược lại cho API Server để từ chối yêu cầu triển khai của người dùng ngay lập tức.

---

## 🔐 3. Cơ Chế Xoay Vòng Secrets Động Của ESO (Lab 2.1)

Secrets trong K8s mặc định chỉ được mã hóa dạng **Base64** thô sơ trên Git. **External Secrets Operator (ESO)** giải quyết việc bảo mật này bằng cách tích hợp trực tiếp cụm EKS với kho khóa đám mây chuyên dụng như **AWS Secrets Manager**.

```
[AWS Secrets Manager] ➡️ (Sync mỗi 10s) ➡️ [ESO Operator] ➡️ [K8s Secret] ➡️ [Pod Mount Volume]
```

### 🔹 Tại sao Mount Volume tự reload mật khẩu không cần restart Pod?
1.  **Environment Variables (Biến môi trường):** Khi K8s inject secrets vào pod dưới dạng biến môi trường, tiến trình ứng dụng chỉ đọc các biến này duy nhất một lần khi khởi động (container boot). Nếu secret thay đổi trên AWS, K8s Secret thay đổi, nhưng biến môi trường của container vẫn giữ giá trị cũ. Bạn buộc phải restart/recreate Pod để lấy giá trị mới.
2.  **Volume Mount (File gắn kết):** Khi gắn Secret làm ổ đĩa ảo (Volume) dạng file (ví dụ tại thư mục `/etc/secrets/`):
    *   Khi mật khẩu trên AWS Secrets Manager thay đổi, ESO sẽ cập nhật giá trị của Kubernetes Secret tương ứng trong vòng 10 giây (`refreshInterval: 10s`).
    *   Bộ điều phối **Kubelet** chạy trên Node vật lý định kỳ kiểm tra sự thay đổi của K8s Secret. Khi phát hiện thay đổi, Kubelet tự ghi đè giá trị mới lên file `/etc/secrets/database-password` trong container.
    *   Ứng dụng chỉ cần đọc file này mỗi khi thiết lập kết nối cơ sở dữ liệu mới. Nhờ đó, thông tin mật khẩu được cập nhật động và đảm bảo **zero downtime** (không làm sập/restart ứng dụng).

---

## 🛡️ 4. Cơ Chế Quét & Ký Số Ảnh Cosign + Sigstore (Lab 2.2)

Để bảo đảm an toàn chuỗi cung ứng phần mềm (Supply Chain Security), chúng ta cần trả lời được hai câu hỏi cốt lõi:
1.  **Image có chứa lỗ hổng bảo mật nghiêm trọng không?** (Do **Trivy** đảm nhận trong CI).
2.  **Image có đúng là do hệ thống CI/CD chính thức của chúng ta build ra không, hay bị tin tặc chèn mã độc vào Registry?** (Do **Cosign** và **Sigstore Policy Controller** đảm nhận).

### 🔹 Cách Cosign ký số container image (CI Pipeline):
Cosign sử dụng mật mã học khóa công khai (asymmetric cryptography - cụ thể là thuật toán ký số ECDSA P-256) để ký số ảnh:

```
[Container Image] ➡️ [Hash SHA-256] ➡️ [Ký bằng Private Key] ➡️ [Đẩy chữ ký (.sig) lên Registry]
```

1.  **Tạo cặp khóa:** Cosign sinh ra một khóa riêng tư (**Private Key** - giữ bí mật tuyệt đối trong GitHub Secrets) và khóa công khai (**Public Key** - công khai để verify).
2.  **Tạo Hash ảnh:** Mỗi container image có một mã định danh duy nhất không thể thay đổi dựa trên nội dung của nó, gọi là **Digest** (mã băm SHA-256). Ví dụ: `ghcr.io/nabe39/w10-api@sha256:1a2b3c...`.
3.  **Ký Digest:** Cosign lấy digest đó băm qua thuật toán ký mã hóa với Private Key để tạo ra một chuỗi **Chữ ký số (Signature)**.
4.  **Lưu trữ chữ ký:** Chữ ký số này được đẩy thẳng lên Container Registry (Docker Hub/GHCR) dưới dạng một tag đặc biệt kết hợp với mã băm của image ban đầu (ví dụ: `sha256-1a2b3c...sig`). Chữ ký này nằm ngay bên cạnh image trong registry.

---

### 🔹 Cách Sigstore Policy Controller biết image đã được ký (K8s Cluster):
Khi bạn deploy ứng dụng vào cụm Kubernetes:

```
[Deploy Request] ➡️ [Sigstore Admission Webhook]
                         |
                         v
     1. Lấy Image Digest từ Registry
     2. Tải file chữ ký (.sig) tương ứng
     3. Giải mã chữ ký bằng Public Key cài trong cụm
     4. So sánh Digest đã ký với Digest thực tế của image
                         |
      +------------------+------------------+
      | (Khớp nhau)                         | (Không khớp / Thiếu chữ ký)
      v                                     v
   [PASS: Cho phép deploy]               [REJECT: Chặn đứng yêu cầu]
```

1.  API Server chuyển tiếp yêu cầu khởi tạo Pod tới **Sigstore Policy Controller Admission Webhook**.
2.  Bộ điều khiển Sigstore xem xét tên ảnh và liên hệ với Container Registry để lấy mã **Image Digest** thực tế cùng file chữ ký đi kèm (`.sig`).
3.  Sigstore lấy **Khóa công khai (Public Key)** được lưu trữ trong cấu hình `ClusterImagePolicy` để giải mã chữ ký số tải về.
4.  **Xác minh tính toàn vẹn:**
    *   Nếu giải mã thành công và Digest trong chữ ký **khớp hoàn toàn** với Digest của image đang tải, điều này chứng minh:
        1. Image được build từ nguồn CI/CD sở hữu khóa Private tương ứng.
        2. Image không hề bị thay đổi hay chèn mã độc sau khi ký (do digest mã băm trùng khớp).
    *   Nếu chữ ký không tồn tại, hoặc giải mã ra digest không khớp, Sigstore lập tức chặn yêu cầu deploy và trả lỗi `Forbidden` cho người dùng.
