```markdown
# Hướng Dẫn Lab: Giám Sát Hệ Thống Với Prometheus Và Node Exporter

Tài liệu này hướng dẫn cách thiết lập một hệ thống giám sát (Monitoring) cơ bản trên môi trường local bằng cách sử dụng **Node Exporter** để thu thập chỉ số phần cứng và **Prometheus** để kéo (pull) và lưu trữ dữ liệu.

---

## 1. Kiến Trúc Hoạt Động (Cơ Chế Pull)

Hệ thống vận hành theo mô hình **Pull-based**:
1. **Node Exporter** chạy ngầm, liên tục đọc các thông số hệ điều hành và tiếp lộ (expose) dữ liệu thô tại cổng `9100`.
2. **Prometheus** đóng vai trò máy chủ trung tâm, định kỳ gửi request HTTP đến Node Exporter để kéo toàn bộ chỉ số về lưu trữ.

---

## 2. Các Bước Triển Khai Lab

### Bước 1: Khởi động Node Exporter
Di chuyển vào thư mục Node Exporter đã tải về và kích hoạt công cụ:
```bash
cd ~/node_exporter-1.10.2.linux-amd64
./node_exporter

```

*Kiểm tra kết quả:* Truy cập `http://localhost:9100/metrics` trên trình duyệt để đảm bảo dữ liệu thô đang được xuất ra thành công.

### Bước 2: Cài đặt và cấu hình Prometheus

Mở một tab terminal mới, thực hiện tải bản phân phối chính thức của Prometheus:

```bash
cd ~
wget [https://github.com/prometheus/prometheus/releases/download/v2.53.1/prometheus-2.53.1.linux-amd64.tar.gz](https://github.com/prometheus/prometheus/releases/download/v2.53.1/prometheus-2.53.1.linux-amd64.tar.gz)
tar xvf prometheus-2.53.1.linux-amd64.tar.gz
cd prometheus-2.53.1.linux-amd64

```

Sử dụng lệnh `nano prometheus.yml` để cấu hình file. Đảm bảo file sử dụng khoảng trắng (spaces) để thụt lề theo đúng định dạng YAML:

```yaml
global:
  scrape_interval: 15s # Chu kỳ kéo dữ liệu (15 giây/lần)

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "my_node_exporter"
    static_configs:
      - targets: ["localhost:9100"] # Endpoint của Node Exporter

```

### Bước 3: Khởi động Prometheus Server

Tại thư mục Prometheus, chạy lệnh sau để chạy dịch vụ kèm file cấu hình vừa tạo:

```bash
./prometheus --config.file=prometheus.yml

```

### Bước 4: Kiểm tra trên giao diện Web UI

1. Truy cập giao diện Prometheus tại: `http://localhost:9090`
2. Kiểm tra trạng thái kết nối: Chọn **Status** -> **Targets** (Đảm bảo endpoint `localhost:9100` hiển thị màu xanh **UP**).
3. Truy vấn biểu đồ: Vào mục **Graph**, gõ biểu thức `node_memory_Active_bytes` và nhấn **Execute** để theo dõi lượng RAM tiêu thụ biến động theo thời gian thực.

---

## 3. Quy Trình Dọn Dẹp Tài Nguyên (Clean Up)

Sau khi hoàn thành bài lab, để tránh việc các tiến trình chạy ngầm làm tiêu tốn tài nguyên máy (CPU/RAM) và dọn dẹp các tệp tin rác, hãy thực hiện theo các bước sau:

### Bước 1: Tắt các tiến trình đang chạy (Stop Services)

Tại các tab terminal đang chạy Prometheus và Node Exporter, hãy nhấn tổ hợp phím:

* **`Ctrl + C`** để dừng trực tiếp tiến trình.

*Mẹo: Nếu dịch vụ bị chạy ẩn (chạy ngầm bằng nohup hoặc &), hãy tìm và tắt chúng bằng lệnh:*

```bash
killall prometheus
killall node_exporter

```

### Bước 2: Xóa bỏ các thư mục và file cài đặt không cần thiết

Nếu không muốn lưu trữ các bộ mã nguồn và dữ liệu log đã quét (nằm trong thư mục `data` của Prometheus), chạy lệnh sau để xóa sạch:

```bash
cd ~
# Xóa thư mục và file lưu trữ của Node Exporter
rm -rf node_exporter-1.10.2.linux-amd64*

# Xóa thư mục và file lưu trữ của Prometheus (bao gồm cả database test)
rm -rf prometheus-2.53.1.linux-amd64*

```

Hệ thống máy tính của bạn hiện tại đã được dọn dẹp hoàn toàn sạch sẽ về trạng thái ban đầu.
