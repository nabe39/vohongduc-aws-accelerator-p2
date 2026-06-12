# 📄 Giải thích Code: [analysis.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/analysis.yaml)

File manifest này định nghĩa tài nguyên **AnalysisTemplate** của Argo Rollouts. Đây là bộ khung kiểm tra chất lượng tự động, truy vấn dữ liệu từ Prometheus để đưa ra quyết định tiếp tục phát hành hay hủy bỏ (abort) bản deploy mới.

---

## 1. Nội dung Code

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: api-success-rate
  namespace: demo
spec:
  metrics:
  - name: success-rate
    interval: 30s
    successCondition: len(result) == 0 || result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
        query: |
          (
            sum(rate(flask_http_request_total{status!~"5..", namespace="demo", service="api"}[2m]))
            /
            sum(rate(flask_http_request_total{namespace="demo", service="api"}[2m]))
          ) or on() vector(1)
```

---

## 2. Giải thích chi tiết các thành phần

### 2.1 Cấu hình chu kỳ và điều kiện đánh giá
*   `kind: AnalysisTemplate`: Tài nguyên mở rộng của Argo Rollouts dùng làm khuôn mẫu phân tích chất lượng.
*   `metrics.name: success-rate`: Đặt tên chỉ số phân tích này là `success-rate` (tỉ lệ thành công).
*   `interval: 30s`: Tần suất chạy truy vấn metric. Cứ mỗi **30 giây** trong thời gian diễn ra Canary Rollout, bộ điều khiển sẽ gửi một câu lệnh PromQL đến Prometheus để đo lại giá trị.
*   `successCondition: len(result) == 0 || result[0] >= 0.95`: Điều kiện để coi là một lần kiểm tra thành công (Pass).
    *   `len(result) == 0`: Khi hệ thống hoàn toàn rảnh rỗi không có traffic, Prometheus sẽ trả về kết quả là một mảng rỗng. Điều kiện này giúp chấp nhận trạng thái rảnh rỗi là thành công, tránh lỗi so sánh kiểu dữ liệu khi so sánh mảng rỗng với số.
    *   `result[0] >= 0.95`: Kết quả đo được (phần tử đầu tiên trong mảng kết quả của Prometheus) phải lớn hơn hoặc bằng **0.95** (tương đương tỷ lệ thành công tối thiểu 95%).
*   `failureLimit: 3`: Giới hạn số lần kiểm tra thất bại tối đa được phép. Nếu có **3 lần kiểm tra liên tiếp** bị đánh giá là lỗi (Success Rate < 95%), hệ thống sẽ chấm dứt Rollout và kích hoạt cơ chế Rollback ngay lập tức.

### 2.2 Cấu hình kết nối Prometheus Provider
*   `address: http://kube-prometheus-stack-prometheus.monitoring.svc:9090`: Địa chỉ DNS nội bộ trong Kubernetes để kết nối tới Prometheus Server:
    *   `kube-prometheus-stack-prometheus`: Tên Service của Prometheus Server.
    *   `monitoring.svc`: Tên namespace của Service này (`monitoring`).
    *   `9090`: Cổng hoạt động mặc định của Prometheus.

### 2.3 Giải thích chi tiết Câu lệnh PromQL
```promql
(
  sum(rate(flask_http_request_total{status!~"5..", namespace="demo", service="api"}[2m]))
  /
  sum(rate(flask_http_request_total{namespace="demo", service="api"}[2m]))
) or on() vector(1)
```
*   `flask_http_request_total`: Metric ghi nhận tổng số HTTP requests đi vào ứng dụng Flask (do thư viện `prometheus_flask_exporter` xuất ra).
*   `status!~"5.."`: Sử dụng Regex để loại bỏ tất cả các request có status code dạng `5xx` (mã lỗi server như 500, 503...). Điều này có nghĩa chỉ đếm các request thành công (2xx, 3xx) hoặc lỗi của client (4xx, vì lỗi 4xx do người dùng nhập sai, không phản ánh lỗi hệ thống ứng dụng).
*   `rate(...[2m])`: Tính toán tốc độ trung bình của request mỗi giây trong khoảng thời gian **2 phút** gần nhất. Việc dùng cửa sổ ngắn 2 phút giúp hệ thống phản ứng cực nhạy với lỗi mới xuất hiện.
*   `sum(...)`: Cộng gộp số liệu từ tất cả các Pods chạy dịch vụ api trong namespace `demo`.
*   Phép chia `/`: Lấy tổng request không bị lỗi 5xx chia cho tổng số lượng request để tính ra Tỷ lệ thành công (Success Rate).
*   `or on() vector(1)`: Đề phòng trường hợp rảnh rỗi không có traffic, phép chia sẽ bị lỗi chia cho 0 (hoặc kết quả vector rỗng). Cú pháp này trả về giá trị mặc định là `1` (100% thành công) khi hệ thống không có traffic.
