# 📄 Giải thích Code: [Dockerfile](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/app/Dockerfile)

File Dockerfile này định nghĩa quy trình build Docker Image cho ứng dụng Flask chạy API, phục vụ cho quá trình test Canary và giám sát metric Prometheus.

---

## 1. Nội dung Code

```dockerfile
FROM python:3.12-slim
RUN pip install flask prometheus-flask-exporter
COPY app.py /app/app.py
WORKDIR /app
ENV FLASK_APP=app.py
EXPOSE 8080
CMD ["flask","run","--host=0.0.0.0","--port=8080"]
```

---

## 2. Giải thích chi tiết từng dòng lệnh

*   `FROM python:3.12-slim`: Sử dụng image nền (Base Image) là Python phiên bản 3.12 dạng rút gọn (`slim`). Image slim được tối ưu để giảm dung lượng file xuống mức tối thiểu, giúp tăng tốc độ build và pull image trong Kubernetes.
*   `RUN pip install flask prometheus-flask-exporter`: Chạy lệnh cài đặt 2 thư viện Python cần thiết:
    *   `flask`: Web framework gọn nhẹ để viết ứng dụng API.
    *   `prometheus-flask-exporter`: Thư viện tự động đo đạc hiệu năng ứng dụng Flask (như số lượng request, HTTP status code, response time) và xuất chúng ra chuẩn Prometheus tại endpoint `/metrics`.
*   `COPY app.py /app/app.py`: Sao chép file mã nguồn ứng dụng [app.py](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/app/app.py) từ thư mục máy local vào bên trong đường dẫn `/app/app.py` của Container.
*   `WORKDIR /app`: Thiết lập thư mục làm việc mặc định bên trong Container là `/app`.
*   `ENV FLASK_APP=app.py`: Đặt biến môi trường `FLASK_APP` trỏ tới file chạy ứng dụng Flask.
*   `EXPOSE 8080`: Khai báo cổng lắng nghe của container là `8080`. Đây là cổng chạy thực tế của ứng dụng bên trong mạng Docker.
*   `CMD ["flask","run","--host=0.0.0.0","--port=8080"]`: Lệnh mặc định sẽ được chạy khi Container khởi động. Lệnh này khởi chạy server Flask ở chế độ lắng nghe trên mọi địa chỉ IP mạng (`0.0.0.0`) và cổng `8080`.
