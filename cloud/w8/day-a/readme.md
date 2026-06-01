Terraform là gì
Theo tài liệu HashiCorp, Terraform là "một công cụ infrastructure as code cho phép bạn định nghĩa tài nguyên cloud và on-prem trong các file cấu hình con người đọc được, có thể version, tái sử dụng và chia sẻ"

Provider là plugin giúp Terraform nói chuyện với một nền tảng cụ thể. hashicorp/aws biết cách gọi API của AWS; có provider cho Google Cloud, Azure, Cloudflare, GitHub, Kubernetes trên Terraform Registry.

Resource là một mẩu hạ tầng bạn khai báo: một aws_instance, một aws_s3_bucket, một aws_security_group. Đây là đơn vị Terraform quản lý.

State là file Terraform dùng để nhớ "thực tế đang có gì". Tài liệu mô tả nó là "nguồn sự thật cho môi trường của bạn" — Terraform đối chiếu file cấu hình với state để biết cần thay đổi gì.

Vòng đời: write, plan, apply
Write — bạn định nghĩa resource trong file .tf, có thể trải trên nhiều provider.
Plan — Terraform tạo một execution plan, mô tả nó sẽ tạo, sửa hay xóa cái gì, dựa trên hiện trạng và cấu hình của bạn, chưa có gì thay đổi thật, bạn đọc kế hoạch và quyết định.
Apply — sau khi bạn duyệt, Terraform thực hiện các thao tác đó "theo đúng thứ tự, tôn trọng mọi quan hệ phụ thuộc giữa resource".
Cộng thêm destroy để dỡ bỏ những gì đã tạo

                terraform plan / apply
                         │
          ┌──────────────▼───────────────┐
          │       Terraform Core          │  đọc *.tf  +  terraform.tfstate
          │  - dựng đồ thị phụ thuộc      │  so cấu hình ⟷ state ⟷ thực tế
          │  - tính diff (kế hoạch)       │  quyết định tạo/sửa/xóa cái gì
          └──────────────┬───────────────┘
                         │  gRPC (go-plugin, chạy local)
          ┌──────────────▼───────────────┐
          │     Provider plugin           │  vd hashicorp/aws 6.46.0
          │  - biết schema từng resource  │  tải về .terraform/ khi init
          │  - dịch sang lời gọi API      │
          └──────────────┬───────────────┘
                         │  HTTPS (AWS SDK, có ký SigV4)
          ┌──────────────▼───────────────┐
          │          AWS API              │  EC2, S3, IAM, ...
          └───────────────────────────────┘

   terraform.tfstate  ◄─ Core ghi lại id thật + thuộc tính của mọi resource


Terraform core là cái binary bạn cài. Nó đọc file .tf, dựng đồ thị các resource và quan hệ giữa chúng, đối chiếu với state, rồi tính ra kế hoạch.
Provider là binary riêng, tải về lúc terraform init và nằm trong thư mục .terraform/. Nó khai báo schema (resource aws_instance có những trường nào, kiểu gì, trường nào bắt buộc) và biết cách dịch "tạo resource này" thành lời gọi API thật. 

Trên Ubuntu/Debian, thêm apt repo chính thức:
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
Main commands:
  init          Prepare your working directory for other commands
  validate      Check whether the configuration is valid
  plan          Show changes required by the current configuration
  apply         Create or update infrastructure
  destroy       Destroy previously-created infrastructure
Một mẹo nhỏ đáng làm ngay: bật autocomplete cho shell, gõ terraform rồi Tab sẽ gợi ý lệnh.
terraform -install-autocomplete


terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply -auto-approve
terraform state list--> Lưu ý quan trọng: file này chứa mọi thuộc tính của resource, kể cả các giá trị nhạy cảm (mật khẩu RDS, private key) ở dạng plaintext. Đó là lý do nó tuyệt đối không được commit vào git, 
$ aws s3api head-bucket --bucket tf-series-bai2-20260525025042897800000001 --> kiem tra doc lap
terraform destroy -auto-approve

Terraform co tính chất idempotent của mô hình khai báo. Chạy plan lần nữa mà không sửa gì. Terraform không tạo bucket thứ hai

terraform console --> mở một prompt tương tác, gõ biểu thức HCL vào là nó in kết quả
$ echo 'upper("hello")' | terraform console
"HELLO"
$ echo '5 + 3 * 2' | terraform console
11


khác biệt list-với-tuple và map-với-object nằm ở chỗ phần tử có cùng kiểu hay không: list/map đòi mọi phần tử cùng kiểu, còn tuple/object cho phép mỗi vị trí một kiểu. Lúc viết cấu hình bạn cứ gõ [...] và {...}, Terraform tự suy ra kiểu cụ thể;
$ echo '{ name = "web", port = 443 }' | terraform console
{
  "name" = "web"
  "port" = 443
}

Tomt tat HCL
HCL chỉ có hai khối: argument (tên = biểu_thức) và block (type, label, body). Sáu kiểu giá trị là string, number, bool, list/tuple, map/object, null, trong đó null nghĩa là "bỏ qua argument". Biểu thức ghép giá trị qua toán tử, ternary, nội suy ${...} và hàm dựng sẵn, và terraform console là chỗ thử chúng nhanh nhất. Block terraform{} khai báo về môi trường chạy: phiên bản, provider, backend. Thứ tự dòng không quan trọng vì Terraform dựng đồ thị từ tham chiếu chứ không chạy tuần tự.