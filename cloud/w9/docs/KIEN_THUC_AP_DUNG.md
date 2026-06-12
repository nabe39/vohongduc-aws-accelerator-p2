# 🧠 Các Kiến Thức Vận Hành & Phát Triển Được Áp Dụng (Concepts & Best Practices)

Dự án này là một bài thực hành tổng hợp tích hợp nhiều lý thuyết nền tảng về **DevOps**, **GitOps**, **SRE (Site Reliability Engineering)** và **Hạ tầng bất biến (Immutable Infrastructure)**. Dưới đây là phân tích chi tiết về các kiến thức cốt lõi được áp dụng thực tế.

---

## 1. Nguyên Tắc GitOps (GitOps Principles)

GitOps không chỉ là việc dùng Git để lưu code, mà là phương pháp quản lý vận hành hạ tầng dựa trên 4 nguyên tắc cốt lõi của **OpenGitOps**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        4 NGUYÊN TẮC GITOPS                             │
├───────────────────────────────────┬────────────────────────────────────┤
│ 1. Mô tả dưới dạng Declarative    │ Hệ thống mô tả bằng khai báo cấu   │
│                                   │ hình (YAML) thay vì chạy lệnh CLI. │
├───────────────────────────────────┼────────────────────────────────────┤
│ 2. Lưu trữ có Version & Immutable │ Toàn bộ trạng thái mong muốn được  │
│                                   │ lưu trên Git, có lịch sử commit.   │
├───────────────────────────────────┼────────────────────────────────────┤
│ 3. Tự động kéo cấu hình (Pull)    │ Agent (ArgoCD) tự động kéo thay    │
│                                   │ đổi từ Git về thay vì push thủ công│
├───────────────────────────────────┼────────────────────────────────────┤
│ 4. Vòng lặp đối khớp (Reconcile)  │ Liên tục so sánh trạng thái thực   │
│                                   │ tế với Git và tự động sửa lệch.   │
└───────────────────────────────────┴────────────────────────────────────┘
```

* **Áp dụng trong dự án:**
  * Toàn bộ tài nguyên K8s từ namespace, deployment, service cho đến Prometheus rules hay cấu hình alert đều được viết thành file `.yaml` trong thư mục [lab/gitops/k8s/](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s).
  * Việc khôi phục (Rollback) được thực hiện chuẩn chỉ bằng lệnh `git revert` trên Git repo, thay vì dùng `kubectl rollout undo` trên cluster, đảm bảo Git luôn là nguồn sự thật duy nhất (Single Source of Truth).

---

## 2. Mô Hình App-of-Apps & Sync Waves

Khi hạ tầng phình to với hàng chục ứng dụng và cấu hình phụ thuộc lẫn nhau, việc deploy thủ công từng file YAML sẽ dẫn đến lỗi do sai thứ tự. Dự án đã áp dụng hai kỹ thuật quản lý nâng cao của ArgoCD:

### App-of-Apps Pattern:
* **Khái niệm:** Một "Ứng dụng cha" (Root Application) quản lý một danh sách các "Ứng dụng con" (Child Applications). 
* **Áp dụng:** File [root.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/argocd/root.yaml) đóng vai trò ứng dụng cha. Khi apply file này, ArgoCD tự động tạo các ứng dụng con như `kube-prometheus-stack`, `argo-rollouts`, `web`, và `api`. Chỉ cần 1 entrypoint duy nhất để dựng toàn bộ hệ thống.

### Sync Waves:
* **Khái niệm:** Phân cấp thứ tự đồng bộ hóa tài nguyên K8s bằng annotation `argocd.argoproj.io/sync-wave`. Giá trị wave càng thấp (âm) càng được chạy trước.
* **Áp dụng:**
  * **Wave `-1`:** Tạo [namespace.yaml](file:///e:/Work/Developer/AWS/XBrain_devop_cloud/ThucHanh/vohongduc-aws-accelerator-p2/cloud/w9/lab/gitops/k8s/namespace.yaml) trước để làm chỗ chứa các tài nguyên khác.
  * **Wave `0`:** Tạo ConfigMaps/Secrets (như `web-config`).
  * **Wave `1`:** Khởi chạy Deployments/Rollouts (để ứng dụng có thể đọc cấu hình từ ConfigMap đã sẵn sàng).
  * **Wave `2`:** Tạo Services và ServiceMonitors (kết nối mạng và bắt đầu giám sát sau khi ứng dụng đã chạy).

---

## 3. Phân Phối Tăng Tiến & Giảm Thiểu Tầm Ảnh Hưởng (Progressive Delivery & Blast Radius)

Phát hành ứng dụng luôn đi kèm rủi ro. Kỹ thuật **Progressive Delivery (Canary Release)** được áp dụng để giải quyết triệt để vấn đề này.

* **Khái niệm Blast Radius (Tầm ảnh hưởng lỗi):** Là tỷ lệ phần trăm người dùng hoặc hệ thống bị ảnh hưởng khi có một lỗi xảy ra trong phiên bản mới.
* **Chiến lược Canary giảm Blast Radius:**
  * Thay vì chuyển 100% traffic sang bản mới ngay lập tức (như Blue-Green hay Rolling Update thông thường), hệ thống chỉ chuyển **25%** traffic sang bản mới. Nếu bản mới bị lỗi 100%, thì tầm ảnh hưởng chung (Blast Radius) đối với khách hàng chỉ giới hạn ở mức **25%**.
* **Phân Tích Tự Động (Automated Canary Analysis - ACA):**
  * Trong lúc pause ở mức 25%, hệ thống không nằm im đợi con người phê duyệt. Lớp phân tích tự động `AnalysisTemplate` liên tục kiểm soát các chỉ số chất lượng mỗi 30 giây.
  * Nếu lỗi vượt quá 3 lần liên tiếp, hệ thống tự động kích hoạt **Abort & Rollback** tự động mà không cần kỹ sư thức đêm trực để bấm nút rollback thủ công.

---

## 4. Lý Thuyết SRE: SLI, SLO & Error Budget

Đo lường độ tin cậy của dịch vụ là kiến thức cốt lõi của kỹ sư SRE từ Google. Dự án đã áp dụng các khái niệm này vào thực tế:

```
                  ┌──────────────────────────────────────────────┐
                  │                 USER EXPERIENCE              │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │  SLI (Service Level Indicator)               │
                  │  Tỉ lệ % request thành công thực tế thu được │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │  SLO (Service Level Objective)               │
                  │  Mục tiêu cam kết (Ví dụ: Success Rate >= 95%)│
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │  Error Budget (Ngân sách lỗi)                │
                  │  Tỉ lệ lỗi cho phép xảy ra (Ví dụ: 5%)       │
                  └──────────────────────────────────────────────┘
```

* **SLI (Chỉ số chất lượng dịch vụ):** Được đo bằng công thức PromQL:
  $$\text{SLI} = \frac{\text{Tổng request thành công (không phải 5xx)}}{\text{Tổng HTTP request nhận được}}$$
* **SLO (Mục tiêu chất lượng dịch vụ):** Được cam kết ở mức **95%** thành công.
* **Error Budget (Ngân sách lỗi):** Là phần dư ra ($100\% - \text{SLO} = 5\%$). Hệ thống được phép lỗi tối đa 5% lượng traffic mà vẫn coi là đạt cam kết chất lượng.

---

## 5. Chiến Lược Cảnh Báo Sức Khỏe SLO & Tốc Độ Tiêu Hao (Burn Rate Alerting)

Để cảnh báo hiệu quả mà không gây loãng tin nhắn (Alert Fatigue), SRE áp dụng khái niệm **Burn Rate (Tốc độ tiêu hao ngân sách lỗi)**.

* **Burn Rate là gì?** Là tốc độ tiêu thụ Error Budget. 
  * Burn Rate = 1: Tiêu thụ hết Error Budget vừa đúng trong khoảng thời gian cam kết (ví dụ: mất 30 ngày để tiêu hết 5% lỗi cho phép).
  * Burn Rate = 14.4: Tiêu thụ hết Error Budget cực nhanh chỉ trong 50 giờ (rất nguy hiểm, cần bắn alert ngay lập tức).
* **Multi-Window Alerting (Nhiều cửa sổ thời gian):**
  * **Cửa sổ ngắn (Fast Burn - ví dụ 2m/5m):** Dùng để phát hiện các sự cố nghiêm trọng, sập dịch vụ đột ngột (lỗi 100%). Cần cảnh báo khẩn cấp (Critical Alert).
  * **Cửa sổ dài (Slow Burn - ví dụ 30m/1h):** Dùng để phát hiện các lỗi nhỏ rò rỉ âm ỉ kéo dài (lỗi 6% liên tục). Lỗi này không làm sập hệ thống ngay nhưng sẽ ăn mòn dần Error Budget theo thời gian.
* **Áp dụng trong dự án:**
  * **AnalysisTemplate (Canary):** Dùng cửa sổ trượt ngắn **2 phút (`[2m]`)** để phát hiện lỗi bùng phát nhanh của bản code mới deploy, từ đó kích hoạt abort lập tức trong vòng dưới 2 phút.
  * **PrometheusRule (SLO Alert):** Dùng cửa sổ trượt dài hơn **5 phút (`[5m]`)** để đánh giá tổng thể và gửi mail cảnh báo qua Alertmanager tới email cá nhân khi SLO bị đe dọa thực sự.
