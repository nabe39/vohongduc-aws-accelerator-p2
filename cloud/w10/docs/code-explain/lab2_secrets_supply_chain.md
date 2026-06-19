# 🔑 Lab 2: Secrets, Supply Chain & Platform Integration

Tài liệu này giải thích chi tiết cấu trúc thư mục, ý nghĩa mã nguồn, và cơ chế hoạt động của các chính sách bảo mật trong bài Lab 2, được phân định rõ ràng thành bài Lab 2.1 và Lab 2.2.

---

## 🔐 Lab 2.1: Quản Lý Secrets Động (Secrets Rotation với ESO)

**Mục tiêu:** Loại bỏ hoàn toàn credentials lưu dạng bản rõ (plaintext) trên Git. Sử dụng **External Secrets Operator (ESO)** để tự động đồng bộ mật khẩu DB từ **AWS Secrets Manager** về Kubernetes Secret. Thực hiện xoay vòng mật khẩu dưới 60 giây và tự động nạp cấu hình mới mà không làm restart Pod (Zero-Downtime).

### 📄 File 1: [eso/secret-store.yaml](../../lab/eso/secret-store.yaml) (Tạo mới)
Khai báo nguồn cung cấp thông tin bí mật (AWS Secrets Manager) và phương thức xác thực.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: demo
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1 # Vùng AWS nơi lưu trữ Secret
      auth:
        secretRef:
          # Minikube không có IRSA, chúng ta sử dụng AWS Access Keys được tạo thủ công qua K8s Secret awssm-secret
          accessKeyIDSecretRef:
            name: awssm-secret
            key: access-key
          secretAccessKeySecretRef:
            name: awssm-secret
            key: secret-access-key
```

---

### 📄 File 2: [eso/external-secret.yaml](../../lab/eso/external-secret.yaml) (Tạo mới)
Định nghĩa ánh xạ từ kho khóa AWS về cụm K8s và tần suất đồng bộ.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-db-secret
  namespace: demo
spec:
  refreshInterval: 10s # Cứ mỗi 10 giây sẽ poll AWS Secrets Manager để cập nhật giá trị mới
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: k8s-db-secret # K8s Secret được sinh ra tự động trong namespace demo
    creationPolicy: Owner
  data:
    - secretKey: database-password # Tên khóa trong K8s Secret
      remoteRef:
        key: dev/app/mysql # Khóa trên AWS Secrets Manager
        property: password # Thuộc tính lấy ra từ chuỗi JSON
    - secretKey: database-username
      remoteRef:
        key: dev/app/mysql
        property: username
```

---

### 📄 File 3: [app-api/rollout.yaml](../../lab/app-api/rollout.yaml) (Modify - Cơ chế Volume Mount)
Để cập nhật mật khẩu động không gây restart Pod, chúng ta mount mật khẩu dạng file thay vì inject vào Environment Variables.

```yaml
spec:
  containers:
  - name: api
    image: ghcr.io/nabe39/w10-api:0.0.1
    # ...
    volumeMounts:
    - name: db-secrets
      mountPath: /etc/secrets # Thư mục chứa file mật khẩu trong pod
      readOnly: true
  volumes:
  - name: db-secrets
    secret:
      secretName: k8s-db-secret # Đọc dữ liệu từ secret do ESO sinh ra
```

---

### 📄 File 4: [argocd/apps/eso.yaml](../../lab/argocd/apps/eso.yaml) & [eso-config.yaml](../../lab/argocd/apps/eso-config.yaml) (Tạo mới)
*   `eso.yaml` (Wave 0): Cài đặt External Secrets Operator Helm Chart vào namespace `external-secrets` và tự động đăng ký các CRDs (`SecretStore`, `ExternalSecret`).
*   `eso-config.yaml` (Wave 1): Đồng bộ các định nghĩa SecretStore và ExternalSecret vào cụm sau khi Operator đã sẵn sàng.

---

### 📄 File 5: [runbooks/runbook-eso.md](../../lab/runbooks/runbook-eso.md) (Tạo mới)
Tài liệu hướng dẫn SRE kiểm tra cơ chế xoay vòng mật khẩu dynamic:
1.  Đổi value secret trên AWS Secrets Manager:
    `aws secretsmanager put-secret-value --secret-id dev/app/mysql --secret-string '{"username":"dbuser","password":"newpassword"}'`
2.  Sau 10 giây, kiểm tra K8s secret đã đổi giá trị mới:
    `kubectl get secret k8s-db-secret -n demo -o jsonpath="{.data.database-password}" | base64 -d`
3.  Kiểm tra pod không hề bị restart (restart count = 0, AGE không đổi) và giá trị trong file đã thay đổi:
    `kubectl exec -it deploy/api -n demo -c api -- cat /etc/secrets/database-password`

---

## 🛡️ Lab 2.2: Bảo Mật Chuỗi Cung Ứng (Trivy + Cosign + Sigstore)

**Mục tiêu:** Ngăn chặn việc chạy image chứa lỗ hổng bảo mật nghiêm trọng (HIGH/CRITICAL CVE) và các container image không rõ nguồn gốc (chưa được ký số từ CI/CD đáng tin cậy).

### 📄 File 6: [Dockerfile](../../lab/src/api/Dockerfile) (Modify)
Đổi sang sử dụng base image `python:3.13-alpine` (thay vì Python cũ) để loại bỏ tối đa các CVE hệ điều hành của base image cũ.

---

### 📄 File 7: [.github/workflows/build-push.yml](../../../.github/workflows/build-push.yml) (Modify)
Pipeline CI tự động thực hiện scan lỗ hổng và ký số ảnh trước khi cho phép deploy.

```yaml
# ...
      # 1. Build and push image tạm thời
      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: ./cloud/w10/lab/src/api
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      # 2. Quét lỗ hổng image bằng Trivy
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.semver.outputs.version }}
          format: 'table'
          exit-code: '1' # Rất quan trọng: Báo lỗi và dừng ngay CI pipeline nếu phát hiện lỗi bảo mật
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'

      # 3. Cài đặt Cosign
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.8.2

      # 4. Ký số ảnh bằng khóa private
      - name: Sign container images
        run: |
          cosign sign --yes --key env://COSIGN_PRIVATE_KEY ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.semver.outputs.version }}
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
```

---

### 📄 File 8: [.trivyignore](../../../.trivyignore) & [runbooks/adr-cve-exception.md](../../lab/runbooks/adr-cve-exception.md) (Tạo mới/Chỉnh sửa)
Khi phát hiện CVE (ví dụ: `CVE-2023-38545` trong curl) nhưng nhà cung cấp chưa có bản vá:
*   Chúng ta ghi nhận lý do kỹ thuật và đặt hạn ngoại lệ (30 ngày) vào tài liệu **ADR** để bảo đảm quy trình kiểm tra minh bạch.
*   Bổ sung mã CVE vào `.trivyignore` để tạm hoãn chặn CI, cho phép triển khai các hotfix khẩn cấp.

---

### 📄 File 9: [policies/cluster-image-policy.yaml](../../lab/policies/cluster-image-policy.yaml) (Tạo mới) & [cosign.pub](../../lab/signing/cosign.pub) (Tạo mới)
Chính sách xác thực chữ ký của cụm Kubernetes (Sử dụng Sigstore Policy Controller).

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: image-signature-policy
spec:
  images:
  - glob: "ghcr.io/nabe39/w10-api*" # Chỉ áp dụng chính sách bắt buộc kiểm tra chữ ký với ảnh w10-api
  authorities:
  - key:
      data: | # Dán Khóa công khai của Cosign (cosign.pub) vào đây
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEuoT7aEp7cUsGvP4EI6q2j1/SGk/1
        2C259MaXAtLyGfY6jnyfjt13nzx9YSMx/6h3dr9+p4spQ7pqzDh0IPhF/g==
        -----END PUBLIC KEY-----
```

---

### 📄 File 10: [demo-namespace.yaml](../../lab/app-common/demo-namespace.yaml) (Modify)
Kích hoạt kiểm tra chữ ký số trên namespace bằng cách gán nhãn label bắt buộc.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  labels:
    policy.sigstore.dev/include: "true" # Sigstore Admission controller sẽ chỉ can thiệp quét các Namespace có label này
```

---

### 📄 File 11: [policy-controller.yaml](../../lab/argocd/apps/policy-controller.yaml) & [policies.yaml](../../lab/argocd/apps/policies.yaml) (Tạo mới)
*   `policy-controller.yaml` (Wave 0): Cài đặt Sigstore Policy Controller Operator bằng Helm (Namespace `cosign-system`).
*   `policies.yaml` (Wave 1): Đẩy cấu hình chính sách `ClusterImagePolicy` xác thực khóa công khai lên cụm.

---

### 🧪 Xác minh nghiệm thu Lab 2.2:
1.  **Nếu push code chứa image có CVE HIGH** -> Trivy scan báo lỗi, CI đỏ, chặn không cho deploy.
2.  **Deploy image chưa ký số** (ví dụ deploy ảnh nginx hoặc w10-api được build chay từ máy local không qua CI):
    `kubectl run unsigned-test --image=ghcr.io/nabe39/w10-api:unsigned -n demo`
    -> Kết quả kỳ vọng: Bị chặn.
    `Error from server (Forbidden): admission webhook "policy.sigstore.dev" denied the request: validation failed: image ghcr.io/nabe39/w10-api:unsigned does not have a valid signature`
3.  **Deploy image đã ký số từ CI/CD** -> Pod chạy thành công (`Running`).
