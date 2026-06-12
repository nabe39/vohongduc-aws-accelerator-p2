# file: cloud/w9/lab/gitops/k8s/apply_env.py
import os

def load_env(env_path):
    env_vars = {}
    if not os.path.exists(env_path):
        print(f"Error: File {env_path} không tồn tại.")
        return None
    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, val = line.split('=', 1)
                # Loại bỏ khoảng trắng và dấu nháy nếu có
                val = val.strip().strip('"').strip("'")
                env_vars[key.strip()] = val
    return env_vars

def main():
    env_path = 'alertmanager.env'
    target_yaml = 'argocd/apps/kube-prometheus-stack.yaml'

    env_vars = load_env(env_path)
    if not env_vars:
        return

    smtp_user = env_vars.get('SMTP_USER', '')
    smtp_pass = env_vars.get('SMTP_PASSWORD', '')
    alert_to = env_vars.get('ALERT_TO_EMAIL', '')

    if 'your-email' in smtp_user or 'your-app-password' in smtp_pass:
        print("Cảnh báo: Bạn cần điền thông tin thật vào file alertmanager.env trước khi chạy script này.")
        return

    if not os.path.exists(target_yaml):
        print(f"Error: File cấu hình {target_yaml} không tồn tại.")
        return

    with open(target_yaml, 'r', encoding='utf-8') as f:
        content = f.read()

    # Thực hiện thay thế các placeholder
    updated_content = content
    if smtp_user:
        updated_content = updated_content.replace('<YOUR_GMAIL_USERNAME>@gmail.com', smtp_user)
    if smtp_pass:
        updated_content = updated_content.replace('<YOUR_GMAIL_APP_PASSWORD>', smtp_pass)
    if alert_to:
        updated_content = updated_content.replace('<YOUR_PERSONAL_EMAIL>@gmail.com', alert_to)

    if updated_content == content:
        print("Không có thay đổi nào được áp dụng (có thể các placeholder đã được thay thế trước đó).")
    else:
        with open(target_yaml, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        print(f"Thành công! Đã cập nhật thông tin bảo mật vào file {target_yaml}.")

if __name__ == '__main__':
    main()
