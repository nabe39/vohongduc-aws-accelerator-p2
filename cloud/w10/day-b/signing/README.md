# 🧪 Lab 2: Ký số Container Image với Cosign & Xác thực qua Kyverno

> **Đường dẫn thư mục:** [cloud/w10/day-b/signing/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/signing)
>
> **Mục tiêu:** Cài đặt Cosign, sinh cặp khóa bảo mật để ký số cho container image, triển khai Kyverno admission policy để xác thực chữ ký và chặn triệt để các image chưa ký triển khai vào cụm.

---

## 🛠️ Các bước thực hiện

### Bước 1: Cài đặt Cosign CLI
Tùy thuộc vào OS của bạn:
*   **macOS (via Homebrew):** `brew install cosign`
*   **Windows (via Winget):** `winget install sigstore.cosign`
*   **Linux/Ubuntu:**
    ```bash
    LATEST_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d \"\,\- | xargs)
    curl -LO https://github.com/sigstore/cosign/releases/download/${LATEST_VERSION}/cosign-linux-amd64
    sudo install -o root -g root -m 0755 cosign-linux-amd64 /usr/local/bin/cosign
    ```

---

### Bước 2: Tạo cặp khóa ký số (Generate Key Pair)
Chạy lệnh sau để sinh cặp khóa (private key `cosign.key` và public key `cosign.pub`):

```bash
cosign generate-key-pair
```
*Hệ thống sẽ yêu cầu bạn nhập mật khẩu (passphrase) để bảo vệ private key.*

> [!WARNING]
> Không bao giờ commit file `cosign.key` lên Git. Hãy lưu trữ an toàn hoặc chuyển thành GitHub Actions Secrets khi cấu hình CI/CD.

---

### Bước 3: Build, Tag và Push Image lên Registry (AWS ECR)
Đăng nhập ECR và thực hiện build/push image của ứng dụng:

```bash
# Đăng nhập ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com

# Build image
docker build -t 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/my-app:1.0.0 .

# Push image
docker push 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/my-app:1.0.0
```

---

### Bước 4: Ký số Container Image với Cosign
Sử dụng khóa bí mật `cosign.key` vừa tạo để ký số trực tiếp lên image đã push:

```bash
cosign sign --key cosign.key 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/my-app:1.0.0
```
*Nhập lại passphrase bạn đã đặt ở Bước 2. Lệnh này sẽ tạo ra một artifact chữ ký và đẩy trực tiếp lên repository ECR của bạn (thường có tag dạng `sha256-...sig`).*

---

### Bước 5: Cài đặt Kyverno Policy Engine trên K8s
Sử dụng Helm để cài đặt Kyverno:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

Kiểm tra xem Kyverno đã sẵn sàng chưa:
```bash
kubectl get pods -n kyverno
```

---

### Bước 6: Khai báo Policy Xác thực hình ảnh (Verify Signature Policy)

1.  Mở file [verify-image-policy.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/signing/verify-image-policy.yaml).
2.  Thay thế `imageReferences` bằng URL ECR chính xác của bạn.
3.  Thay thế nội dung khóa công khai trong trường `key` bằng nội dung từ file `cosign.pub` của bạn.
4.  Áp dụng policy lên cụm:
    ```bash
    kubectl apply -f verify-image-policy.yaml
    ```

---

### Bước 7: Thực nghiệm Kiểm thử (Verification)

#### Case 1: Deploy một Image chưa ký (Unsigned)
Thử deploy một phiên bản ứng dụng chưa được ký số (ví dụ tag `:latest` hoặc một ảnh khác):
```bash
kubectl run test-unsigned --image=123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/my-app:latest
```
*Output mong đợi: API Server từ chối và in ra lỗi tương tự:*
`Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: verify-image-signature: signature verification failed for ...`

#### Case 2: Deploy Image đã ký (Signed)
Thử deploy phiên bản `:1.0.0` đã được ký ở Bước 4:
```bash
kubectl run test-signed --image=123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/my-app:1.0.0
```
*Output mong đợi: Pod được tạo thành công!*
```bash
kubectl get pods test-signed
```
*Trạng thái của Pod chuyển sang `Running` bình thường.*

---

## 🧹 Dọn dẹp tài nguyên (Cleanup)

Sau khi hoàn thành thực hành, hãy gỡ bỏ các cấu hình và tài nguyên thử nghiệm để đưa cluster về trạng thái sạch:

```bash
# 1. Xóa các Pod kiểm thử
kubectl delete pod test-signed --force --grace-period=0
kubectl delete pod test-unsigned --force --grace-period=0 2>/dev/null

# 2. Xóa Kyverno verify image policy
kubectl delete -f verify-image-policy.yaml

# 3. Gỡ cài đặt Kyverno Policy Engine
helm uninstall kyverno -n kyverno
kubectl delete ns kyverno

# 4. Xóa cặp khóa Cosign cục bộ
rm cosign.key cosign.pub
```

