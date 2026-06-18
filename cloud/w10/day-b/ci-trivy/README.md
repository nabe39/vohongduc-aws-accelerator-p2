# 🧪 Lab 3: Tích hợp Trivy Image Scan & Cấu hình Exception Policy trong CI/CD

> **Đường dẫn thư mục:** [cloud/w10/day-b/ci-trivy/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/ci-trivy)
>
> **Mục tiêu:** Cài đặt Trivy quét lỗ hổng bảo mật cho container image, tích hợp quét tự động vào pipeline CI/CD, thiết lập chính sách chặn build khi phát hiện lỗi HIGH/CRITICAL, và thực hành quy trình bypass CVE ngoại lệ bằng `.trivyignore` dựa trên Security ADR.

---

## 🛠️ Các bước thực hiện

### Bước 1: Cài đặt Trivy cục bộ (Local Testing)
*   **Windows (via winget / scoop):**
    ```bash
    winget install AquaSecurity.Trivy
    # hoặc
    scoop install trivy
    ```
*   **macOS (via Homebrew):**
    ```bash
    brew install aquasecurity/trivy/trivy
    ```
*   **Linux/Debian/Ubuntu:**
    ```bash
    sudo apt-get install wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy
    ```

---

### Bước 2: Quét thử nghiệm Image
Tiến hành quét một image có sẵn trên Docker Hub (ví dụ `nginx:1.19` nổi tiếng có nhiều CVE):

```bash
trivy image nginx:1.19
```
*Trivy sẽ tải database lỗ hổng mới nhất (Vulnerability DB) và phân tích các layer của image.*

---

### Bước 3: Cấu hình Fail-on Policy cho CI
Để cấu hình pipeline tự động dừng khi phát hiện các lỗ hổng nguy hiểm (`HIGH` hoặc `CRITICAL`):

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL nginx:1.19
```
*Lệnh trên sẽ kết thúc với Exit Code 1. Trong CI/CD, bất cứ lệnh nào kết thúc với Exit Code khác 0 sẽ đánh dấu step đó thất bại và dừng pipeline.*

---

### Bước 4: Tích hợp vào GitHub Actions Pipeline
Dưới đây là một phần cấu hình workflow GitHub Actions (`.github/workflows/ci.yml`) để tự động build và quét ảnh:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ "main" ]

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build local image
        run: |
          docker build -t my-app:${{ github.sha }} .

      # Quét image và tạo file báo cáo dạng bảng trên GitHub Action log
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1' # Dừng build nếu phát hiện lỗi
          ignore-unfixed: true # Chỉ quan tâm lỗi đã có bản vá
          severity: 'HIGH,CRITICAL'
```

---

### Bước 5: Áp dụng Exception Policy bằng `.trivyignore`
Khi phát hiện lỗ hổng nhưng tổ chức đồng ý bỏ qua (Ví dụ do lỗi thuộc thư viện nền chưa có bản vá từ CentOS/Debian và đã được ký duyệt qua **Security ADR**):

1.  Kiểm tra danh sách CVE bị phát hiện, xác định mã CVE cần bỏ qua (ví dụ: `CVE-2023-38545`).
2.  Tạo hoặc chỉnh sửa file [.trivyignore](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w10/day-b/ci-trivy/.trivyignore) ở thư mục gốc hoặc chỉ định rõ đường dẫn khi quét.
3.  Quét lại image kèm theo cờ cấu hình ignore:
    ```bash
    trivy image --ignorefile .trivyignore --exit-code 1 --severity HIGH,CRITICAL nginx:1.19
    ```
    *Nếu các CVE bị chặn đã nằm trong file `.trivyignore`, lệnh quét sẽ kết thúc thành công (Exit Code 0), cho phép pipeline tiếp tục triển khai.*

---

## 🧹 Dọn dẹp tài nguyên (Cleanup)

Đối với bài Lab quét Trivy trên local và CI, bạn không tạo tài nguyên tốn phí nào trên Cloud. Để dọn dẹp môi trường local của bạn:

```bash
# 1. Xóa các Docker image thử nghiệm trên local máy dev (nếu có)
docker rmi nginx:1.19
docker rmi my-app:latest 2>/dev/null

# 2. Xóa cache cơ sở dữ liệu lỗ hổng của Trivy (giải phóng dung lượng ổ đĩa)
trivy clean --all

# 3. Gỡ cài đặt Trivy CLI (Tùy chọn)
# macOS: brew uninstall trivy
# Windows (scoop): scoop uninstall trivy
# Linux: sudo apt-get remove trivy
```

