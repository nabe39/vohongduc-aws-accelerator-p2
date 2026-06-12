# 📄 Giải thích Code: [app.py](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/app/app.py)

File mã nguồn Python này định nghĩa ứng dụng Flask cung cấp API, hỗ trợ cơ chế giả lập lỗi (Error Injection) để phục vụ việc kiểm thử khả năng rollback tự động của Canary Rollout.

---

## 1. Nội dung Code

```python
import os, random
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
PrometheusMetrics(app)            # tự thêm /metrics

ERR = float(os.getenv("ERROR_RATE", "0"))
VER = os.getenv("VERSION", "v1")

@app.get("/")
def index():
    if random.random() < ERR:
        return jsonify(error="injected", version=VER), 500
    return jsonify(ok=True, version=VER)

@app.get("/healthz")
def healthz(): return "ok", 200
```

---

## 2. Giải thích chi tiết mã nguồn

### 2.1 Cài đặt và tích hợp Exporter
*   `PrometheusMetrics(app)`: Dòng này tích hợp thư viện xuất metrics của Prometheus vào Flask. Nó tự động:
    *   Tạo endpoint `/metrics` trên ứng dụng Flask để phơi bày dữ liệu đo lường.
    *   Theo dõi và thu thập tự động các metric hệ thống quan trọng như `flask_http_request_total` (tổng request), `flask_http_request_duration_seconds` (thời gian phản hồi) cùng các nhãn chi tiết như `status` (mã HTTP code), `method` (GET, POST), và `endpoint` (đường dẫn URL).

### 2.2 Đọc tham số cấu hình
*   `ERR = float(os.getenv("ERROR_RATE", "0"))`: Đọc biến môi trường `ERROR_RATE` (mặc định là `0` - không lỗi). Giá trị này nằm trong khoảng từ `0.0` (0% lỗi) đến `1.0` (100% lỗi) để mô phỏng tỷ lệ lỗi trả về của hệ thống.
*   `VER = os.getenv("VERSION", "v1")`: Đọc phiên bản của ứng dụng từ biến môi trường `VERSION` (mặc định là `"v1"`). Giúp phân biệt phản hồi đang đến từ bản deploy cũ hay bản mới.

### 2.3 Định nghĩa các Routes (API Endpoints)
*   `@app.get("/")`: Endpoint chính tiếp nhận traffic.
    *   `random.random() < ERR`: Sinh ra một số ngẫu nhiên từ `0` đến `1`. Nếu số này nhỏ hơn tỉ lệ lỗi mong muốn (`ERR`), ứng dụng lập tức trả về mã HTTP `500 Internal Server Error` với thông báo lỗi `"injected"`.
    *   Nếu không lỗi, ứng dụng trả về mã HTTP `200 OK` cùng JSON chứa trạng thái thành công và phiên bản ứng dụng hiện tại (`VER`).
*   `@app.get("/healthz")`: Endpoint kiểm tra sức khỏe của container.
    *   Luôn trả về chuỗi `"ok"` với HTTP code `200 OK` để thông báo cho Kubernetes biết container này vẫn sống và sẵn sàng nhận mạng.

---

## 3. Ứng dụng thực tế trong Canary Rollout

*   Khi muốn tiến hành thử nghiệm tính năng tự động hủy bỏ (Abort) Canary Rollout: ta chỉ cần thiết lập giá trị `ERROR_RATE` lên `1` (lỗi 100%) hoặc `0.2` (lỗi 20%) trong cấu hình triển khai [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml).
*   Lúc này, traffic đi vào Canary Pod mới sẽ trả về mã lỗi 500. Prometheus qua ServiceMonitor thu thập được số liệu này. Biểu thức trong AnalysisTemplate phát hiện tỷ lệ thành công bị sụt giảm quá ngưỡng cam kết (SLO < 95%) nên sẽ tự động gửi chỉ thị rollback về.
