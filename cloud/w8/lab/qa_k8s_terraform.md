# Giải thích chi tiết về K8s, Terraform và Cơ chế hoạt động của Lab

Tài liệu này trả lời chi tiết từng câu hỏi của bạn để phục vụ việc học tập và nghiên cứu.

---

## 1. Vì sao dùng K8s (Kubernetes)?
**Kubernetes (K8s)** là một nền tảng mã nguồn mở dùng để **tự động hóa việc điều phối container** (Container Orchestration). Chúng ta dùng K8s vì các lý do sau:
*   **Quản lý Container ở quy mô lớn (Scaling)**: Nếu ứng dụng có 1-2 container, ta dùng Docker là đủ. Nhưng khi hệ thống có hàng chục, hàng trăm container chạy trên nhiều server khác nhau, Docker đơn lẻ không thể tự quản lý được. K8s sẽ gom nhiều server vật lý/ảo (nodes) thành một cụm duy nhất để chạy container.
*   **Tự động phục hồi (Self-Healing)**: Nếu một container bị crash hoặc server chứa nó bị lỗi, K8s sẽ tự động phát hiện và khởi chạy lại container đó trên một server khác đang khỏe mạnh mà không cần con người can thiệp.
*   **Cân bằng tải & Phát hiện dịch vụ (Load Balancing & Service Discovery)**: K8s tự động cấp IP riêng cho từng group container (Pod) và tạo ra một Load Balancer nội bộ (Service) để chia đều traffic cho chúng.
*   **Zero-Downtime Deployment (Rolling Updates)**: Khi cập nhật phiên bản mới của ứng dụng, K8s sẽ cập nhật từng container một (lần lượt). Nếu container mới chạy lỗi, nó sẽ tự động rollback về bản cũ, đảm bảo người dùng không bị gián đoạn.

---

## 2. K8s Kind là gì?
*   **Kind** viết tắt của **K**ubernetes **in** **D**ocker.
*   Đây là một công cụ giúp tạo ra cụm Kubernetes cục bộ (local Kubernetes cluster) bằng cách **chạy các node K8s dưới dạng các Docker Container**.
*   **Tại sao lại dùng Kind trong Lab này?**
    *   Thông thường, dựng 1 cụm K8s hoàn chỉnh (production-ready) trên AWS cần dùng dịch vụ managed như EKS (rất đắt tiền, khoảng $70/tháng chỉ riêng Control Plane) hoặc tự dựng bằng `kubeadm` trên nhiều EC2 (cài đặt rất lâu và tốn tài nguyên).
    *   `Kind` cực kỳ **nhẹ** và **nhanh**. Nó cho phép chạy toàn bộ một cụm K8s (gồm cả Control Plane và Worker Node) bên trong duy nhất một container Docker chạy trên 1 con EC2 giá rẻ như `t3.micro`.

---

## 3. Sự khác nhau giữa Provider Kubernetes và K8s (Kubernetes) là gì?
*   **K8s (Kubernetes)**: Là bản thân **hệ thống cluster đang chạy thật** (gồm API server, etcd, scheduler, worker nodes...). Nó chạy trên EC2 để tiếp nhận các ứng dụng (Pod, Service) và giữ cho chúng hoạt động.
*   **Provider Kubernetes (trong Terraform)**: Chỉ là một **plugin (thư viện code)** chạy trên máy local của bạn (nơi bạn gõ lệnh `terraform apply`). Nhiệm vụ của provider này là dịch các block cấu hình dạng HCL của Terraform (ví dụ: `resource "kubernetes_deployment"`) thành các API call chuẩn của Kubernetes (gửi qua HTTP/HTTPS) để ra lệnh cho cụm K8s chạy thật tạo tài nguyên.
*   *Hình dung: K8s là cái TV, còn Provider Kubernetes là chiếc điều khiển từ xa (Remote). Bạn bấm nút trên Remote (Terraform) để điều khiển TV (K8s cluster).*

---

## 4. Vì sao phải cần file `kubeconfig` tồn tại mới kết nối được K8s trên EC2?
*   K8s API Server là một endpoint HTTPS cực kỳ bảo mật. Để có thể điều khiển được nó, bạn bắt buộc phải có chứng chỉ xác thực (Client Certificate, Client Key) và CA của cụm đó.
*   Tất cả các thông tin này (gồm: địa chỉ API Server, CA Certificate, Client Certificate, Client Private Key) được đóng gói chung vào một file cấu hình định dạng YAML gọi là **kubeconfig** (thường nằm ở `~/.kube/config`).
*   Nếu không có file `kubeconfig` này, Provider Kubernetes trên máy local của bạn sẽ không biết:
    1.  Cụm K8s nằm ở địa chỉ IP nào?
    2.  Lấy chứng chỉ bảo mật nào để xác thực quyền Admin với cụm K8s?
*   Do đó, không có `kubeconfig` thì không thể kết nối và ra lệnh deploy app được.

---

## 5. Giải thích vì sao việc dùng file động phụ thuộc trực tiếp vào EC2 Instance lại giải quyết được vấn đề?
### Vấn đề gốc (Bootstrap Problem):
Khi chạy lệnh `terraform plan` trên một repo sạch:
*   EC2 instance chưa được tạo ➔ Chưa có K8s ➔ Chưa có file `kubeconfig`.
*   Nếu cấu hình provider trỏ tới một file cố định không tồn tại (vd: `config_path = "config.yaml"`), Terraform sẽ cố gắng đọc file đó lúc plan, không thấy và sẽ báo lỗi lập tức. Hoặc nếu nó kết nối tới IP cũ, nó sẽ báo lỗi timeout.

### Giải pháp dùng file động:
Trong file [k8s.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/k8s.tf), chúng ta viết:
```hcl
locals {
  kubeconfig_path = "${path.module}/kubeconfig_${aws_instance.k8s_node.id}.yaml"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}
```
*   `aws_instance.k8s_node.id` là một thuộc tính **chỉ biết sau khi tạo xong EC2** (`known after apply`).
*   Do đó, biến `local.kubeconfig_path` cũng trở thành giá trị **chỉ biết sau khi apply**.
*   Khi Terraform thấy cấu hình của provider `kubernetes` phụ thuộc vào một giá trị chưa biết (computed), nó sẽ tự động **trì hoãn toàn bộ quá trình lập kế hoạch (plan) cho các tài nguyên của provider đó** (như Deployment, Service) cho tới khi phase `apply` thực sự chạy và tạo xong EC2.
*   Nhờ vậy, bước `terraform plan` đầu tiên sẽ vượt qua thành công mà không bị báo lỗi thiếu file cấu hình.

---

## 6. `terraform_data.wait_for_k8s` nằm ở đâu và làm gì?
*   **Vị trí**: Nằm trong file [k8s.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/k8s.tf).
*   **Nhiệm vụ**: Nó đóng vai trò là một **chốt chặn (Waiter)**. Khi EC2 vừa được tạo xong, AWS báo trạng thái là "Complete", nhưng thực tế hệ điều hành bên trong EC2 mới bắt đầu boot và chạy script cài đặt Docker/Kind (mất khoảng 2-3 phút).
*   Tài nguyên `terraform_data.wait_for_k8s` sử dụng một `local-exec` provisioner để chạy script PowerShell [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1) trên máy của bạn.
*   Nó sẽ **giữ chân** tiến trình `terraform apply` không cho chạy tiếp xuống các phần K8s, bắt Terraform phải đợi cho tới khi cụm K8s trong EC2 đã khởi động hoàn toàn và file `kubeconfig` đã được tải về máy local thành công.

---

## 7. `user_data` làm gì?
*   **Vị trí**: Nằm trong block khai báo `aws_instance.k8s_node` ở file [main.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/main.tf).
*   **Nhiệm vụ**: Đây là đoạn script Bash chạy tự động ở quyền `root` ngay khi EC2 khởi động lần đầu tiên. Nó làm các nhiệm vụ:
    1.  **Bật 2 GB Swap**: Tăng bộ nhớ ảo cho EC2 t3.micro để tránh lỗi hết RAM khi chạy K8s.
    2.  **Cài đặt Docker**: Nền tảng để chạy container.
    3.  **Cài đặt Kubectl và Kind**: Công cụ quản lý và chạy cụm K8s.
    4.  **Tạo cụm Kind**: Khởi chạy cụm K8s trong container. Cụm này được cấu hình mở cổng API `6443` ra ngoài và đưa IP công cộng của EC2 vào danh sách chứng chỉ an toàn (certSANs).
    5.  **Cấu hình Port Mapping**: Map cổng 80 của EC2 host vào cổng NodePort 30080 của cụm Kind.

---

## 8. `wait_k8s.ps1` làm gì và vì sao cần nó?
*   **Vị trí**: File [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1) trong thư mục lab.
*   **Nhiệm vụ**:
    1.  Nó liên tục thử kết nối SSH vào EC2 instance bằng khóa riêng `k8s-key.pem` mỗi 10 giây.
    2.  Khi kết nối được, nó sẽ chạy lệnh `sudo kind get kubeconfig` bên trong EC2 để lấy nội dung file cấu hình K8s.
    3.  **Thay đổi địa chỉ kết nối**: Nội dung file gốc của Kind trỏ về `127.0.0.1:6443` (local). Script sẽ thay thế nó bằng IP công cộng của EC2 (ví dụ: `44.213.106.127:6443`) để máy của bạn ở nhà có thể kết nối được qua Internet.
    4.  Ghi đè nội dung đó vào file `kubeconfig_<instance_id>.yaml` ở máy local của bạn để cung cấp cho provider `kubernetes`.
*   **Vì sao cần**: Nếu không có script này, Terraform local sẽ không thể lấy được chứng chỉ kết nối động của cụm K8s mới tinh vừa dựng trên AWS.

---

## 9. GIẢI THÍCH LỖI: Vì sao chạy `terraform destroy` bị kẹt ở Internet Gateway (IGW) mười mấy phút không xong?

Đây là một lỗi cực kỳ phổ biến và thú vị khi làm việc với **Multi-Provider** (AWS + K8s) trong cùng một cấu hình Terraform. 

### Nguyên nhân: Bị kẹt Deadlock (Khóa chết chéo) do mất kết nối mạng

Khi bạn chạy `terraform destroy`, Terraform sẽ phân tích đồ thị phụ thuộc để xóa tài nguyên theo thứ tự ngược lại (tài nguyên phụ thuộc xóa trước, tài nguyên gốc xóa sau).

1.  **Về mặt logic K8s**: Để xóa các K8s resource (`kubernetes_deployment.web`), provider `kubernetes` trên máy của bạn **bắt buộc phải kết nối được tới cổng 6443 của EC2** để ra lệnh xóa Pod.
2.  **Về mặt logic AWS**: Để xóa Internet Gateway (IGW) và VPC, toàn bộ các tài nguyên sử dụng mạng (như EC2, ENIs) phải bị hủy hoàn toàn trước.

### Điểm Deadlock xảy ra ở đâu?
*   Do chúng ta không khai báo mối quan hệ phụ thuộc rõ ràng giữa cấu hình mạng AWS (Route Table, Route đi ra Internet Gateway) và các tài nguyên Kubernetes.
*   Khi bạn chạy destroy, Terraform thấy **Route Table / Route** không có phụ thuộc trực tiếp vào K8s Deployment, nên nó tiến hành **xóa các Route đi ra Internet Gateway trước hoặc song song**.
*   **Hậu quả**: Ngay khi Route đi ra Internet bị xóa, con EC2 lập tức **mất kết nối với Internet**. Cổng `6443` và cổng `22` (SSH) của EC2 bị cô lập hoàn toàn.
*   Lúc này, Provider Kubernetes trên máy local cố gắng kết nối tới EC2 để xóa Deployment ➔ **Bị timeout liên tục (treo vô hạn)**.
*   Vì Kubernetes Deployment không thể xóa được ➔ Terraform **không thể tiến hành bước tiếp theo là xóa EC2**.
*   Vì EC2 vẫn đang bật và giữ card mạng (ENI) trong VPC ➔ AWS chặn không cho xóa Internet Gateway (gây ra lỗi `DependencyViolation` và kẹt ở trạng thái `Still destroying...` mười mấy phút).

### Cách xử lý khi bị kẹt:
1.  Nhấn `Ctrl + C` để hủy lệnh `terraform destroy` đang bị treo.
2.  Lên AWS Console (Trình duyệt) ➔ Vào mục **EC2** ➔ Chọn con EC2 `k8s-lab-node` và bấm **Terminate** thủ công để ép nó tắt đi.
3.  Khi EC2 tắt hoàn toàn, card mạng (ENI) sẽ tự động giải phóng.
4.  Lúc này, chạy lại lệnh:
    ```bash
    terraform destroy -auto-approve
    ```
    Terraform sẽ dọn sạch các phần còn lại (VPC, Subnet, IGW) chỉ trong vài giây.
5.  *Giải pháp triệt để trong code*: **(Đã được áp dụng vào code)** Để tránh bị lỗi này, chúng ta đã thêm khai báo `depends_on` vào các tài nguyên Kubernetes (`kubernetes_config_map`, `kubernetes_deployment`, `kubernetes_service`) trỏ trực tiếp đến `aws_route_table_association` và `aws_security_group`. Khi gõ `terraform destroy`, Terraform sẽ biết và bắt buộc phải xóa sạch các tài nguyên Kubernetes trước khi chạm vào hạ tầng mạng AWS, loại bỏ hoàn toàn hiện tượng deadlock.

---

## 10. Giải thích Chi tiết Từng Dòng Code của Tất cả các File

Dưới đây là phần giải nghĩa cặn kẽ từng dòng cấu hình trong các file của Lab này:

### A. File [main.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/main.tf)

#### 1. Cấu hình Terraform & Providers (Dòng 1 - 25)
*   `terraform { required_version = ">= 1.0.0" }`: Yêu cầu phiên bản Terraform tối thiểu là `1.0.0` để đảm bảo tính tương thích của cú pháp.
*   `required_providers { ... }`: Khai báo danh sách các plugin (providers) cần dùng để giao tiếp với các API tương ứng:
    *   `aws`: Cung cấp các tài nguyên trên đám mây AWS.
    *   `kubernetes`: Cung cấp các đối tượng bên trong cụm K8s (Deployment, Service, ConfigMap).
    *   `tls`: Dùng để tạo khóa SSH RSA tự động trên máy local.
    *   `local`: Dùng để ghi đè private key hoặc file cấu hình xuống ổ đĩa cục bộ.
*   `provider "aws" { region = "us-east-1" }`: Thiết lập khu vực AWS mặc định là Bắc Virginia (`us-east-1`).

#### 2. Hạ tầng Mạng VPC & Subnet (Dòng 27 - 88)
*   `resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16" ... }`: Tạo một mạng ảo riêng biệt (VPC) với dải IP từ `10.0.0.0` đến `10.0.255.255`. Bật DNS hostnames và DNS support để các EC2 có thể phân giải tên miền công cộng.
*   `resource "aws_internet_gateway" "igw"`: Tạo cổng Internet Gateway nối vào VPC giúp traffic đi ra/vào từ Internet công cộng.
*   `resource "aws_subnet" "public_a"` và `"public_b"`: Chia VPC thành 2 vùng mạng con công cộng (Public Subnets) ở hai Availability Zone khác nhau (`us-east-1a` và `us-east-1b`). Điều này là bắt buộc vì AWS Application Load Balancer (ALB) yêu cầu phải có tối thiểu 2 Subnets ở 2 AZ khác nhau để đảm bảo High Availability (HA).
*   `resource "aws_route_table" "public"`: Tạo bảng định tuyến định nghĩa luồng đi của traffic. Dòng `route { cidr_block = "0.0.0.0/0"; gateway_id = ... }` chỉ ra rằng tất cả traffic đi ra ngoài Internet sẽ được dẫn qua cổng Internet Gateway (`igw`).
*   `resource "aws_route_table_association"`: Gắn bảng định tuyến công cộng này vào 2 Subnet A và B để biến chúng thành Public Subnet thực sự.

#### 3. IAM Role cho EC2 với SSM Permission (Dòng 89 - 130)
*   `resource "aws_iam_role" "ec2_role"`: Tạo một IAM Role có chính sách Trust Policy cho phép dịch vụ EC2 (`ec2.amazonaws.com`) giả lập (assume) vai trò này.
*   `resource "aws_iam_role_policy" "ssm_policy"`: Gắn kèm một chính sách phân quyền cho Role này, cho phép EC2 ghi (`ssm:PutParameter`), đọc (`ssm:GetParameter`), và xóa (`ssm:DeleteParameter`) tham số cấu hình trong AWS SSM Parameter Store tại đường dẫn `/k8s/*`.
*   `resource "aws_iam_instance_profile" "ec2_profile"`: Đóng gói IAM Role này vào một "Profile" để có thể gắn trực tiếp vào EC2 Instance khi khởi tạo.

#### 4. Security Groups (Dòng 132 - 193)
*   `resource "aws_security_group" "alb_sg"`: Tường lửa cho ALB. Chỉ cho phép cổng `80` (HTTP) đi vào từ bất kỳ đâu (`0.0.0.0/0`) và cho phép tất cả traffic đi ra ngoài.
*   `resource "aws_security_group" "ec2_sg"`: Tường lửa cho EC2 instance.
    *   Cổng `22` (SSH): Mở rộng cho mọi IP (`0.0.0.0/0`) để script local có thể kết nối vào lấy kubeconfig qua giao thức SSH.
    *   Cổng `80` (HTTP): Chỉ cho phép traffic đi vào nếu nó xuất phát từ chính **ALB Security Group** (`security_groups = [aws_security_group.alb_sg.id]`). Điều này ngăn chặn người dùng truy cập trực tiếp vào EC2 mà bắt buộc phải đi vòng qua ALB.
    *   Cổng `6443` (Kubernetes API): Mở rộng cho mọi IP để máy local của bạn ở nhà có thể gọi trực tiếp API điều khiển cụm K8s.

#### 5. Khởi tạo Khóa SSH Tự động (Dòng 195 - 215)
*   `resource "tls_private_key" "k8s_key" { algorithm = "RSA"; rsa_bits = 4096 }`: Tạo một cặp khóa mã hóa RSA độ dài 4096-bit trực tiếp bằng Terraform.
*   `resource "aws_key_pair" "k8s_key"`: Đăng ký khóa công khai (Public Key) vừa tạo lên AWS Key Pair để gán vào EC2 khi tạo.
*   `resource "local_file" "private_key"`: Ghi khóa riêng tư (Private Key) dạng PEM xuống file `k8s-key.pem` ở thư mục hiện tại của máy local.
    *   `provisioner "local-exec"` chạy lệnh Windows `icacls` để thu hồi toàn bộ quyền kế thừa và chỉ cấp quyền Full Control (`F`) cho user hiện tại của bạn (`$env:USERNAME`). Lệnh này là bắt buộc vì SSH client trên Windows/Linux sẽ từ chối kết nối nếu file Private Key có quyền đọc quá rộng rãi (lỗi *Permissions are too open*).

#### 6. Khởi tạo EC2 Instance & User Data Script (Dòng 217 - 316)
*   `data "aws_ami" "ubuntu"`: Tìm kiếm bản cài đặt Ubuntu 22.04 LTS chính chủ mới nhất trên AWS Market để làm OS cho EC2.
*   `resource "aws_instance" "k8s_node"`: Khởi tạo EC2 dòng `t3.micro` gắn các cấu hình Subnet, Security Group, IAM Profile và Key Pair ở trên. Ổ đĩa cứng được tăng lên 20GB gp3 để đủ dung lượng chứa ảnh Docker của cụm K8s.
*   **Chi tiết User Data Script (Chạy tự động khi EC2 khởi động lần đầu):**
    *   `fallocate -l 2G /swapfile ... swapon /swapfile`: Tạo một phân vùng bộ nhớ ảo (swap) dung lượng 2GB trên ổ đĩa và kích hoạt nó. Đây là cấu hình tối quan trọng để EC2 `t3.micro` (vốn chỉ có 1GB RAM vật lý) không bị lỗi tràn RAM và tự động tắt (OOM crash) khi chạy control plane của Kubernetes.
    *   `apt-get install -y docker.io`: Cài đặt Docker Engine và thêm user `ubuntu` vào group `docker` để chạy container không cần sudo.
    *   `curl -LO .../kubectl && mv ./kubectl /usr/local/bin/kubectl`: Tải và cài đặt CLI `kubectl` để quản lý cụm.
    *   `curl -Lo ./kind .../kind-linux-amd64 && mv ./kind /usr/local/bin/kind`: Tải và cài đặt binary của `kind`.
    *   `token=$(curl -s -X PUT ... "http://169.254.169.254/latest/api/token") ...`: Sử dụng dịch vụ EC2 Instance Metadata Service v2 (IMDSv2) để lấy địa chỉ IP công cộng (Public IP) của chính con EC2 đó từ trong OS.
    *   `cat <<KIND_EOF > /tmp/kind-config.yaml`: Tạo file cấu hình khởi động cụm Kind:
        *   `apiServerAddress: 0.0.0.0`: Cho phép Kubernetes API Server lắng nghe trên mọi card mạng của EC2 (thay vì chỉ lắng nghe cục bộ `127.0.0.1`).
        *   `apiServerPort: 6443`: Đặt cổng API của cụm K8s là `6443`.
        *   `certSANs: - "$public_ip"`: Cực kỳ quan trọng. Đưa IP công cộng của EC2 vào danh sách tên miền an toàn của chứng chỉ TLS tự ký do Kind sinh ra. Nếu thiếu dòng này, client local gọi API qua địa chỉ IP công cộng sẽ bị K8s từ chối do lỗi chứng chỉ SSL không khớp.
        *   `extraPortMappings: - containerPort: 30080; hostPort: 80`: Thiết lập Docker port-forwarding: Ánh xạ cổng `80` của máy EC2 vào cổng `30080` (NodePort mặc định của Web Service) bên trong container điều khiển của Kind.
    *   `kind create cluster --config /tmp/kind-config.yaml --wait 5m`: Tiến hành dựng cụm Kubernetes Kind theo cấu hình trên và đợi tối đa 5 phút cho đến khi tất cả các pod hệ thống khởi chạy thành công.
    *   `kind get kubeconfig > /tmp/kubeconfig.yaml ... sed -i ...`: Trích xuất file cấu hình kubeconfig của cụm mới tạo, thay thế địa chỉ endpoint cục bộ `127.0.0.1` thành địa chỉ Public IP thực tế của EC2, sau đó đẩy trực tiếp lên Parameter Store của AWS SSM như một phương án backup bảo mật.

---

### B. File [k8s.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/k8s.tf)

#### 1. Bộ Đồng bộ Waiter (Dòng 1 - 15)
*   `resource "terraform_data" "wait_for_k8s" { depends_on = [aws_instance.k8s_node] }`: Sử dụng resource trung gian của Terraform để tạo một điểm mốc đồng bộ hóa. Nó chỉ bắt đầu chạy khi EC2 instance đã được dựng xong.
*   `provisioner "local-exec"` (khi tạo mới): Chạy script PowerShell [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1) truyền vào tham số Public IP và ID của EC2 instance. Script này giữ nhiệm vụ đợi cụm K8s bên trong EC2 sẵn sàng và kéo file kubeconfig về đĩa máy local.
*   `provisioner "local-exec" { when = destroy }` (khi xóa): Tự động dọn dẹp sạch sẽ các file cấu hình `kubeconfig_*.yaml` tạm thời trên ổ đĩa máy local khi bạn chạy lệnh `terraform destroy`.

#### 2. Cấu hình Dynamic Provider (Dòng 17 - 19)
*   `provider "kubernetes" { config_path = terraform_data.wait_for_k8s.id != "" ? ... : null }`: Khai báo động đường dẫn file cấu hình của Kubernetes Provider. Lập luận `terraform_data.wait_for_k8s.id != ""` bắt buộc Terraform phải chờ đến khi bộ đồng bộ hoàn thành việc tải file kubeconfig về máy rồi mới được phép phân giải đường dẫn này.

#### 3. Kubernetes ConfigMap cho giao diện Web (Dòng 22 - 272)
*   `resource "kubernetes_config_map" "web_html"`: Tạo một ConfigMap trong cụm K8s chứa file `index.html` của trang web. Giao diện được thiết kế hiện đại, responsive bằng CSS thuần (dùng Google Font "Outfit", hiệu ứng Glassmorphic blur nền, Status Badge động dạng pulse, và layout dạng lưới tối giản, cao cấp).
*   `depends_on = [ ..., terraform_data.wait_for_k8s ]`: Buộc ConfigMap này chỉ được tạo sau khi cụm K8s đã sẵn sàng và hạ tầng mạng đã được liên kết đầy đủ.

#### 4. Kubernetes Deployment & Service (Dòng 275 - 370)
*   `resource "kubernetes_deployment" "web"`: Triển khai ứng dụng Nginx lên cụm K8s.
    *   `replicas = 2`: Tạo 2 Pods chạy song song để đảm bảo tính chịu lỗi.
    *   `limits` & `requests`: Đặt giới hạn tối đa tài nguyên cho mỗi Pod (64MB RAM, 100m CPU) và mức yêu cầu tối thiểu (32MB RAM, 50m CPU) để kiểm soát tài nguyên tránh gây crash cho node EC2 t3.micro yếu.
    *   `volume` & `volume_mount`: Ánh xạ thư mục mặc định của Nginx `/usr/share/nginx/html` tới dữ liệu file `index.html` được định nghĩa trong `kubernetes_config_map.web_html.metadata[0].name`.
*   `resource "kubernetes_service" "web"`: Tạo một Service K8s phân phối traffic đến các Pod.
    *   `type = "NodePort"`: Cấu hình mở cổng NodePort ra host máy chủ.
    *   `node_port = 30080`: Mở cổng cứng `30080` trên node. Đây chính là cổng mà chúng ta đã map ra cổng `80` của EC2 host trong file cấu hình Kind ở bước trước.

---

### C. File [alb.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/alb.tf)

*   `resource "aws_lb" "main"`: Tạo một Application Load Balancer (ALB) dạng public (`internal = false`) nằm trên cả 2 Subnet A và B, sử dụng Security Group `alb_sg` để kiểm soát truy cập từ Internet.
*   `resource "aws_lb_target_group" "main"`: Định nghĩa Target Group hướng traffic đến cổng `80` của các thực thể đích (Target Type là `instance`).
    *   `health_check`: Cấu hình hệ thống tự động kiểm tra trạng thái sức khỏe của EC2 định kỳ mỗi 15 giây qua cổng `80`. Nếu EC2 không phản hồi quá 3 lần liên tiếp, ALB sẽ ngừng chuyển traffic tới nó.
*   `resource "aws_lb_listener" "http"`: Tạo Listener lắng nghe cổng `80` công cộng của ALB và chuyển hướng (forward) toàn bộ traffic vào Target Group.
*   `resource "aws_lb_target_group_attachment" "k8s_node"`: Gắn trực tiếp EC2 Instance `k8s_node` vào Target Group trên cổng `80`.

---

### D. File [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1)

*   `param ($ip, $instanceId)`: Nhận vào tham số IP công cộng và ID của EC2 instance.
*   `$keyPath = Join-Path $PSScriptRoot "k8s-key.pem"`: Xác định đường dẫn file khóa SSH riêng tư vừa ghi xuống đĩa máy local.
*   `for ($i=0; $i -lt 60; $i++) { ... }`: Vòng lặp thăm dò (polling loop) tối đa 60 lần, mỗi lần cách nhau 10 giây (tương đương 10 phút chờ tối đa).
*   `ssh -i $keyPath -o StrictHostKeyChecking=no ... "sudo kubectl --kubeconfig /tmp/kubeconfig.yaml get nodes"`: Kết nối SSH vào EC2 và thực hiện lệnh kiểm tra xem API server của cụm K8s Kind đã khởi động và nhận diện các node hay chưa. Tùy chọn `-o StrictHostKeyChecking=no` giúp bỏ qua cảnh báo bảo mật vân tay của host mới tạo.
*   `if ($LASTEXITCODE -eq 0)`: Nếu lệnh trên chạy thành công không có lỗi, chứng tỏ cụm K8s đã hoạt động.
*   `$val = ssh ... "sudo kind get kubeconfig"`: Chạy lệnh lấy nội dung file cấu hình Kubeconfig của Kind.
*   `$val -replace "server: https://127.0.0.1:6443", ...`: Thay thế địa chỉ máy chủ cục bộ trong file cấu hình thành địa chỉ IP công cộng của EC2 (`https://<public_ip>:6443`). Điều này là bắt buộc vì máy local của bạn nằm ở nhà, bên ngoài mạng AWS, không thể kết nối tới loopback `127.0.0.1` của EC2 được.
*   `$val | Out-File -FilePath $outputPath -Encoding utf8`: Lưu file cấu hình đã sửa đổi xuống máy local dưới tên file động `kubeconfig_<instance_id>.yaml` với chuẩn mã hóa UTF-8.

---

### E. File [outputs.tf](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/outputs.tf)

*   `output "alb_dns_name"`: Trả về link HTTP trỏ tới tên miền DNS công cộng của Application Load Balancer để người dùng nhấp trực tiếp vào trình duyệt sau khi deploy.
*   `output "ec2_public_ip"`: Trả về địa chỉ IP công cộng của EC2 chứa cụm để tiện cho việc kiểm tra hoặc debug thủ công.

---

## 11. Phân tích Lý do Lựa chọn Công nghệ & So sánh với Giải pháp Thay thế

### A. Tại sao chọn `kind` thay vì `minikube` hay các giải pháp K8s khác trên EC2?

| Tiêu chí so sánh | Kubernetes in Docker (`kind`) (Được chọn) | Minikube | K3s (Rancher) | AWS EKS (Managed Service) |
| :--- | :--- | :--- | :--- | :--- |
| **Bản chất hoạt động** | Chạy các node dưới dạng container Docker trên Host OS. | Hỗ trợ nhiều driver ảo hóa (VirtualBox, KVM, Docker). | Bản phân phối rút gọn chạy trực tiếp như Systemd Service. | Dịch vụ Kubernetes do AWS quản lý hoàn toàn. |
| **Yêu cầu tài nguyên** | Cực kỳ nhẹ. Chạy mượt mà trên EC2 dòng rẻ tiền nhất (`t3.micro` - 1 CPU, 1GB RAM + 2GB Swap). | Nặng hơn. Docker driver trên EC2 đòi hỏi tối thiểu `t2.medium` (4GB RAM) để chạy ổn định. | Khá nhẹ nhưng cài đặt trực tiếp, làm thay đổi cấu hình mạng và iptables của EC2 host. | Cực kỳ nặng. Control plane tách riêng, worker node phải từ `t3.medium` trở lên. |
| **Độ cô lập môi trường** | **Tuyệt đối**. Toàn bộ cụm K8s nằm gọn trong 1 Docker container. Xóa container là sạch Host OS. | Tương đối. Phụ thuộc vào Docker driver hoặc máy ảo, dọn dẹp khó sạch hoàn toàn. | **Kém**. Cài đặt cắm sâu vào hệ điều hành host, để lại nhiều file rác và tiến trình ngầm khi gỡ bỏ. | Tuyệt đối (nằm trên hạ tầng dịch vụ của AWS). |
| **Port Mapping ra ngoài** | Hỗ trợ khai báo cổng tĩnh `extraPortMappings` cực kỳ tường minh ngay lúc dựng cụm. | Phải chạy lệnh phụ `minikube tunnel` hoặc port-forward thủ công để expose cổng. | Phải cấu hình Traefik Ingress Controller hoặc NodePort thủ công và phức tạp hơn. | Sử dụng AWS Load Balancer Controller tích hợp (rất phức tạp và tốn nhiều bước cấu hình IAM). |
| **Chi phí hạ tầng** | **~$0** (Nằm hoàn toàn trong gói AWS Free Tier với `t3.micro`). | **~$15 - $20/tháng** (Bắt buộc dùng EC2 lớn hơn). | **~$0** (Chạy được trên `t3.micro`). | **~$70 - $150/tháng** ($72 phí quản lý cụm + phí EC2 lớn làm worker). |

**Kết luận**: `kind` là lựa chọn tối ưu nhất cho bài Lab tự động hóa 1-Click vì nó đảm bảo 3 tiêu chí: **Chi phí rẻ nhất** (Free Tier), **Môi trường sạch sẽ nhất** (dễ dọn dẹp), và **Cấu hình mạng tường minh nhất** thông qua port-mapping trực tiếp từ cấu hình YAML.

---

### B. Tại sao lại dùng K8s (Kubernetes) thay vì chỉ chạy VM thuần hoặc Docker-compose?

Mục tiêu của bài lab là xây dựng một hệ thống **Cloud-Native chuẩn Production** thu nhỏ. Việc sử dụng K8s mang lại các bài học thực tiễn mà VM thuần hay Docker-compose không thể cung cấp:
1.  **Cơ chế Self-Healing (Tự phục hồi)**: Trong cụm K8s, nếu một pod Nginx bị crash do lỗi ứng dụng, K8s Control Plane sẽ tự động phát hiện và tạo lại Pod mới thay thế chỉ trong vài giây. VM thuần hoặc Docker-compose đơn lẻ không có khả năng tự động quản lý vòng đời này nếu không viết script giám sát phức tạp bên ngoài.
2.  **Mount cấu hình động (ConfigMap)**: K8s cho phép quản trị viên tách biệt mã nguồn ứng dụng (Nginx image) và cấu hình tĩnh (file `index.html`) thông qua `ConfigMap`. File HTML có thể cập nhật trực tiếp trên API K8s và tự động sync vào Pods mà không cần phải build lại Docker Image hay khởi động lại Container.
3.  **Học tập thực tiễn (Ready for Production)**: Toàn bộ cấu trúc định nghĩa Deployment, Service, ReplicaSets, Liveness/Readiness Probes trong bài lab này được viết theo chuẩn K8s toàn cầu. Khi chuyển đổi dự án lên môi trường production lớn chạy trên AWS EKS hay Google GKE, bạn chỉ cần mang nguyên các file tài nguyên này đi sử dụng mà không cần thay đổi logic.

---

### C. Tại sao sử dụng script local [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1) thay vì các cơ chế khác?

Nhiều người sẽ đặt câu hỏi: *Tại sao không dùng các cơ chế sẵn có của Terraform hoặc AWS?*

1.  **Tại sao không dùng Provisioner `remote-exec` của Terraform để lấy cấu hình?**
    *   *Hạn chế*: `remote-exec` hoạt động bằng cách cố gắng kết nối SSH vào EC2 ngay khi cổng SSH (`22`) vừa mở. Tuy nhiên, tại thời điểm EC2 vừa mở cổng 22, hệ điều hành Ubuntu bên trong mới chỉ bắt đầu khởi động và bắt đầu chạy script `user_data` (quá trình cài đặt Docker, Kind và tạo cụm K8s mất từ 2-3 phút).
    *   Nếu ta dùng `remote-exec` chạy các lệnh `kubectl` hay `kind`, nó sẽ chạy ngay lập tức và **báo lỗi đỏ lập tức do công cụ chưa được cài xong**, làm gãy luồng `terraform apply`.
    *   Provisioner `remote-exec` mặc định không hỗ trợ vòng lặp thử lại thông minh (custom polling) và không thể tự tải file từ máy ảo về máy local của bạn.
2.  **Tại sao không dùng AWS SSM Parameter Store làm Data Source trực tiếp trong Terraform?**
    *   *Hạn chế*: Terraform hoạt động theo nguyên lý "Read-first" đối với các Data Source. Tại thời điểm chạy `plan` hoặc bắt đầu `apply`, data source `aws_ssm_parameter` sẽ cố gắng đọc giá trị tại `/k8s/kubeconfig`.
    *   Do cụm K8s chưa được tạo, tham số này chưa hề tồn tại trên AWS Parameter Store. Terraform sẽ ném ra lỗi `ParameterNotFound` và dừng tiến trình. Terraform không có cơ chế tự động "chờ đợi và liên tục kiểm tra" cho đến khi tham số đó xuất hiện.
3.  **Ưu thế của [wait_k8s.ps1](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w8/lab/wait_k8s.ps1)**:
    *   Script PowerShell chạy ở môi trường local của bạn, đóng vai trò như một **vòng lặp kiểm tra trạng thái độc lập (Health-Check Loop)**. Nó chỉ lấy file kubeconfig khi và chỉ khi cụm K8s bên trong EC2 báo trạng thái "hoàn toàn khỏe mạnh" (`kubectl get nodes` trả về mã thoát `0`).
    *   Nó thực hiện xử lý logic chuỗi (string replacement) cực kỳ nhanh chóng để thay đổi địa chỉ IP cục bộ sang IP công cộng trước khi lưu thành file vật lý cấp cho Kubernetes provider.

---

### D. Tại sao dùng cơ chế Dynamic Provider Configuration & Orchestrated Bootstrapping thay vì các giải pháp khác?

Để giải quyết bài toán cài đặt K8s lên hạ tầng vừa tạo trong một lần chạy duy nhất, có một số hướng đi khác nhưng đều có nhược điểm lớn:

1.  **Giải pháp chạy 2 giai đoạn thủ công (Multi-stage apply)**:
    *   *Cách làm*: Người dùng chạy `terraform apply` lần một để dựng VPC và EC2. Đợi EC2 cài xong, người dùng tự SSH vào EC2 lấy file kubeconfig, lưu về máy local dưới tên cố định. Sau đó mới uncomment code định nghĩa Deployment/Service K8s và chạy `terraform apply` lần hai.
    *   *Nhược điểm*: Phá vỡ hoàn toàn triết lý **1-Click Automation**. Gây bất khả thi nếu muốn tích hợp vào các đường ống CI/CD tự động (như Github Actions, GitLab CI) vốn yêu cầu chạy không có tương tác người dùng.
2.  **Giải pháp dùng Wrapper Script bên ngoài (Shell/Python wrapper hoặc Terragrunt)**:
    *   *Cách làm*: Viết một file script Python bọc ngoài. Script này sẽ chạy `terraform apply -target=aws_instance...` trước, sau đó tự chạy lệnh SSH kéo file config về, rồi mới chạy lệnh `terraform apply` cho toàn bộ tài nguyên còn lại.
    *   *Nhược điểm*: Khiến dự án phụ thuộc vào các công cụ bọc ngoài, làm tăng độ phức tạp khi phân phối mã nguồn (người dùng phải cài đặt thêm Python, cấu hình thư viện SSH, cài Terragrunt...). Nó cũng làm mất đi khả năng quản lý trạng thái đồng nhất của file state.
3.  **Tại sao cơ chế hiện tại là tối ưu nhất?**
    *   Nó tích hợp toàn bộ luồng xử lý và mối liên hệ phụ thuộc trực tiếp vào **đồ thị tài nguyên (Dependency Graph)** của Terraform Core.
    *   Tận dụng trạng thái "chưa xác định" (`known after apply`) của thuộc tính ID EC2 để báo cho Terraform tự động lập lịch trì hoãn cho Kubernetes provider một cách tự nhiên và chính thống nhất.
    *   Đảm bảo trải nghiệm người dùng hoàn hảo: chỉ gõ đúng một lệnh duy nhất và nhận về kết quả cuối cùng.
