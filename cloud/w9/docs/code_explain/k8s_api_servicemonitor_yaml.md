# 📄 Giải thích Code: [servicemonitor.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/servicemonitor.yaml)

File manifest này định nghĩa cấu hình **ServiceMonitor** của Prometheus Operator. Đây là cầu nối trung gian giúp Prometheus Server tự động phát hiện và định kỳ thu thập dữ liệu (scrape targets) từ API Service mà không cần khai báo IP thủ công.

---

## 1. Nội dung Code

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-servicemonitor
  namespace: demo
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: api
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

---

## 2. Giải thích chi tiết cấu hình

*   `kind: ServiceMonitor`: Tài nguyên Custom Resource Definition (CRD) của Prometheus Operator. Nó mô tả cách thu thập metrics từ một tập hợp các Service Kubernetes.
*   `metadata`:
    *   `name: api-servicemonitor`: Đặt tên cho ServiceMonitor này.
    *   `namespace: demo`: Đặt trong cùng namespace với ứng dụng `api` để thuận tiện quản lý.
    *   `labels.release: kube-prometheus-stack`: **Nhãn chìa khóa bắt buộc.** Prometheus Server được cấu hình chỉ quét các ServiceMonitor có chứa nhãn release trùng khớp. Nhãn này đảm bảo Prometheus Operator phát hiện ra tệp cấu hình này để sinh cấu hình scrape tương ứng.
*   `spec`: Phần mô tả mục tiêu scrape.
    *   `selector.matchLabels.app: api`: ServiceMonitor sẽ tìm kiếm tất cả các **Service** K8s trong cluster có chứa nhãn `app: api`. Ở đây chính là Service `api` định nghĩa trong file [api.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/k8s-api/api.yaml).
    *   `endpoints`: Khai báo các cổng và thông số thu thập dữ liệu.
        *   `port: http`: Chỉ định tên cổng (Port Name) trên Service cần scrape là `http` (tương đương cổng `8080` của API).
        *   `path: /metrics`: Đường dẫn API trên ứng dụng Flask xuất ra dữ liệu metrics định dạng Prometheus.
        *   `interval: 15s`: Tần suất kéo dữ liệu. Cứ mỗi **15 giây**, Prometheus Server sẽ gửi một request `GET /metrics` đến các Pods nằm sau Service để lấy số liệu mới nhất về lưu trữ và vẽ biểu đồ.
