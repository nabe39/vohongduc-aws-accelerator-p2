# 📄 Giải thích Code: [prom-rules.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/prom-rules.yaml)

File manifest này định nghĩa cấu hình **PrometheusRule** để thiết lập cảnh báo vi phạm cam kết chất lượng dịch vụ (SLO) cho API. Nó được Prometheus Operator tự động quét và nạp cấu hình chạy động.

---

## 1. Nội dung Code

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: api-slo-alerts
  namespace: demo
  labels:
    release: kube-prometheus-stack
spec:
  groups:
  - name: api-slo
    rules:
    - alert: ApiLowSuccessRateSLO
      expr: |
        (
          sum(rate(flask_http_request_total{status!~"5..", namespace="demo", service="api"}[5m]))
          /
          (sum(rate(flask_http_request_total{namespace="demo", service="api"}[5m])) or on() vector(1))
        ) < 0.95
      for: 0s
      labels:
        severity: critical
      annotations:
        summary: "API low success rate (below 95% SLO)"
        description: "Tỉ lệ thành công của api giảm dưới 95% trong 2 phút liên tiếp. Giá trị hiện tại: {{ $value }}."
```

---

## 2. Giải thích chi tiết cấu hình và biểu thức

### 2.1 Metadata và Nhãn lọc
*   `kind: PrometheusRule`: Custom Resource Definition (CRD) của Prometheus Operator dùng để định nghĩa các luật cảnh báo (Alerting Rules) hoặc luật gom nhóm (Recording Rules).
*   `labels.release: kube-prometheus-stack`: **Nhãn bắt buộc.** Chỉ có các PrometheusRule có gắn đúng nhãn release của Helm chart mới được Prometheus Operator quét thấy và nạp tự động vào Prometheus Server.

### 2.2 Quy tắc cảnh báo (`rules`)
*   `alert: ApiLowSuccessRateSLO`: Tên của cảnh báo được tạo ra.
*   `expr`: Biểu thức truy vấn PromQL đo đạc SLO.
    *   `flask_http_request_total{status!~"5..", namespace="demo", service="api"}[5m]`: Đếm tổng số request thành công (không lỗi 5xx) trong cửa sổ trượt **5 phút**. Dùng cửa sổ 5 phút giúp mượt hóa biểu đồ, tránh các lỗi kết nối nhất thời gây cảnh báo ảo (False Alarms).
    *   `/ (sum(...) or on() vector(1))`: Phép chia tính tỉ lệ thành công. Việc bọc thêm vế `or on() vector(1)` đảm bảo khi hệ thống không có traffic, phép chia vẫn trả về giá trị `1` (100% thành công) thay vì trả về vector rỗng làm treo cảnh báo.
    *   `< 0.95`: Ngưỡng kích hoạt cảnh báo. Cảnh báo sẽ nổ ra khi Tỉ lệ thành công trung bình của dịch vụ giảm dưới **95%** trong cửa sổ 5 phút.
*   `for: 0s`: Thời gian chờ tối thiểu từ khi biểu thức vi phạm cho đến khi phát cảnh báo. Đặt `0s` nghĩa là ngay khi cửa sổ 5 phút có trung bình success rate < 95%, Alertmanager sẽ lập tức nhận lỗi và gửi email ngay, không chờ đợi thêm trạng thái pending.
*   `labels.severity: critical`: Nhãn độ nghiêm trọng của lỗi là `critical` (cấp bách). Nhãn này có thể dùng để lọc và cấu hình nhạc chuông/tin nhắn khẩn cấp trong Alertmanager.
*   `annotations`: Chứa nội dung hiển thị trong email.
    *   `{{ $value }}`: Biến động tự động điền giá trị thực tế của Tỷ lệ thành công đo được tại thời điểm nổ cảnh báo vào email (ví dụ: `0.0` hoặc `0.85`).
