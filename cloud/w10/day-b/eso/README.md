# 🧪 Lab 1: Tích hợp External Secrets Operator (ESO) & Auto Rotation

> **Đường dẫn thư mục:** [cloud/w10/day-b/eso/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/eso)
>
> **Mục tiêu:** Cài đặt ESO, liên kết cụm Kubernetes với AWS Secrets Manager bằng IAM Roles for Service Accounts (IRSA), đồng bộ secret tự động và kiểm tra cơ chế tự động xoay vòng mật khẩu (rotation) dưới 60 giây mà không cần restart Pod.

---

## 🛠️ Các bước thực hiện

### Bước 1: Cài đặt External Secrets Operator (ESO)
Nếu cụm chưa cài đặt ESO, hãy triển khai bằng Helm:

```bash
# Thêm Helm repository của ESO
helm repo add external-secrets https://charts.external-secrets.io

# Cập nhật repository
helm repo update

# Cài đặt ESO vào namespace external-secrets
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Kiểm tra trạng thái các Pods của ESO:
```bash
kubectl get pods -n external-secrets
```

---

### Bước 2: Thiết lập AWS IAM Policy & Role cho ServiceAccount (IRSA)
Để ESO có quyền đọc secret từ AWS Secrets Manager mà không cần dùng Access Key tĩnh, chúng ta cấu hình IRSA.

1.  **Tạo IAM Policy** cho phép đọc Secret trên AWS:
    Tạo một file policy tên là `eso-policy.json`:
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ],
                "Resource": "arn:aws:secretsmanager:ap-southeast-1:YOUR_ACCOUNT_ID:secret:dev/app/*"
            }
        ]
    }
    ```
    Tạo policy trên AWS:
    ```bash
    aws iam create-policy --policy-name EKS-ESO-ReadSecrets-Policy --policy-document file://eso-policy.json
    ```

2.  **Associate IAM Role với ServiceAccount** bằng `eksctl`:
    ```bash
    eksctl create iamserviceaccount \
      --name external-secrets-sa \
      --namespace external-secrets \
      --cluster your-eks-cluster-name \
      --role-name EKS-ESO-ReadSecrets-Role \
      --attach-policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/EKS-ESO-ReadSecrets-Policy \
      --approve \
      --override-existing-serviceaccounts
    ```

---

### Bước 3: Tạo Secret trên AWS Secrets Manager
Truy cập AWS Console hoặc dùng AWS CLI để tạo secret chứa thông tin đăng nhập database:

```bash
aws secretsmanager create-secret \
  --name dev/app/mysql \
  --description "Database credentials for Dev app" \
  --secret-string '{"username":"dbadmin","password":"SuperSecurePassword123"}' \
  --region ap-southeast-1
```

---

### Bước 4: Khai báo ClusterSecretStore & ExternalSecret
1.  Áp dụng cấu hình kết nối tới AWS Secrets Manager:
    ```bash
    kubectl apply -f clustersecretstore.yaml
    ```
    *Xem cấu hình tại:* [clustersecretstore.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/eso/clustersecretstore.yaml)

2.  Tạo namespace `development` để chạy ứng dụng (nếu chưa có):
    ```bash
    kubectl create namespace development
    ```

3.  Áp dụng `ExternalSecret` để đồng bộ thông tin nhạy cảm:
    ```bash
    kubectl apply -f externalsecret.yaml
    ```
    *Xem cấu hình tại:* [externalsecret.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/eso/externalsecret.yaml)

---

### Bước 5: Kiểm tra và xác thực đồng bộ (Verification)

1.  **Kiểm tra trạng thái đồng bộ của ExternalSecret:**
    ```bash
    kubectl get externalsecret app-db-secret -n development
    ```
    *Output mong đợi có cột STATUS là `SecretSynced`.*

2.  **Kiểm tra K8s Secret được sinh ra:**
    ```bash
    kubectl get secret k8s-db-secret -n development -o yaml
    ```

3.  **Giải mã xem giá trị secret trong K8s có khớp với AWS Secrets Manager:**
    ```bash
    kubectl get secret k8s-db-secret -n development -o jsonpath='{.data.database-password}' | base64 --decode
    ```

---

### Bước 6: Kiểm tra Auto Rotation (< 60s)
1.  Cập nhật giá trị secret trên AWS Secrets Manager:
    ```bash
    aws secretsmanager put-secret-value \
      --secret-id dev/app/mysql \
      --secret-string '{"username":"dbadmin","password":"RotatedPassword999!"}' \
      --region ap-southeast-1
    ```
2.  Chờ khoảng **60 giây** (theo cấu hình `refreshInterval: 1m` trong `externalsecret.yaml`).
3.  Giải mã lại secret trong K8s để kiểm tra xem giá trị đã tự động cập nhật hay chưa:
    ```bash
    kubectl get secret k8s-db-secret -n development -o jsonpath='{.data.database-password}' | base64 --decode
    ```
    *Nếu output in ra `RotatedPassword999!`, việc tự động xoay vòng không cần restart Pod đã hoạt động hoàn hảo!*

---

## 🧹 Dọn dẹp tài nguyên (Cleanup)

Sau khi hoàn thành thực hành, hãy dọn dẹp các tài nguyên để tránh phát sinh chi phí hoặc rác trong cụm:

```bash
# 1. Xóa các tài nguyên ESO đã tạo
kubectl delete -f externalsecret.yaml
kubectl delete -f clustersecretstore.yaml

# 2. Xóa Namespace development
kubectl delete ns development

# 3. Gỡ cài đặt External Secrets Operator
helm uninstall external-secrets -n external-secrets
kubectl delete ns external-secrets

# 4. Xóa AWS Secrets Manager Secret
aws secretsmanager delete-secret \
  --secret-id dev/app/mysql \
  --force-delete-without-recovery \
  --region ap-southeast-1

# 5. Xóa IAM ServiceAccount (IRSA) và IAM Policy
eksctl delete iamserviceaccount \
  --name external-secrets-sa \
  --namespace external-secrets \
  --cluster your-eks-cluster-name

# Xóa policy trên AWS (cần lấy ARN chính xác của policy)
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='EKS-ESO-ReadSecrets-Policy'].Arn" --output text)
aws iam delete-policy --policy-arn $POLICY_ARN
```

