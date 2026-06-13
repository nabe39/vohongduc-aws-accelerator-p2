# 📄 Giải thích Code: [apply_env.py](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/apply_env.py)

File Python này đóng vai trò là một tiện ích nhỏ giúp tự động điền các thông tin bảo mật (SMTP Gmail) từ file môi trường cục bộ vào cấu hình ứng dụng giám sát Kubernetes trước khi deploy.

---

## 1. Phân tích chi tiết mã nguồn

### 1.1 Hàm `load_env(env_path)`
Hàm này đọc file cấu hình `.env` cục bộ và chuyển đổi các dòng text thành một Dictionary trong Python.

```python
def load_env(env_path):
    env_vars = {}
    if not os.path.exists(env_path):
        print(f"Error: File {env_path} không tồn tại.")
        return None
    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            # Bỏ qua dòng trống hoặc dòng bắt đầu bằng dấu thăng (#) là comment
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, val = line.split('=', 1)
                # Loại bỏ khoảng trắng và dấu nháy kép, nháy đơn nếu có
                val = val.strip().strip('"').strip("'")
                env_vars[key.strip()] = val
    return env_vars
```

### 1.2 Hàm `main()`
Hàm chính thực hiện logic đọc dữ liệu môi trường và ghi vào file cấu hình YAML.

```python
def main():
    env_path = 'alertmanager.env'
    target_yaml = 'argocd/apps/kube-prometheus-stack.yaml'

    env_vars = load_env(env_path)
    if not env_vars:
        return

    smtp_user = env_vars.get('SMTP_USER', '')
    smtp_pass = env_vars.get('SMTP_PASSWORD', '')
    alert_to = env_vars.get('ALERT_TO_EMAIL', '')

    # Ngăn chặn trường hợp người dùng chạy script khi chưa cấu hình thông tin thật
    if 'your-email' in smtp_user or 'your-app-password' in smtp_pass:
        print("Cảnh báo: Bạn cần điền thông tin thật vào file alertmanager.env trước khi chạy script này.")
        return

    if not os.path.exists(target_yaml):
        print(f"Error: File cấu hình {target_yaml} không tồn tại.")
        return

    # Đọc file Helm values của Prometheus Stack
    with open(target_yaml, 'r', encoding='utf-8') as f:
        content = f.read()

    # Thực hiện thay thế các placeholder (chỗ trống đại diện) bằng giá trị thật
    updated_content = content
    if smtp_user:
        updated_content = updated_content.replace('<YOUR_GMAIL_USERNAME>@gmail.com', smtp_user)
    if smtp_pass:
        updated_content = updated_content.replace('<YOUR_GMAIL_APP_PASSWORD>', smtp_pass)
    if alert_to:
        updated_content = updated_content.replace('<YOUR_PERSONAL_EMAIL>@gmail.com', alert_to)

    # Nếu có sự thay đổi thì mới ghi đè lại file
    if updated_content == content:
        print("Không có thay đổi nào được áp dụng (có thể các placeholder đã được thay thế trước đó).")
    else:
        with open(target_yaml, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        print(f"Thành công! Đã cập nhật thông tin bảo mật vào file {target_yaml}.")
```

---

## 2. Ý nghĩa và lý do sử dụng

*   **Tự động hóa bảo mật:** Thay vì người dùng phải mở file YAML cấu hình phức tạp [kube-prometheus-stack.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/apps/kube-prometheus-stack.yaml) ra sửa đổi thủ công bằng tay (rất dễ gõ sai cú pháp YAML thụt dòng thụt lề), script thực hiện việc tìm kiếm và thay thế chính xác các chuỗi ký tự giữ chỗ (`<YOUR_GMAIL_USERNAME>@gmail.com`, `<YOUR_GMAIL_APP_PASSWORD>`, `<YOUR_PERSONAL_EMAIL>@gmail.com`).
*   **Tránh push nhầm token lên Git:** Việc tách biệt ra file môi trường trung gian giúp repo Git luôn ở trạng thái "sạch" không bị lộ password cá nhân.
