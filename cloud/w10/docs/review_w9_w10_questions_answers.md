# Bộ Câu Hỏi Ôn Tập W9 + W10 — Mentor Review Session

> Tài liệu này tổng hợp 50 câu hỏi tự luận bao phủ toàn bộ kiến thức từ tuần W9 (GitOps, Observability, Canary) và W10 (RBAC, Admission Policy, Secrets, Supply Chain Security, Platform Integration, Incident Response). Mục tiêu là giúp trainee tự kiểm tra lại mức độ hiểu bài và kết nối các khái niệm với nhau trước khi vào Capstone W11-W12.

---

## Phần 1: GitOps và CI/CD (W9 — Thứ 2)

**Câu 1:** GitOps là gì? Hãy nêu 4 nguyên tắc cốt lõi của OpenGitOps và giải thích tại sao Git được gọi là "nguồn sự thật duy nhất" (Single Source of Truth)?

**Trả lời:**
GitOps là phương pháp quản lý vận hành hạ tầng và ứng dụng mà trong đó Git là nguồn sự thật duy nhất cho trạng thái mong muốn của hệ thống. Thay vì apply manifest thủ công bằng lệnh CLI, mọi thay đổi phải đi qua Git commit.

4 nguyên tắc cốt lõi của OpenGitOps:

1. **Mô tả dạng Declarative:** Hệ thống được mô tả bằng file cấu hình khai báo (YAML, Helm, Kustomize) thay vì chạy các lệnh imperative. Ví dụ: viết `replicas: 3` trong YAML thay vì chạy `kubectl scale --replicas=3`.
2. **Lưu trữ có Version và Immutable:** Toàn bộ trạng thái mong muốn được lưu trong Git, có lịch sử commit đầy đủ. Mỗi thay đổi là 1 commit mới, không sửa đè trực tiếp.
3. **Tự động kéo cấu hình (Pull):** Agent (ArgoCD, Flux) tự động kéo thay đổi từ Git về cluster, thay vì CI push lệnh trực tiếp vào cluster. Đây là điểm khác biệt cơ bản với CI/CD truyền thống.
4. **Vòng lặp đối khớp (Reconcile):** Agent liên tục so sánh trạng thái thực tế trên cluster với trạng thái trong Git. Nếu có lệch (drift), agent tự động sửa lại về đúng trạng thái mong muốn.

Git là "nguồn sự thật duy nhất" vì bất kỳ ai cũng có thể biết chính xác trạng thái cluster đang chạy gì chỉ bằng cách xem Git repo, không cần SSH vào cluster.

---

**Câu 2:** So sánh `git revert` và `kubectl rollout undo` khi cần rollback. Cách nào phù hợp với tinh thần GitOps hơn và tại sao?

**Trả lời:**

| Tiêu chí | `git revert` | `kubectl rollout undo` |
|---|---|---|
| Tác động | Tạo 1 commit mới đảo ngược thay đổi trên Git | Tác động trực tiếp vào cluster, không qua Git |
| GitOps | Phù hợp hoàn toàn — Git vẫn là nguồn sự thật | Vi phạm GitOps — trạng thái cluster lệch khỏi Git |
| Audit trail | Có đầy đủ lịch sử ai revert lúc mấy giờ | Không có vết tích trên Git |
| Rollback scope | Rollback chính xác theo commit | Rollback deployment, không rollback cấu hình khác |
| Tốc độ | Chưa hàng qua ArgoCD auto-sync (1-2 phút) | Ngay lập tức |

`git revert` phù hợp với GitOps hơn vì sau khi revert, ArgoCD đọc lại Git và tự động đồng bộ cluster về trạng thái an toàn. Git luôn là nguồn sự thật. `kubectl rollout undo` dù nhanh nhưng phù hợp hơn trong tình huống khẩn cấp khi GitOps chưa được thiết lập đầy đủ.

---

**Câu 3:** App-of-Apps pattern trong ArgoCD là gì? Nêu một ví dụ thực tế về cấu trúc repo và giải thích tại sao pattern này phổ biến khi quản lý nhiều ứng dụng.

**Trả lời:**
App-of-Apps là mô hình trong đó một Application cha (root) quản lý nhiều Application con. Application cha chỉ trỏ đến thư mục chứa các Application con, ArgoCD tự động tạo và quản lý toàn bộ từ một entrypoint duy nhất.

Ví dụ trong dự án W9:
```
argocd/
  root.yaml               <- Application cha (trỏ vào thư mục apps/)
  apps/
    kube-prometheus-stack.yaml   <- App con: monitoring stack
    argo-rollouts.yaml           <- App con: canary controller
    web.yaml                     <- App con: frontend
    api.yaml                     <- App con: backend API
```

Tại sao phổ biến:
- **1 entrypoint:** Chỉ cần `kubectl apply -f root.yaml` là toàn bộ platform được dựng lên tự động
- **Quản lý độc lập:** Mỗi App con có lifecycle riêng, sync riêng, có thể enable/disable từng phần
- **Phân quyền:** Có thể giao quyền sync cho từng team riêng biệt (team infra quản lý monitoring, team dev quản lý app)
- **Dễ scale:** Thêm app mới chỉ cần thêm file YAML vào thư mục `apps/`, root tự động phát hiện

---

**Câu 4:** Sync Waves trong ArgoCD là gì? Hãy giải thích thứ tự deployment hợp lý cho một hệ thống có Namespace, ConfigMap, Deployment, Service và ServiceMonitor.

**Trả lời:**
Sync Waves là kỹ thuật sử dụng annotation `argocd.argoproj.io/sync-wave: <số>` để sắp xếp thứ tự deploy tài nguyên. Tài nguyên có giá trị wave nhỏ hơn (âm) sẽ được deploy trước.

Thứ tự hợp lý:
- **Wave -1:** Namespace — phải tồn tại trước thì các tài nguyên khác mới có "chỗ chứa"
- **Wave 0:** ConfigMap, Secret — ứng dụng cần đọc cấu hình này khi khởi động
- **Wave 1:** Deployment, Rollout — ứng dụng khởi chạy sau khi đã có cấu hình sẵn
- **Wave 2:** Service, ServiceMonitor — kết nối mạng và bắt đầu giám sát sau khi ứng dụng đã chạy

Nếu không dùng Sync Waves, có thể xảy ra tình trạng Deployment được tạo trước khi Namespace tồn tại, dẫn đến lỗi.

---

**Câu 5:** Trong CI/CD với GitOps, tại sao người ta sử dụng mô hình "plan-on-PR, apply-on-merge" thay vì "apply ngay khi push"? Nêu các rủi ro nếu apply ngay khi push.

**Trả lời:**

**Plan-on-PR:** Khi mở Pull Request, CI chỉ chạy kiểm tra (lint, validate YAML, terraform plan, dry-run) và hiển thị những gì sẽ thay đổi. Team review và approve trước khi merge.

**Apply-on-merge:** Chỉ khi PR được merge vào main branch, CI mới thực sự apply thay đổi vào môi trường.

Rủi ro nếu apply ngay khi push:
1. **Không có review:** Lỗi trong YAML có thể lên production ngay lập tức, không ai kiểm tra
2. **Không có audit:** Khó biết ai đã push gì và khi nào khi có sự cố
3. **Xung đột:** Nhiều người push cùng lúc có thể gây xung đột trạng thái cluster
4. **Không có rollback plan:** Không có biện pháp kiểm tra trước nên khi lỗi rất khó biết rollback về đâu

Mô hình plan-on-PR tạo ra "cổng kiểm soát" (gate) buộc mọi thay đổi phải được con người phê duyệt trước khi ảnh hưởng đến cluster.

---

## Phần 2: Observability — SLO, SLI, Prometheus, Grafana (W9 — Thứ 3)

**Câu 6:** Observability là gì? Giải thích sự khác nhau giữa 3 trụ cột: Metrics, Logs và Traces. Mỗi cái dùng để làm gì trong thực tế?

**Trả lời:**
Observability là khả năng hiểu được trạng thái bên trong của hệ thống thông qua các tín hiệu (signals) nó phát ra bên ngoài.

3 trụ cột:

| Trụ cột | Mô tả | Dùng để làm gì |
|---|---|---|
| **Metrics** | Dữ liệu số (time-series), đo lường theo thời gian | Biết "hệ thống đang như thế nào" — CPU, request rate, error rate, latency p95 |
| **Logs** | Bản ghi sự kiện text, có timestamp | Biết "chuyện gì xảy ra" — debug lỗi cụ thể, xem stack trace |
| **Traces** | Luồn theo yêu cầu qua nhiều service | Biết "yêu cầu đi theo đường nào" — tìm bottleneck trong microservices |

Ví dụ thực tế: Khi có alert CPU cao (Metric), SRE xem log để biết process nào gây ra (Log), sau đó dùng trace để hiểu request nào chậm và tại sao (Trace).

---

**Câu 7:** SLI và SLO là gì? Hãy định nghĩa công thức tính SLI cho một API service và nêu ví dụ cụ thể về SLO phù hợp.

**Trả lời:**

**SLI (Service Level Indicator)** là chỉ số đo lường chất lượng dịch vụ thực tế. Đây là giá trị "đang đo".

Công thức tính SLI Availability cho API:
```
SLI = (Tổng request thành công (không phải 5xx)) / (Tổng request nhận được)
```

Ví dụ PromQL:
```promql
sum(rate(flask_http_request_total{status!~"5.."}[5m]))
/
(sum(rate(flask_http_request_total{}[5m])) or on() vector(1))
```

**SLO (Service Level Objective)** là mục tiêu cam kết đặt ra cho SLI. Đây là "ngưỡng chấp nhận".

Ví dụ SLO:
- SLO Availability: `>= 95%` request thành công trong 30 ngày
- SLO Latency: `>= 99%` request có response time < 500ms

Error Budget = 100% - SLO = 5% là phần dư lại, tổ chức được phép để lỗi mà vẫn đạt cam kết.

---

**Câu 8:** Làm sao nhận được email thông báo khi EC2 đặt ngưỡng CPU 80%? Hãy mô tả toàn bộ luồng cấu hình từ AWS CloudWatch đến email.

**Trả lời:**
Luồng cấu hình đầy đủ:

**Bước 1: Tạo SNS Topic**
- Vào AWS SNS Console, tạo Topic mới (Standard type)
- Tạo Subscription: Protocol = Email, Endpoint = địa chỉ email nhận cảnh báo
- Xác nhận email (confirm subscription link được gửi đến hộp thư)

**Bước 2: Tạo CloudWatch Alarm**
- Vào CloudWatch > Alarms > Create Alarm
- Chọn metric: EC2 > Per-Instance Metrics > CPUUtilization
- Chọn instance cụ thể cần giám sát
- Thiết lập điều kiện: `>= 80` trong 1 period (ví dụ 5 phút)
- Action: In alarm state -> Send notification to SNS Topic vừa tạo

**Bước 3: Test**
- Có thể generate tải trên EC2 bằng stress tool: `stress --cpu 8 --timeout 300`
- Đợi khoảng 5 phút, kiểm tra email

**Lưu ý:** Với K8s/EKS, có thể dùng PrometheusRule + Alertmanager thay CloudWatch. Alertmanager được cấu hình SMTP (Gmail) để gửi email khi alert trigger.

---

**Câu 9:** Burn Rate là gì? Giải thích tại sao phải dùng nhiều cửa sổ thời gian (multi-window) trong alert thay vì chỉ 1 ngưỡng đơn giản.

**Trả lời:**

**Burn Rate** là tốc độ tiêu hao Error Budget.
- Burn Rate = 1: Tiêu thụ hết Error Budget vừa đúng trong thời gian cam kết (30 ngày)
- Burn Rate = 14.4: Tiêu thụ hết trong 50 giờ — rất nguy hiểm

Ví dụ: SLO = 99.9% (Error Budget = 0.1%). Nếu trong 1 giờ có 1% lỗi -> Burn Rate = 1%/0.1% = 10 -> Tiêu hết budget trong 3 ngày.

**Tại sao cần multi-window:**
- **Cửa sổ ngắn (Fast Burn - 2m/5m):** Phát hiện sự cố nghiêm trọng, sập dịch vụ đột ngột (lỗi 100%). Cần cảnh báo khẩn cấp ngay.
- **Cửa sổ dài (Slow Burn - 30m/1h):** Phát hiện lỗi nhỏ rò rỉ âm ỉ kéo dài (lỗi 6% liên tục). Không làm sập hệ thống ngay nhưng ăn mòn dần Error Budget.

Nếu chỉ dùng 1 ngưỡng đơn giản (ví dụ `error_rate > 0.05`):
- **Cảnh báo giả (False Alarm):** 1 spike ngắn 30 giây sẽ trigger alert
- **Bỏ lọ lỗi âm ỉ:** Lỗi 6% dài hạn không vượt ngưỡng đơn giản nhưng sẽ sập SLO sau nhiều ngày

Multi-window alert giảm nhiễu (Alert Fatigue) và phát hiện cả 2 loại sự cố.

---

**Câu 10:** Grafana không hiển thị gì từ Prometheus, bạn sẽ debug như thế nào? Mô tả từng bước cụ thể.

**Trả lời:**
Quy trình debug theo thứ tự:

**Bước 1: Kiểm tra Prometheus có chạy không**
```bash
kubectl get pods -n monitoring
# Xem prometheus-server có STATUS = Running không
kubectl logs -n monitoring prometheus-server-xxx
```

**Bước 2: Kiểm tra Prometheus có scrape được data không**
- Truy cập Prometheus UI: `kubectl port-forward -n monitoring svc/prometheus 9090:9090`
- Vào tab `Status > Targets` — kiểm tra target có UP không
- Vào tab `Graph`, thử query đơn giản: `up` — xem có data trả về không

**Bước 3: Kiểm tra kết nối từ Grafana đến Prometheus**
- Vào Grafana > Configuration > Data Sources > Prometheus
- Click "Save & Test" — xem có báo "Data source connected" không
- Kiểm tra URL Prometheus đúng chưa: phải dùng Service DNS nội bộ, ví dụ `http://prometheus-server.monitoring.svc.cluster.local:9090`

**Bước 4: Kiểm tra query trong Grafana**
- Mở panel cần xem > Edit
- Chạy thử query trong Prometheus UI trước — xem có data trả về không
- Kiểm tra time range của Grafana có khớp với thời gian có data không

**Bước 5: Kiểm tra quyền RBAC và NetworkPolicy**
- Kiểm tra xem có NetworkPolicy chặn traffic từ Grafana pod đến Prometheus pod không
- Kiểm tra ServiceAccount của Grafana có quyền đọc metrics không

**Nguyên nhân phổ biến nhất:** URL data source sai (dùng IP thay vì DNS), time range không khớp, Prometheus chưa scrape được target.

---

**Câu 11:** OpenTelemetry là gì? Giải thích vai trò của OTel SDK và OTel Collector trong luồng observability tổng thể.

**Trả lời:**

**OpenTelemetry (OTel)** là framework observability mã nguồn mở, trung lập nhà cung cấp, cho phép instrument ứng dụng để thu thập metrics, logs, traces và gửi đi các backend phân tích.

**OTel SDK** là thư viện nhúng vào trong ứng dụng (Go, Python, Java, Node.js...) để:
- Phát sinh trace khi có request
- Phát sinh metrics (counter, histogram, gauge)
- Phát sinh structured logs
- Tất cả được định dạng chuẩn OTLP (OpenTelemetry Protocol)

**OTel Collector** đóng vai trò trung gian (middleware) giữa ứng dụng và backend:
- **Receiver:** Nhận dữ liệu từ SDK (OTLP, Jaeger, Prometheus format)
- **Processor:** Xử lý, lọc, thêm label, batch dữ liệu
- **Exporter:** Gửi dữ liệu đến backend: Prometheus (metrics), Loki (logs), Jaeger/Tempo (traces)

Lợi ích của việc dùng Collector: Tách phần instrument ứng dụng khỏi phần routing. Khi cần đổi backend, chỉ thay đổi cấu hình Collector, không cần sửa code ứng dụng.

Luồng thực tế trong W9:
```
Flask App (OTel SDK) -> OTLP -> OTel Collector -> Prometheus (metrics) / Loki (logs)
                                                   -> Grafana Dashboard
```

---

**Câu 12:** PromQL là gì? Giải thích câu query sau đây và ý nghĩa của từng phần:
`sum(rate(flask_http_request_total{status!~"5..", job="api"}[5m])) / sum(rate(flask_http_request_total{job="api"}[5m]))`

**Trả lời:**
Phân tích từng thành phần:

| Thành phần | Ý nghĩa |
|---|---|
| `flask_http_request_total` | Metric đếm tổng số HTTP request, cung cấp bởi prometheus_flask_exporter |
| `{status!~"5.."}` | Filter: chỉ lấy các request có status KHÔNG phải 5xx (regex negative match) |
| `{job="api"}` | Filter: chỉ lấy metrics từ job/service có tên "api" |
| `rate(...[5m])` | Tính tốc độ thay đổi trung bình mỗi giây trong 5 phút vừa qua |
| `sum(...)` | Cộng tất cả các chuỗi thời gian thành 1 giá trị tổng |
| `/ sum(...)` | Chia: tử số = request thành công, mẫu số = tổng request |

Kết quả trả về: Một số thập phân từ 0 đến 1 đại diện cho tỷ lệ thành công.
- Kết quả = 0.97 -> 97% request thành công
- Kết quả < 0.95 -> Vi phạm SLO 95% -> Trigger alert

Phần `or on() vector(1)` ở mẫu số: Nếu không có traffic, trả về 1 (100% thành công) để tránh chia cho 0.

---

## Phần 3: Canary và Progressive Delivery (W9 — Thứ 4)

**Câu 13:** Canary deployment là gì, tại sao phải sử dụng canary thay vì rolling update thông thường?

**Trả lời:**

**Canary deployment** là chiến lược chỉ đưa một phần nhỏ traffic (ví dụ 5-10%) sang phiên bản mới để kiểm tra chất lượng. Nếu metric ổn thì tăng dần; nếu xấu thì rollback ngay.

Tên "Canary" lấy cảm hứng từ thợ mỏ dùng chim canary để phát hiện khí độc carbon monoxide — chim khó thở sức trước, cảnh báo thợ mỏ.

**Tại sao dùng Canary thay Rolling Update?**

| Tiêu chí | Rolling Update | Canary |
|---|---|---|
| Phạm vi rủi ro | 100% user bị ảnh hưởng khi deploy | Chỉ x% user được kiểm tra |
| Phát hiện lỗi | Lỗi xảy ra trên toàn bộ user ngay | Lỗi chỉ ảnh hưởng tới % nhỏ ban đầu |
| Khả năng rollback | Phải rollback sau khi đã ảnh hưởng nhiều | Có thể rollback trước khi lỗi lan rộng |
| Kiểm soát | Không có cơ chế tự động kiểm tra | Có AnalysisTemplate tự động đánh giá |
| Blast Radius | Lớn (100%) | Nhỏ (có thể chỉ 1-5%) |

Rolling Update phù hợp cho các thay đổi không ảnh hưởng user (patch bé). Canary phù hợp cho các thay đổi lớn, phiên bản mới có rủi ro cao.

---

**Câu 14:** Hãy so sánh thả canary 1% và 10% khi deploy một version mới. Trường hợp nào nên dùng mỗi tỷ lệ?

**Trả lời:**

| Tiêu chí | Canary 1% | Canary 10% |
|---|---|---|
| Blast Radius | Rất nhỏ, chỉ 1/100 user bị ảnh hưởng | Lớn hơn, 1/10 user có thể bị lỗi |
| Thời gian kiểm tra | Lâu hơn mới có đủ mẫu để phân tích | Nhanh hơn có đủ mẫu thống kê |
| Độ tin cậy thống kê | Thấp — cần nhiều thời gian mới đủ data | Cao hơn — có đủ data để quyết định |
| Ảnh hưởng business | Rất thấp nếu có lỗi | Trung bình nếu có lỗi |
| Use case | Production có tất traffic lớn (VD: 100M req/ngày) | Production có traffic vừa, cần phân tích nhanh |

**Khi nào dùng 1%:**
- Service có traffic rất lớn (hàng triệu request/ngày) — 1% đã đủ để lấy mẫu thống kê
- Tính năng mới có rủi ro cao, chưa được kiểm tra kỹ
- SLO căng thẳng, doanh nghiệp không chấp nhận lỗi

**Khi nào dùng 10%:**
- Service có traffic vừa (vài trăm nghìn request/ngày) — 1% không đủ data để phân tích
- Tính năng đã được test kỹ ở staging
- Cần deploy nhanh để kịp deadline

**Chiến lược thứ tự lý tưởng:** 1% -> 5% -> 25% -> 50% -> 100%, mỗi bước pause và kiểm tra metric trước khi tăng.

---

**Câu 15:** Rollout CRD và AnalysisTemplate trong Argo Rollouts là gì? Giải thích luồng hoạt động khi một canary tự động abort.

**Trả lời:**

**Rollout CRD** là tài nguyên Kubernetes thay thế cho Deployment thường khi dùng Argo Rollouts. Nó cho phép mô tả chiến lược triển khai phức tạp như canary, blue-green.

**AnalysisTemplate** là CRD định nghĩa cách lấy và đánh giá metric trong lúc rollout. Nó bao gồm:
- Query lấy metric (PromQL, Datadog, New Relic...)
- Tần suất kiểm tra (interval)
- Điều kiện chấp nhận (successCondition)
- Giới hạn thất bại (failureLimit)

Luồng hoạt động khi Canary tự động Abort:
```
1. Push code mới -> ArgoCD sync -> Rollout CRD update image
2. Argo Rollouts tạo Canary ReplicaSet, chuyển 25% traffic sang
3. AnalysisRun được tạo, bắt đầu query Prometheus mỗi 30 giây
4. Kết quả query: error rate = 80% (vì phiên bản mới lỗi)
5. AnalysisRun ghi nhận: LẦN THẤT BẠI 1/3
   (sau 30 giây) LẦN THẤT BẠI 2/3
   (sau 30 giây) LẦN THẤT BẠI 3/3 -> VƯỢT failureLimit
6. AnalysisRun trạng thái: FAILED
7. Rollout tự động chuyển sang trạng thái: ABORTED
8. 100% traffic được chuyển trở lại phiên bản cũ (Stable)
9. Canary ReplicaSet được scale xuống 0
10. Alert được gửi về email/Slack để thông báo
```

---

**Câu 16:** Error Budget là gì? Giải thích cơ chế sử dụng error budget để quyết định có nên triển khai tính năng mới không.

**Trả lời:**

**Error Budget** là phần dư ra giữa 100% và SLO — là "ngân sách lỗi" mà tổ chức được phép tiêu.

Ví dụ: SLO = 99.9% trong 30 ngày
- Error Budget = 100% - 99.9% = 0.1%
- Tương đương: 0.1% x 30 ngày x 24 giờ x 60 phút = **43.8 phút downtime được phép**

**Cơ chế sử dụng Error Budget:**

| Tình trạng | Quyết định |
|---|---|
| Còn nhiều Error Budget | Được phép triển khai tính năng mới, chấp rủi ro cao hơn |
| Còn ít Error Budget | Giảm các thay đổi rủi ro, tập trung ổn định |
| Hết Error Budget | Đóng băng tất cả tính năng mới (feature freeze), chỉ sửa bug và cải thiện reliability |

Đây là cơ chế cân bằng giữa tốc độ phát triển (velocity) và độ ổn định (reliability). Dev muốn push nhanh, SRE muốn giữ ổn định — Error Budget là "đồng tiền chung" để hai bên đàm phán.

---

**Câu 17:** Argo Rollouts khác Deployment thường như thế nào? Khi nào nên chuyển từ Deployment sang Rollout?

**Trả lời:**

| Tiêu chí | Kubernetes Deployment | Argo Rollout |
|---|---|---|
| Chiến lược | RollingUpdate, Recreate | Canary, Blue-Green, và tùy chỉnh |
| Phân bổ traffic | Không hỗ trợ phân bổ theo tỷ lệ | Hỗ trợ phân bổ theo tỉ lệ (10%, 25%...) |
| Phân tích metric | Không có | AnalysisTemplate tự động đánh giá |
| Auto rollback | Không tự động theo metric | Tự động abort khi metric xấu |
| Pause/Resume | Không linh hoạt | Pause ở từng bước để con người kiểm tra |
| Dashboard | Kubectl thuần túy | Argo Rollouts Dashboard dễ theo dõi trực quan |

**Khi nên chuyển sang Rollout:**
- Service có SLO cao, không chấp nhận lỗi ảnh hưởng nhiều user
- Có Prometheus/Grafana đã được thiết lập, có metric để phân tích
- Team muốn auto-abort khi có lỗi để tránh thức khuya rollback tay
- Để deploy phiên bản lớn, có nhiều rủi ro

**Khi vẫn dùng Deployment:**
- Service nội bộ (internal), không ảnh hưởng user trực tiếp
- Team nhỏ, chưa có observability stack
- Thay đổi đơn giản (config, patch bé)

---

## Phần 4: Kubernetes RBAC (W10 — Thứ 2)

**Câu 18:** RBAC trong Kubernetes là gì? Giải thích sự khác nhau giữa Role/RoleBinding và ClusterRole/ClusterRoleBinding.

**Trả lời:**

**RBAC (Role-Based Access Control)** là cơ chế phân quyền trong Kubernetes, xác định ai (Subject) được phép làm gì (Verb) với tài nguyên gì (Resource).

4 đối tượng chính:
- **Role:** Tập hợp các quyền (rules) GIỚI HẠN trong một namespace cụ thể
- **ClusterRole:** Tập hợp các quyền áp dụng cho TOÀN BỘ cluster (không giới hạn namespace)
- **RoleBinding:** Gán Role vào một User/Group/ServiceAccount TRONG namespace
- **ClusterRoleBinding:** Gán ClusterRole vào User/Group/ServiceAccount TRÊN TOÀN CLUSTER

**Phạm vi sử dụng:**

| Trường hợp | Sử dụng |
|---|---|
| Developer chỉ làm việc trong namespace `team-a` | Role + RoleBinding trong `team-a` |
| SRE cần xem toàn bộ pod trên mọi namespace | ClusterRole + ClusterRoleBinding |
| Ứng dụng cần đọc ConfigMap trong namespace của nó | Role + RoleBinding (gán vào ServiceAccount) |
| Viewer chỉ được xem nhưng không được sửa | ClusterRole `view` có sẵn + ClusterRoleBinding |

---

**Câu 19:** Nếu muốn 1 người chỉ có quyền xem, 1 người có quyền xem và sửa 1 số resource trong namespace, 1 người toàn quyền thì làm như thế nào? Viết YAML minh họa.

**Trả lời:**

**Người 1: Chỉ có quyền xem (Viewer)**
```yaml
# Dùng ClusterRole "view" có sẵn của Kubernetes
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewer-binding
  namespace: team-namespace
subjects:
- kind: User
  name: user-viewer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view        # ClusterRole có sẵn, chỉ get/list/watch, không sửa xóa
  apiGroup: rbac.authorization.k8s.io
```

**Người 2: Quyền xem và sửa một số resource (Developer)**
```yaml
# Bước 1: Tạo Role với quyền hạn chế
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: team-namespace
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Không có "delete" — không được xóa
---
# Bước 2: Gán Role vào user
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: team-namespace
subjects:
- kind: User
  name: user-developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

**Người 3: Toàn quyền (SRE/Admin)**
```yaml
# Dùng ClusterRole "admin" có sẵn của Kubernetes
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-binding
  namespace: team-namespace
subjects:
- kind: User
  name: user-sre
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin    # Toàn quyền trong namespace, không xóa namespace chính nó
  apiGroup: rbac.authorization.k8s.io
```

**Kiểm tra quyền:**
```bash
kubectl auth can-i delete pods --namespace=team-namespace --as=user-viewer
# Kết quả: no

kubectl auth can-i create deployments --namespace=team-namespace --as=user-developer
# Kết quả: yes
```

---

**Câu 20:** Kubernetes xử lý như thế nào khi nhận yêu cầu tạo một tài nguyên? Mô tả toàn bộ quy trình từ lúc gọi `kubectl apply` cho đến khi Pod chạy.

**Trả lời:**
Quy trình đầy đủ:

```
kubectl apply -f pod.yaml
      |
      v
[1. Authentication] — API Server xác thực danh tính người dùng
      |              (certificate, token, OIDC)
      v
[2. Authorization (RBAC)] — Kiểm tra user có quyền tạo resource này không
      |                     Nếu không -> 403 Forbidden
      v
[3. Admission Controllers] — Chuỗi xử lý trước khi lưu vào etcd
      |   a. MutatingAdmissionWebhook: Có thể sửa đổi YAML (thêm label, inject sidecar)
      |   b. ValidatingAdmissionWebhook: Chỉ kiểm tra, nếu vi phạm -> từ chối
      |   c. ValidatingAdmissionPolicy (K8s 1.30+): CEL expression native
      |   d. OPA/Gatekeeper Webhook: Kiểm tra policy Rego
      |   => Nếu bị block -> 400 Bad Request kèm thông báo lý do
      v
[4. Lưu vào etcd] — Trạng thái mong muốn được lưu vào database
      v
[5. Scheduler] — Phân công Pod sẽ chạy trên Node nào
      |          (dựa vào resource, affinity, taints/tolerations)
      v
[6. Kubelet trên Node] — Nhận thông tin, gọi container runtime (containerd/docker)
      v
[7. Container Runtime] — Pull image, tạo container
      v
[8. Pod Running] — Pod đang chạy, kubelet báo cáo trạng thái lên API Server
```

---

**Câu 21:** `kubectl auth can-i` được dùng để làm gì? Nêu 3 tình huống thực tế hay dùng lệnh này.

**Trả lời:**
`kubectl auth can-i` là lệnh kiểm tra nhanh xem một user/service account có quyền thực hiện một hành động cụ thể không.

Cú pháp: `kubectl auth can-i <verb> <resource> [flags]`

3 tình huống thực tế:
```bash
# Tình huống 1: Debug khi deploy lỗi 403
# Hỏi xem CI pipeline (service account "ci-bot") có quyền deploy không
kubectl auth can-i create deployments \
  --namespace=production \
  --as=system:serviceaccount:ci:ci-bot
# Kết quả: yes / no

# Tình huống 2: Kiểm tra user trước khi cấp quyền
# Xác nhận user-viewer chỉ xem, không xóa được
kubectl auth can-i delete pods \
  --namespace=team-a \
  --as=user-viewer
# Kết quả: no

# Tình huống 3: Kiểm tra toàn bộ quyền của một account
kubectl auth can-i --list \
  --namespace=production \
  --as=system:serviceaccount:production:my-app
# Liệt kê tất cả các quyền mà service account này có
```

---

**Câu 22:** ServiceAccount trong Kubernetes là gì? Tại sao ứng dụng chạy trong Pod nên dùng ServiceAccount thay vì dùng username/password của con người?

**Trả lời:**

**ServiceAccount** là danh tính (identity) cho các process chạy trong Pod, giúp Pod giao tiếp với Kubernetes API Server.

Khi Pod cần đọc ConfigMap, tạo Job, gọi API Server -> cần có ServiceAccount với quyền phù hợp.

**Tại sao dùng ServiceAccount thay User account:**

| Lý do | Giải thích |
|---|---|
| Phân quyền gốc | User account dùng cho con người, ServiceAccount dùng cho machine/process |
| Scope hẹp | ServiceAccount nằm trong namespace, dễ quản lý phân quyền hạn hẹp |
| Tự động mount | Kubernetes tự động mount token vào Pod tại `/var/run/secrets/kubernetes.io/serviceaccount/` |
| Không lưu mật khẩu | ServiceAccount dùng short-lived token, không cần lưu password tĩnh |
| Tích hợp IRSA | Trên EKS, ServiceAccount có thể được map với IAM Role (IRSA) để truy cập AWS services |

Ví dụ sử dụng:
- ArgoCD cần đọc/ghi mọi tài nguyên -> ServiceAccount "argocd-server" với ClusterRole rộng
- Prometheus cần get/list Pod, ServiceMonitor -> ServiceAccount "prometheus" với Role giới hạn

---

## Phần 5: Admission Controllers và Policy Enforcement (W10 — Thứ 2)

**Câu 23:** Admission Controller là gì? Phân biệt giữa Mutating và Validating Admission Webhook.

**Trả lời:**

**Admission Controller** là các module xử lý yêu cầu API trên K8s sau khi Authentication và Authorization, trước khi lưu vào etcd.

| Loại | Mục đích | Có thể từ chối? | Ví dụ |
|---|---|---|---|
| **MutatingAdmissionWebhook** | Chỉnh sửa (mutate) request trước khi lưu | Có | Thêm sidecar tự động, thêm label default, inject envvar |
| **ValidatingAdmissionWebhook** | Chỉ kiểm tra (validate), không sửa | Có | Kiểm tra phải có label "owner", phải có resource limit |

Luồng xử lý:
```
Request -> [Mutating Webhooks] -> [Schema Validation] -> [Validating Webhooks] -> etcd
```

Mutating chạy trước Validating. Lý do: Webhook mutating có thể thêm trường bị thiếu trước khi validating kiểm tra sự tồn tại của trường đó.

OPA/Gatekeeper cài đủ 2 webhook: 1 auditing (chỉ ghi log) và 1 denying (chặn thẳng).
Kyverno cũng có cả mutation và validation policy.

---

**Câu 24:** OPA Gatekeeper và Kyverno khác nhau như thế nào? Khi nào nên chọn cái nào?

**Trả lời:**

| Tiêu chí | OPA / Gatekeeper | Kyverno |
|---|---|---|
| Ngôn ngữ policy | Rego (ngôn ngữ riêng biệt) | YAML thuần túy |
| Độ phức tạp | Cao, cần học Rego | Thấp, Kubernetes-native |
| Tính linh hoạt | Rất cao, viết được logic phức tạp | Vừa đủ cho phần lớn use case |
| Mutation | Hỗ trợ (OPA Mutation) | Hỗ trợ mạnh hơn |
| Generate resource | Không native | Có (tự động tạo NetworkPolicy khi tạo Namespace) |
| Community | Lớn, đã được sử dụng lâu | Đang phát triển, CNCF project |
| Khi chọn | Cần logic policy phức tạp, có team đã biết Rego | Team muốn bắt đầu nhanh, Kubernetes-native |

**Khuyến nghị cho người mới:** Bắt đầu với Kyverno (YAML-native, dễ hiểu). Khi cần logic phức tạp trên nhiều điều kiện, chuyển sang OPA/Gatekeeper.

---

**Câu 25:** Tạo resource đẩy lên bị Admission chặn lại do thiếu tag `owner`, giờ phải làm sao? Hãy mô tả luồng chạy của Admission Controller trong tình huống này.

**Trả lời:**

**Luồng chạy của Admission Controller:**
```
kubectl apply -f pod.yaml
      |
      v
API Server nhận request
      |
      v
[ValidatingAdmissionWebhook / Gatekeeper]
  -> Kiểm tra: Pod có label "owner" không?
  -> Kết quả: KHÔNG CÓ
  -> Phản hồi: 400 Bad Request
     "Resource Pod/my-pod is not allowed: Missing required label: owner"
      |
      v
Yêu cầu bị từ chối, KHÔNG được lưu vào etcd
```

**Cách xử lý:**
```yaml
# Bước 1: Xem thông báo lỗi chi tiết
kubectl apply -f pod.yaml
# Error: ... Missing required label: owner

# Bước 2: Thêm label "owner" vào manifest
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    owner: "team-backend"    # Thêm dòng này
    app: my-app
spec:
  containers: [...]

# Bước 3: Apply lại
kubectl apply -f pod.yaml
# Kết quả: pod/my-pod created
```

**Nếu urgently cần deploy mà chưa sửa kịp:**
- Nếu policy ở chế độ `audit`: Resource vẫn được tạo nhưng bị ghi log vi phạm
- Nếu policy ở chế độ `enforce`: Buộc phải sửa manifest trước
- Nếu cần exception: Phải liên hệ admin để tạo ExcludedNamespace hoặc tạo exception rule trong Constraint

---

**Câu 26:** ValidatingAdmissionPolicy (K8s 1.30+) là gì? Tại sao đây được xem là bước tiến lớn so với webhook bên ngoài?

**Trả lời:**

**ValidatingAdmissionPolicy** là giải pháp native của Kubernetes (từ phiên bản 1.30) để viết validation policy bằng CEL (Common Expression Language) trực tiếp trong cluster, không cần deploy thêm tool bên ngoài.

**Ví dụ policy bắt buộc phải có resource limits:**
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resource-limits
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >
      object.spec.containers.all(c,
        has(c.resources) &&
        has(c.resources.limits) &&
        has(c.resources.limits.cpu) &&
        has(c.resources.limits.memory)
      )
    message: "Mỗi container phải có resource limits (CPU và Memory)"
```

**Ưu điểm so với OPA/Gatekeeper webhook:**

| Tiêu chí | OPA/Gatekeeper (webhook) | ValidatingAdmissionPolicy (native) |
|---|---|---|
| Deploy thêm tool | Cần cài Gatekeeper (deployment, webhook cert) | Không cần, dùng thẳng với API Server |
| Hiệu năng | Mỗi request phải gọi qua HTTP webhook | Xử lý trong API Server, nhanh hơn |
| Dependency | Phụ thuộc webhook service có phải chạy | Không có điểm lỗi tùng ngoài (single point of failure) |
| Ngôn ngữ | Rego (phức tạp) | CEL (đơn giản, Kubernetes-native) |
| Tính tương thích | Luôn hỗ trợ | Chỉ từ K8s 1.30+ |

---

## Phần 6: Secrets Management và Supply Chain Security (W10 — Thứ 3)

**Câu 27:** AWS Secrets Manager và External Secrets Operator (ESO) phối hợp với nhau như thế nào? Vẽ sơ đồ luồng đồng bộ secret.

**Trả lời:**

**Luồng đồng bộ secret (ESO + AWS Secrets Manager):**
```
AWS Secrets Manager          External Secrets Operator       Kubernetes
(nguồn lưu trữ)              (bridge/controller)             (đích)

[DB_PASSWORD=abc123]  <---[IRSA Role để đọc]--- [ESO Controller]
                                                       |
                                               [ExternalSecret CRD]
                                               refreshInterval: 1m
                                                       |
                                                       v
                                               [Kubernetes Secret]
                                               (tự động cập nhật)
                                                       |
                                                       v
                                               [Pod mount Secret]
                                               (dùng như env var)
```

**Cấu hình ExternalSecret:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: production
spec:
  refreshInterval: 1m      # Đồng bộ lại mỗi 1 phút
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials    # Tên K8s Secret được tạo
  data:
  - secretKey: password     # Tên key trong K8s Secret
    remoteRef:
      key: prod/db          # Tên secret trong AWS SM
      property: password    # Property trong JSON của secret
```

**Lợi ích:** Khi admin đổi password trong AWS SM, ESO tự động cập nhật K8s Secret sau refreshInterval. Pod không cần restart (nếu dùng Volume mount thay env var).

---

**Câu 28:** Cosign là gì? Giải thích cơ chế ký số image và tại sao admission webhook cần xác thực chữ ký khi deploy.

**Trả lời:**

**Cosign** (thuộc dự án Sigstore) là công cụ để ký số (sign) và xác thực (verify) container image, giúp đảm bảo image đến từ nguồn đáng tin cậy và không bị sửa đổi.

**Cơ chế hoạt động:**
```
CI Pipeline                              Kubernetes Cluster

[Build Docker Image]
      |
      v
[Trivy Scan - OK]
      |
      v
[Cosign Sign Image]
  cosign sign --key cosign.key \         [Kyverno Policy - verifyImages]
    my-registry/my-app:v1.0                     |
      |                                kubectl apply -> [Admission Webhook]
      v                                         |
[Push Image + Signature]              Webhook gọi Cosign verify:
  ECR: my-app:v1.0 (image)             cosign verify --key cosign.pub \
  ECR: my-app:v1.0.sig (signature)       my-registry/my-app:v1.0
                                                  |
                                                  v
                                      [Chữ ký hợp lệ -> ALLOW]
                                      [Không có chữ ký -> DENY]
```

**Tại sao Admission Webhook cần xác thực:**
- Ngăn tin tặc kéo image độc hại từ DockerHub và deploy vào cluster
- Đảm bảo chỉ image đi qua CI pipeline (scan + sign) mới được chạy
- Zero-trust: Cluster không tin bất kỳ image nào chưa được xác minh nguồn gốc

---

**Câu 29:** 1 image không có nguồn gốc hay không kiểm soát thì gây ra vấn đề gì? Hãy liệt kê ít nhất 5 rủi ro bảo mật cụ thể.

**Trả lời:**

**5 rủi ro chính khi dùng image không kiểm soát:**

1. **Chứa mã độc (Malware/Backdoor):**
   Image từ DockerHub public có thể chứa sẵn malware, cryptominer, hoặc backdoor trong layer. Khi chạy, mã độc có quyền truy cập tài nguyên cluster và mạng nội bộ.

2. **Lỗ hổng bảo mật CVE (Common Vulnerabilities and Exposures):**
   Image có thể dùng các base image cũ (Ubuntu 18.04, Alpine 3.10) chưa được vá nhiều lỗ hổng bảo mật CVE mức độ CRITICAL. Kẻ tấn công có thể khai thác để chiếm quyền container hoặc thoát ra node.

3. **Supply Chain Attack:**
   Kẻ tấn công có thể chèn mã độc vào image của một thư viện phổ biến (typosquatting: "pytorch" ghi là "pytorchh"). Dev vô tình dùng image bị poisoned.

4. **Không biết tài sản mình đang chạy (Unknown Dependencies):**
   Không kiểm soát image nghĩa là không biết bên trong có gì. Có thể có:
   - Packages lỗi thời
   - License vi phạm (GPL trong commercial product)
   - Dữ liệu nhạy cảm hardcode (API key của nhà phát triển gốc)

5. **Container Escape — Quyền Root không cần thiết:**
   Nhiều image DockerHub mặc định chạy bằng user root và có thể yêu cầu quyền privileged. Nếu kẻ tấn công chiếm được process trong container, chúng có thể thoát ra Node và phá hỏng toàn bộ cluster.

6. **Không có audit trail — Không truy vết được:**
   Khi có sự cố, không thể xác định: Image đến từ đâu? Ai push lên? Khi nào? Đã qua kiểm tra bảo mật chưa? Đây là nightmare cho forensics sau sự cố.

---

**Câu 30:** K8s biết image đến từ registry của công ty bằng cách nào? Nêu cấu hình Kyverno để chỉ cho phép image từ registry nội bộ.

**Trả lời:**
Kubernetes **không mặc định biết** image đến từ đâu. Cần cấu hình Admission Policy để enforce.

**Cách K8s biết image từ registry công ty:**
Thông qua Admission Controller (Kyverno/Gatekeeper) kiểm tra field `image` trong Pod spec.

**Cấu hình Kyverno ClusterPolicy:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registry
spec:
  validationFailureAction: Enforce
  rules:
  - name: only-allow-internal-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Chỉ cho phép image từ registry nội bộ: registry.company.com"
      pattern:
        spec:
          containers:
          - image: "registry.company.com/*"
          # Tất cả container phải bắt đầu bằng registry.company.com/
```

**Kiểm soát thêm bằng ImagePullSecrets:**
```yaml
apiVersion: v1
kind: Pod
spec:
  imagePullSecrets:
  - name: internal-registry-secret  # Credentials để pull từ registry nội bộ
  containers:
  - image: registry.company.com/my-app:v1.0
```

**Kết hợp với xác thực chữ ký (Cosign):**
```yaml
# Kyverno VerifyImages: chỉ cho phép image từ registry công ty VÀ được ký số
rules:
- name: verify-image-signature
  match:
    resources:
      kinds: [Pod]
  verifyImages:
  - imageReferences:
    - "registry.company.com/*"      # Chỉ image từ registry nội bộ
    attestors:
    - entries:
      - keys:
          publicKeys: |-
            -----BEGIN PUBLIC KEY-----
            ... (public key của CI pipeline công ty)
            -----END PUBLIC KEY-----
```

---

**Câu 31:** Trivy là gì? Hãy giải thích cách tích hợp Trivy vào GitHub Actions pipeline và cấu hình để fail CI khi phát hiện lỗ hổng CRITICAL.

**Trả lời:**

**Trivy** là công cụ quét bảo mật mã nguồn mở (Aqua Security) quét lỗ hổng (CVE) trong:
- Container images
- File system / repository
- Kubernetes cluster config
- Infrastructure as Code (Terraform, CloudFormation)

**Tích hợp vào GitHub Actions:**
```yaml
# .github/workflows/ci.yaml
name: CI Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Build Docker Image
      run: docker build -t my-app:${{ github.sha }} .

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'my-app:${{ github.sha }}'
        format: 'table'
        exit-code: '1'           # Fail CI khi phát hiện lỗ hổng
        ignore-unfixed: true     # Bỏ qua CVE chưa có patch
        vuln-type: 'os,library'  # Quét cả OS và thư viện
        severity: 'CRITICAL,HIGH'  # Chỉ fail ở mức CRITICAL và HIGH
```

**Khi Trivy phát hiện CVE CRITICAL:**
- CI fail, không push image lên registry
- Báo cáo ghi rõ: CVE ID, mô tả, gói ảnh hưởng, phiên bản vá
- Developer cần: update base image hoặc update package bị lỗ hổng

**Exception CVE:** Nếu CVE chưa có fix, phải viết ADR (Architecture Decision Record) ghi rõ: CVE gì, lý do chưa vá được, kế hoạch vá khi có patch, được quản lý phê duyệt.

---

**Câu 32:** SLSA Framework là gì? Giải thích các cấp độ (levels) và ý nghĩa thực tế của việc đạt Level 2.

**Trả lời:**

**SLSA (Supply-chain Levels for Software Artifacts)** là bộ tiêu chuẩn đánh giá độ an toàn của chuỗi cung ứng phần mềm (software supply chain). Tăng cấp = Tăng chứng minh nguồn gốc code.

| Cấp độ | Tên | Yêu cầu chính |
|---|---|---|
| SLSA 1 | Build | Build process được tự động hóa, tạo ra provenance (biên bản nguồn gốc) |
| SLSA 2 | Signed | Provenance được ký số, lưu trữ được, build service tin tưởng được |
| SLSA 3 | Hardened | Build service không thể sửa đổi provenance, chống giả mạo nguồn gốc |
| SLSA 4 | (Legacy) | 2-party review cho mọi thay đổi |

**Ý nghĩa đạt Level 2 trong thực tế:**
- CI pipeline tự động build image (không build tay trên laptop dev)
- Provenance (metadata bao gồm: ai build, khi nào, từ commit nào) được ký số bằng Cosign
- Bất kỳ ai cũng có thể xác minh: image này được build từ commit X, lúc Y, bởi CI pipeline Z
- Chống tấn công "malicious maintainer": Ngay cả khi người có quyền push repo muốn chèn code xấu, lịch sử provenance vẫn được ghi lại

**Trong W10 lab:** Ký image bằng Cosign sau khi Trivy scan (đạt SLSA 2 chính xác khi ký + push provenance).

---

## Phần 7: Platform Integration và Resource Management (W10 — Thứ 4)

**Câu 33:** ResourceQuota và LimitRange khác nhau như thế nào? Hãy nêu tình huống thực tế cần cả hai.

**Trả lời:**

| Tiêu chí | ResourceQuota | LimitRange |
|---|---|---|
| Phạm vi | Giới hạn TỔNG tài nguyên cả namespace | Giới hạn min/max/default từng Container/Pod |
| Mục đích | Ngăn một team chiếm hết tài nguyên cluster | Đảm bảo mỗi container khai báo đúng resource |
| Ví dụ | namespace không được dùng quá 10 CPU | Mỗi container phải có limit >= 100m CPU |

**Tình huống cần cả hai:**

Ví dụ: Cluster có 3 team, mỗi team có namespace riêng.

ResourceQuota (giới hạn team):
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "4"      # Tổng CPU request không quá 4 core
    requests.memory: 8Gi   # Tổng memory request không quá 8GB
    limits.cpu: "8"        # Tổng CPU limit không quá 8 core
    pods: "20"             # Tối đa 20 pods
```

LimitRange (buộc quốc container):
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-a
spec:
  limits:
  - type: Container
    default:               # Giá trị mặc định nếu dev không khai báo
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:                   # Giới hạn tối đa một container
      cpu: "2"
      memory: "2Gi"
```

Nếu chỉ có ResourceQuota mà không có LimitRange: Dev tạo Pod không khai báo resource -> ResourceQuota không tính Pod này vào quota (vì nó ở mức 0) -> Có thể tạo vô hạn Pod không limit -> Noisy neighbor attack.

---

**Câu 34:** Chaos Engineering là gì? Tại sao lại có ý tưởng cố ý gây ra lỗi trong hệ thống đang chạy? Nêu 2 công cụ phổ biến và các loại thử nghiệm.

**Trả lời:**

**Chaos Engineering** là kỷ luật thử nghiệm độ bền của hệ thống bằng cách cố ý gây ra các lỗi kiểm soát trong môi trường giống production, nhằm phát hiện các điểm yếu trước khi chúng xảy ra thực sự.

Triết lý: "Nếu hệ thống sẽ gặp lỗi, tốt hơn là nên giả lập lỗi trong điều kiện kiểm soát để tìm và sửa, hơn là để lỗi xảy ra bất ngờ lúc 2 giờ sáng."

**2 công cụ phổ biến:**

1. **LitmusChaos (CNCF):**
   - Kubernetes-native, có UI Dashboard
   - Các loại thử nghiệm: kill pod, shut down node, network delay, disk fill
   - Define experiment bằng YAML (ChaosEngine)

2. **Chaos Mesh:**
   - Cũng Kubernetes-native, giao diện web đẹp hơn
   - Hỗ trợ: NetworkChaos (delay, loss), PodChaos (kill, failure), HTTPChaos (inject lỗi 5xx), DNSChaos

**Các loại thử nghiệm hay dùng:**
- **Pod Kill:** Xóa ngẫu nhiên một pod để test high availability
- **Network Delay:** Thêm latency giữa 2 service để test timeout handling
- **CPU Stress:** Tăng tải CPU để test autoscaling
- **Node Drain:** Drain một node để test pod rescheduling
- **Network Partition:** Cắt đứt kết nối giữa 2 namespace để test circuit breaker

---

**Câu 35:** AWS Cost Anomaly Detection là gì? Giải thích cách nó làm việc và tại sao quan trọng trong vận hành Cloud.

**Trả lời:**

**AWS Cost Anomaly Detection** là dịch vụ sử dụng Machine Learning để giám sát chi phí AWS hàng ngày, phát hiện và gửi cảnh báo tự động khi có bất thường về chi phí.

**Cơ chế hoạt động:**
1. AWS thu thập dữ liệu chi phí theo ngày cho từng service
2. ML model học pattern chi phí "bình thường" (mùa, ngày trong tuần, sự kiện release...)
3. Khi chi phí vượt qua ngưỡng bất thường so với model -> Tạo "anomaly"
4. Gửi cảnh báo qua email/SNS

**Cấu hình cơ bản:**
- Tạo Monitor: Theo dõi AWS services (toàn bộ hoặc cụ thể), Linked Account, Cost Category
- Tạo Alert: Ngưỡng $ (ví dụ: bất thường > $20), tần suất gửi (immediate, daily, weekly)
- Nhận báo cáo với: Service nào tăng, tăng bao nhiêu, nguyên nhân có thể

**Tại sao quan trọng:**
- EKS cluster có thể autoscale vô kiểm nếu cấu hình sai -> hóa đơn tăng đột biến
- Một EC2 developer quên tắt có thể tốn hàng trăm USD
- S3 bucket bị cấu hình sai -> data egress phí không lồ

**Thực hành tốt:** Kết hợp với AWS Budgets (hard limit) + Cost Anomaly Detection (cảnh báo mềm). Budget chặn, Anomaly báo sớm.

---

## Phần 8: AWS Security Foundation (W10 — Thứ 5/6 Review)

**Câu 36:** Shared Responsibility Model của AWS là gì? Phân tích rõ trách nhiệm của AWS và của khách hàng khi sử dụng EKS.

**Trả lời:**

**Shared Responsibility Model:** AWS chịu trách nhiệm bảo mật "của Cloud" (security OF the cloud), khách hàng chịu trách nhiệm bảo mật "trong Cloud" (security IN the cloud).

| Trách nhiệm | AWS | Khách hàng (khi dùng EKS) |
|---|---|---|
| Phần cứng vật lý | Data center, server, network switch | Không |
| Hypervisor / Virtualization | Quản lý EC2 instance | Không |
| EKS Control Plane | Quản lý, vá, scale master node | Không |
| OS của Worker Node | Không (trừ Fargate) | Phải vá OS, bảo mật kubelet |
| Container Runtime | Không | Phải cập nhật containerd |
| Container Image | Không | Phải scan và ký số image |
| K8s RBAC | Không | Phải cấu hình Role/RoleBinding |
| Network (VPC, SG) | Cung cấp API | Phải cấu hình SG, NACL, NetworkPolicy |
| IAM | Cung cấp hệ thống | Phải cấu hình User, Role, Policy đúng |
| Dữ liệu ứng dụng | Không | Phải mã hóa, backup, quản lý |

**Với EKS Fargate:** AWS quản lý thêm Worker Node OS, khách hàng chỉ quản lý container và trên.

---

**Câu 37:** IRSA (IAM Roles for Service Accounts) là gì? Tại sao đây tốt hơn việc nhúng AWS Access Key trực tiếp vào Pod?

**Trả lời:**

**IRSA** là cơ chế cho phép map trực tiếp một AWS IAM Role với một Kubernetes Service Account thông qua OIDC (OpenID Connect) provider của EKS.

**Tại sao tốt hơn Access Key trong Pod:**

| Tiêu chí | Hardcode Access Key | IRSA |
|---|---|---|
| Bảo mật | Rất kém — key bị lộ là bị tấn công | Tốt — không có key nào để bị lộ |
| Rotation | Phải manual đổi key và cập nhật Secret | Tự động — token được renew tự động |
| Audit | Khó truy vết action nào của service nào | CloudTrail ghi rõ: action X bởi SA Y trong Pod Z |
| Scope | Key thậm chí có quyền lớn, khó giới hạn | Mỗi SA chỉ có Role nhỏ nhất cần thiết |
| Incident | Phải invalidate key gấp, tốn thời gian | Xóa RoleBinding là cut quyền ngay |

**Cơ chế IRSA:**
```
Pod (ServiceAccount: my-sa)
  -> projected token (aud: sts.amazonaws.com)
  -> gọi AWS STS: AssumeRoleWithWebIdentity
  -> STS xác thực với EKS OIDC Provider
  -> Trả về temporary credentials (15 phút - 1 giờ)
  -> Pod dùng credentials này gọi AWS API
```

---

**Câu 38:** Pod Security Standards (PSS) trong Kubernetes có 3 mức độ là gì? Nêu cấu hình container hardening cho mức Restricted.

**Trả lời:**

**3 mức độ Pod Security Standards:**

| Mức độ | Mô tả | Use case |
|---|---|---|
| **Privileged** | Không có giới hạn, toàn quyền | System-level workload (CNI, storage driver) |
| **Baseline** | Ngăn các leo thang quyền rõ ràng | General-purpose workload |
| **Restricted** | Thực hành bảo mật cao nhất | Production, sensitive workload |

**Cấu hình Container Hardening cho mức Restricted:**
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true        # Cấm chạy bằng user root
    runAsUser: 1000           # Chạy bằng user ID cụ thể
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault    # Bật seccomp filter
  containers:
  - name: app
    image: my-app:v1
    securityContext:
      allowPrivilegeEscalation: false  # Cấm leo thang quyền
      readOnlyRootFilesystem: true     # Hệ thống file chỉ đọc
      capabilities:
        drop:
        - ALL                          # Bỏ tất cả Linux capabilities
        add:
        - NET_BIND_SERVICE             # Chỉ thêm nếu thực sự cần
    resources:                         # Bắt buộc khai báo resource
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

---

**Câu 39:** NetworkPolicy trong Kubernetes là gì? Viết YAML cho phép chỉ Pod frontend giao tiếp với Pod backend, cấm tất cả traffic khác.

**Trả lời:**

**NetworkPolicy** là tài nguyên Kubernetes định nghĩa các quy tắc cho phép hoặc từ chối traffic mạng giữa các Pod. Mặc định K8s cho phép mọi Pod giao tiếp với mọi Pod (open).

**Cấu hình NetworkPolicy:**
```yaml
# Policy 1: Backend chỉ nhận traffic từ frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-from-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend           # Áp dụng cho Pod có label app=backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend      # Chỉ cho phép traffic từ Pod frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database      # Backend được phép gọi database
    ports:
    - protocol: TCP
      port: 5432
  - to:                      # Cho phép DNS resolution
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53

---
# Policy 2: Frontend chỉ được gọi backend, không gọi gì khác
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress-only-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
```

**Lưu ý:** NetworkPolicy chỉ hoạt động khi CNI plugin hỗ trợ (Calico, Cilium, Weave). Flannel không hỗ trợ NetworkPolicy.

---

**Câu 40:** AWS GuardDuty là gì? Liệt kê 5 loại mối đe dọa mà GuardDuty có thể phát hiện trong môi trường EKS.

**Trả lời:**

**AWS GuardDuty** là dịch vụ phát hiện mối đe dọa quản lý (managed threat detection), sử dụng ML và intelligence để phân tích CloudTrail, VPC Flow Logs, DNS Logs và EKS Audit Logs để phát hiện hành vi bất thường.

**5 loại mối đe dọa GuardDuty phát hiện trong EKS:**

1. **Cryptocurrency Mining (CryptoCurrency:Runtime/BitcoinTool.B):**
   Pod đang chạy binary liên quan đến tiền ảo, kết nối đến mining pool. Dấu hiệu: CPU cao bất thường, outbound kết nối đến IP mining pool.

2. **Privileged Container Launched (Policy:Kubernetes/PrivilegedContainer):**
   Ai đó tạo container với `privileged: true` — có thể là bước đầu của container escape attack.

3. **Exposed Kubernetes Dashboard (Policy:Kubernetes/ExposedDashboard):**
   Kubernetes Dashboard bị expose ra internet không có authentication.

4. **Unusual Kubernetes API calls (Discovery:Kubernetes/MaliciousIPCaller):**
   API call đến từ IP address bị biết là độc hại (C2 server, Tor exit node).

5. **Anonymous User Access (Policy:Kubernetes/AnonymousAccessGranted):**
   Ai đó đã cấp ClusterRoleBinding cho `system:anonymous` user — toàn bộ cluster bị expose không cần xác thực.

---

## Phần 9: Incident Response (W10 — Thứ 5/6)

**Câu 41:** Mô tả quy trình ứng phó sự cố bảo mật 6 bước của AWS (AWS IR Playbook). Áp dụng vào tình huống: phát hiện 1 Pod trong K8s cluster đang chạy cryptocurrency miner.

**Trả lời:**

**6 bước AWS Incident Response:**

**Bước 1 — DETECT (Phát hiện):**
- GuardDuty phát hiện: `CryptoCurrency:Runtime/BitcoinTool.B` trên Pod `worker-abc`
- Prometheus alert: CPU usage của Pod đạt 95% bất thường
- -> Tạo Incident ticket, phân công SRE trực

**Bước 2 — TRIAGE (Đánh giá):**
- Xác định: Pod nào? Namespace nào? Node nào?
- Mức độ: Pod đã leo thang quyền chưa? Đã lan sang Pod khác chưa?
- Thu thập evidence:
  ```bash
  kubectl describe pod worker-abc -n production
  kubectl logs worker-abc -n production --previous
  kubectl exec worker-abc -- ps aux  # Xem process đang chạy
  ```

**Bước 3 — CONTAIN (Cô lập):**
```bash
# Bước 3a: Tách Pod khỏi Service (dừng nhận traffic từ user)
kubectl label pod worker-abc app-  # Xóa label -> Service không route đến nữa

# Bước 3b: Áp dụng NetworkPolicy cô lập Pod
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-compromised-pod
spec:
  podSelector:
    matchLabels:
      kubernetes.io/pod-name: worker-abc
  policyTypes: [Ingress, Egress]
  # Không có ingress/egress rules = cấm tất cả traffic
EOF
```

**Bước 4 — ERADICATE (Loại bỏ):**
- Sau khi thu thập đủ bằng chứng:
  ```bash
  kubectl delete pod worker-abc -n production
  # Xóa image bị nhiễm khỏi ECR
  ```
- Xác định nguồn gốc: Image từ đâu? Ai push? Bao giờ?

**Bước 5 — RECOVER (Phục hồi):**
- Chạy lại GitOps pipeline để deploy lại phiên bản sạch:
  `argocd app sync production-api`
- Xác nhận hệ thống hoạt động bình thường
- Restore service traffic

**Bước 6 — POST-MORTEM (Rút kinh nghiệm):**
- Viết báo cáo: nguyên nhân gốc rễ (root cause), thời gian ảnh hưởng, các bước đã làm
- Cập nhật Runbook với bước cải tiến
- Implement fix: Thêm Admission Policy cấm image không có chữ ký, thêm NetworkPolicy, cập nhật Trivy threshold

---

**Câu 42:** Tại sao nên xóa nhãn (remove label) của Pod bị hack thay vì xóa ngay Pod đó? Giải thích chiến lược forensics này.

**Trả lời:**

**Khi xóa Pod ngay lập tức:**
- Mất hết bằng chứng: process đang chạy, kết nối mạng, file trong container filesystem
- Không thể phân tích: Mã độc hoạt động như thế nào? Đã khai thác lỗ hổng nào? Đã xâm nhập sâu đến đâu?
- Vi phạm quy trình forensics: Có thể cần bằng chứng cho pháp lý hoặc bảo hiểm

**Chiến lược forensics — Xóa nhãn trước:**
```bash
# Bước 1: Xóa label app khỏi Pod -> Service không route traffic đến nữa
kubectl label pod compromised-pod app-

# Giờ Pod vẫn chạy nhưng không còn nhận traffic user
# Service selector không khớp -> traffic bị cắt

# Bước 2: Cô lập mạng bằng NetworkPolicy
# Pod vẫn chạy, SRE có thể exec vào để thu thập bằng chứng

# Bước 3: Thu thập bằng chứng
kubectl exec compromised-pod -- cat /proc/1/cmdline    # Process chính
kubectl exec compromised-pod -- netstat -tulnp          # Kết nối mạng
kubectl exec compromised-pod -- ls -la /tmp             # File đáng ngờ
kubectl cp compromised-pod:/tmp/suspicious-binary .     # Copy file độc

# Bước 4: Sau khi thu thập xong -> mới xóa Pod
kubectl delete pod compromised-pod
```

Đây là nguyên tắc "cô lập trước, điều tra sau, tiêu hủy cuối cùng" — giống như cảnh sát phong tỏa hiện trường trước khi di chuyển bằng chứng.

---

**Câu 43:** EventBridge + Lambda có thể dùng để tự động ứng phó sự cố bảo mật (auto-remediation) như thế nào? Mô tả một luồng cụ thể.

**Trả lời:**

**Luồng Auto-Remediation:**
```
GuardDuty phát hiện mối đe dọa
      |
      v
EventBridge Rule
  Pattern: {"source": ["aws.guardduty"], "detail-type": ["GuardDuty Finding"]}
      |
      v
Lambda Function (auto-remediation)
      |
  [Logic phân loại theo severity và type]
      |
      |-> UnauthorizedAPICall.* -> Revoke IAM credentials
      |-> CryptoCurrency:Runtime -> Isolate EC2 instance (change SG)
      |-> K8s.Privileged -> Call K8s API to delete pod
      |-> Exfiltration.* -> Block S3 bucket public access
      |
      v
Notification SNS/Slack: "Auto-remediation executed for finding XYZ"
      |
      v
Security team review và confirm (con người kiểm tra sau)
```

**Ví dụ Lambda cho EC2 isolation:**
```python
def lambda_handler(event, context):
    finding = event['detail']
    instance_id = finding['resource']['instanceDetails']['instanceId']

    ec2 = boto3.client('ec2')

    # 1. Thay đổi SG của instance sang SG isolation
    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=['sg-isolation-id']  # SG có sẵn, không cho phép gì cả
    )

    # 2. Chụp EBS snapshot trước khi tắt
    ec2.create_snapshot(
        VolumeId=get_root_volume(instance_id),
        Description=f'Forensics snapshot - GuardDuty finding {finding["id"]}'
    )

    # 3. Gửi thông báo
    sns.publish(TopicArn='...', Message=f'Instance {instance_id} isolated')
```

---

**Câu 44:** Runbook là gì? Hãy viết một runbook mẫu theo chuẩn SRE Google cho tình huống: Canary rollout tự động abort và rollback.

**Trả lời:**

**Runbook** là tài liệu hướng dẫn từng bước xử lý sự cố cụ thể, giúp SRE on-call hành động nhanh và chính xác ngay cả lúc 3 giờ sáng.

---

**RUNBOOK: Canary Rollout Auto-Abort**

**Severity:** P2 (Medium)

**Thời gian xử lý dự kiến:** 15-30 phút

**Triệu chứng (Symptoms):**
- Alert: `Canary Rollout Aborted` trong Grafana/PagerDuty
- Argo Rollouts Dashboard hiển thị trạng thái `Aborted`
- Email cảnh báo SLO từ Alertmanager

**Nguyên nhân có thể (Possible Causes):**
- Phiên bản mới có bug gây lỗi 5xx
- Phiên bản mới có hiệu năng kém gây tăng latency
- AnalysisTemplate query sai, báo false positive

**Bước xử lý:**

Bước 1: Xác nhận trạng thái (5 phút)
```bash
# Xem trạng thái rollout
kubectl argo rollouts get rollout api -n production --watch

# Xem chi tiết sự cố phân tích
kubectl describe analysisrun -n production | grep -A5 "Status"

# Xem log của phiên bản mới
kubectl logs -l app=api,rollouts-pod-template-hash=<canary-hash> -n production
```

Bước 2: Xác nhận rollback thành công (5 phút)
```bash
# Kiểm tra 100% traffic về phiên bản cũ
kubectl argo rollouts get rollout api -n production
# => Canary weight: 0, Stable: 100%

# Kiểm tra error rate về bình thường
# Mở Grafana dashboard API Success Rate
```

Bước 3: Phân tích nguyên nhân (10 phút)
```bash
# Xem metric tại thời điểm abort
# Grafana: query flask_http_request_total trong khoảng thời gian rollout
```

Bước 4: Báo cáo và update ticket
- Ghi nhận: thời gian abort, nguyên nhân, ảnh hưởng thực tế (% user bị lỗi x phút)
- Thông báo cho PM/Dev team

---

## Phần 10: Tổng hợp và Kết nối Kiến Thức

**Câu 45:** Vẽ sơ đồ hoặc mô tả luồng đầy đủ khi Developer push code mới cho đến khi Pod chạy trong production, bao gồm: CI pipeline, Cosign, ArgoCD, Admission Controller, ESO.

**Trả lời:**
Luồng đầy đủ (tham khảo sơ đồ sequence trong w10_relationship_and_integration.md):

```
DEVELOPER
  | push code + YAML
  v
GITHUB CI PIPELINE
  |-> Quét mã nguồn (GitGuardian/Trivy — quét repo)
  |-> Build Docker Image
  |-> Trivy Image Scan (quét CVE trong image)
  |   [FAIL nếu có CVE CRITICAL] -> Báo cáo, Developer sửa
  |-> Cosign Sign Image (ký số bằng private key của CI)
  |-> Push Image + Signature (.sig) lên AWS ECR
  |-> Cập nhật image tag trong Git repo (gitops/k8s/app.yaml)
  |
  v
GIT REPOSITORY (trạng thái mong muốn mới)
  |
ARGOCD (phát hiện diff giữa Git và cluster)
  |-> Auto-sync (apply YAML mới)
  |
  v
EKS API SERVER
  |-> [1] Authentication: Xác thực ArgoCD ServiceAccount
  |-> [2] Authorization (RBAC): ArgoCD có quyền tạo/cập nhật resource?
  |-> [3] Admission Controllers:
  |     - Gatekeeper: Kiểm tra có label "owner" không, có resource limits không
  |     - ValidatingAdmissionPolicy: Có chạy root không, có allowPrivilegeEscalation không
  |     - Kyverno: Xác thực chữ ký Cosign của image
  |       [FAIL nếu image không có chữ ký] -> DENY, ArgoCD sync fail
  |-> [4] Lưu vào etcd
  |
  v
SCHEDULER: Chọn Node phù hợp
  |
  v
KUBELET trên Node: Pull image, tạo container
  |
  v
POD RUNNING
  |-> External Secrets Operator đồng bộ Secret từ AWS Secrets Manager
  |-> Pod nhận được DB_PASSWORD từ K8s Secret (không hardcode)
  |
  v
MONITORING
  - Prometheus scrape metrics từ Pod
  - Grafana hiển thị dashboard
  - Alertmanager gửi cảnh báo khi SLO bị vi phạm
```

---

**Câu 46:** Nếu có 6 rủi ro bảo mật phổ biến trong một EKS cluster, bạn sẽ xử lý từng rủi ro bằng gì? (Theo nội dung Lab W10)

**Trả lời:**

| Rủi ro | Giải pháp |
|---|---|
| **Risk 1: Lộ Credentials tĩnh** | Xóa Access Key khỏi Pod. Dùng IRSA (IAM Roles for ServiceAccount) + AWS Secrets Manager + ESO để inject credentials động, tự động rotation < 60s |
| **Risk 2: Pod chạy Root / Privileged** | Enforce Pod Security Standards (Restricted) bằng ValidatingAdmissionPolicy hoặc Gatekeeper. Bật `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false` |
| **Risk 3: Không giới hạn tài nguyên** | Triển khai ResourceQuota giới hạn tổng CPU/Memory/Pod mỗi namespace. Thêm LimitRange gán giá trị mặc định và giới hạn max mỗi container |
| **Risk 4: Không có lát mạng** | Triển khai NetworkPolicy chỉ cho phép các kết nối cần thiết. Default deny all, rồi chỉ whitelist tường minh |
| **Risk 5: Image CVE & Không rõ nguồn gốc** | Thêm Trivy scan trong CI pipeline (fail on CRITICAL). Ký số image bằng Cosign. Cấu hình Kyverno ClusterPolicy chỉ cho phép image từ registry nội bộ và đã được ký số |
| **Risk 6: Không có IR process** | Viết Runbook cho các sự cố phổ biến. Thực hành 6-step AWS IR. Cấu hình EventBridge + Lambda auto-remediation cho sự cố tự cập nhật |

---

**Câu 47:** Audit mode và Enforce mode của Gatekeeper khác nhau như thế nào? Khi nào nên dùng mỗi chế độ?

**Trả lời:**

| Tiêu chí | Audit mode | Enforce mode |
|---|---|---|
| Hành động khi vi phạm | Chỉ ghi log, resource vẫn được tạo | Từ chối request, resource không được tạo |
| Ảnh hưởng đến production | Không | Có — mọi resource vi phạm sẽ bị chặn |
| Phạm vi quét | Cả resource đã tồn tại và resource mới | Chỉ resource mới tạo/cập nhật |
| Kết quả | Báo cáo danh sách vi phạm (compliance report) | Bắt buộc tuân thủ chính sách ngay |

**Khi nên dùng Audit mode:**
- Khi vừa triển khai policy mới cho cluster đang chạy (legacy resources có thể vi phạm)
- Khi muốn đo lường phạm vi ảnh hưởng trước khi bật enforce
- Khi cần thời gian để team dev cập nhật tất cả manifest trước khi enforce

**Khi nên dùng Enforce mode:**
- Khi đã chạy audit đủ lâu và đã sửa hết vi phạm
- Cho cluster mới (greenfield) — bật enforce ngay từ đầu
- Cho các policy bảo mật quan trọng (không chạy root, phải có resource limit)

**Best practice:** Bắt đầu với `audit`, quét báo cáo vi phạm, thông báo cho team, đặt thời hạn sửa, sau đó chuyển sang `enforce`.

---

**Câu 48:** Giải thích cơ chế "Defense in Depth" (Phòng thủ chiều sâu) trong Kubernetes security. Nêu các lớp bảo vệ.

**Trả lời:**

**Defense in Depth** là chiến lược bảo mật sử dụng nhiều lớp bảo vệ độc lập, sao cho nếu một lớp bị vỡ, còn các lớp khác vẫn bảo vệ hệ thống.

**Các lớp bảo vệ trong K8s:**
```
TẦNG 1: AWS Layer
  - IAM Least Privilege (quy tắc quyền tối thiểu)
  - SCP chặn hành động nguy hiểm trên AWS Organizations
  - VPC Security Group, NACL
  - GuardDuty phát hiện mối đe dọa

TẦNG 2: Cluster Layer
  - RBAC: Phân quyền chỉ người cần biết
  - Admission Controllers: Chặn resource vi phạm policy
  - Pod Security Standards: Enforced at namespace level
  - NetworkPolicy: Lát mạng giữa Pod

TẦNG 3: Workload Layer
  - Container chạy non-root
  - readOnlyRootFilesystem
  - Drop all Linux capabilities
  - Resource limits (ngăn crypto miner)

TẦNG 4: Supply Chain Layer
  - Trivy scan image CVE
  - Cosign ký số image
  - Admission verify signature
  - Secrets không hardcode (IRSA + ESO)

TẦNG 5: Runtime / Detection Layer
  - Prometheus + Grafana giám sát bất thường
  - EKS Audit Logs -> CloudWatch
  - GuardDuty EKS runtime monitoring
  - Alertmanager gửi cảnh báo

TẦNG 6: Response Layer
  - Runbook / Playbook sẵn sàng
  - EventBridge + Lambda auto-remediation
  - Chaos Engineering đã test trước
```

Kẻ tấn công phải phá cả 6 lớp — khổi việc cực kỳ khó.

---

**Câu 49:** So sánh Sealed Secrets và External Secrets Operator (ESO). Khi nào nên dùng mỗi giải pháp?

**Trả lời:**

| Tiêu chí | Sealed Secrets | External Secrets Operator (ESO) |
|---|---|---|
| Nguồn secret | Mã hóa local và lưu trong Git | Lấy từ external provider (AWS SM, Vault...) |
| Lưu trữ | File .yaml mã hóa commit lên Git | Không lưu secret trong Git |
| Rotation | Phải mã hóa lại và commit mới khi đổi secret | Tự động lấy phiên bản mới từ provider |
| Dependency | Chỉ cần kubeseal CLI và controller | Cần external secret store (AWS SM, HashiCorp Vault) |
| GitOps friendly | Rất cao — secret ở trong Git (đã mã hóa) | Tốt — nhưng secret không ở trong Git |
| Audit trail | Thay đổi được track trong Git | Thay đổi được track trong AWS SM / Vault |
| Use case | Nhóm nhỏ, không có secret manager riêng | Doanh nghiệp, đã có AWS SM / Vault |

**Khi dùng Sealed Secrets:**
- Team nhỏ, không có budget cho AWS Secrets Manager
- Muốn secret (đã mã hóa) nằm trong Git để quản lý cùng manifest
- Rotation ít khi thay đổi

**Khi dùng ESO:**
- Đã có AWS Secrets Manager / HashiCorp Vault
- Cần auto-rotation mà không restart Pod
- Compliance yêu cầu secret không được lưu trong Git dù đã mã hóa

---

**Câu 50:** Nếu phải xây dựng một "Mini Platform" end-to-end cho team sử dụng K8s, bạn sẽ lấy các thành phần gì từ W9 và W10? Giải thích lý do chọn mỗi thành phần.

**Trả lời:**

**Mini Platform End-to-End:**

**1. GitOps — ArgoCD (W9)**
- Lý do: Mọi thay đổi phải qua Git, có audit trail, rollback dễ dàng
- Cấu hình: App-of-Apps pattern quản lý tất cả thành phần

**2. Observability Stack — Prometheus + Grafana + Loki (W9)**
- Lý do: Phải nhìn thấy hệ thống đang chạy như thế nào, alert khi có vấn đề
- Cấu hình: SLO 95% success rate, burn rate alert, dashboard tự động

**3. Progressive Delivery — Argo Rollouts + Canary (W9)**
- Lý do: Mỗi deploy có rủi ro, cần kiểm tra ở % nhỏ trước, auto-abort nếu lỗi
- Cấu hình: Canary 25%, AnalysisTemplate query Prometheus, failureLimit: 3

**4. Access Control — RBAC (W10-D1)**
- Lý do: Mỗi người chỉ có quyền cần thiết, ngăn leo thang quyền
- Cấu hình: Role developer/sre/viewer với phạm vi namespace rõ ràng

**5. Policy Enforcement — Kyverno / Gatekeeper (W10-D1)**
- Lý do: Bắt buộc bảo mật ở cluster level, không phụ thuộc vào cam kết developer
- Cấu hình: Bắt buộc resource limits, cấm chạy root, yêu cầu label owner

**6. Secrets Management — ESO + AWS Secrets Manager (W10-D2)**
- Lý do: Không hardcode credentials, tự động rotation, audit trail
- Cấu hình: ExternalSecret refresh 1 phút, IRSA cho ESO

**7. Supply Chain Security — Trivy + Cosign + Kyverno verifyImages (W10-D2)**
- Lý do: Ngăn image độc hại và image không rõ nguồn gốc vào cluster
- Cấu hình: Trivy fail on CRITICAL trong CI, Cosign sign, Kyverno only allow signed image từ registry nội bộ

**8. Resource Management — ResourceQuota + LimitRange (W10-D3)**
- Lý do: Ngăn noisy neighbor, ngăn crypto miner chiếm hết tài nguyên
- Cấu hình: Quota mỗi namespace, LimitRange gán default limits

**9. Network Security — NetworkPolicy (W10-D2/Live)**
- Lý do: Default deny all, chỉ cho phép kết nối cần thiết
- Cấu hình: Frontend -> Backend -> Database, cấm tất cả còn lại

**10. Incident Response — Runbook + EventBridge + Lambda (W10-D3)**
- Lý do: Khi có sự cố cần hành động nhanh, có thể tự động hóa ứng phó
- Cấu hình: Runbook cho 5 sự cố phổ biến, auto-isolate khi GuardDuty alert

---

*Tài liệu này được tổng hợp từ kiến thức W9 (GitOps, Observability, Canary) và W10 (RBAC, Admission Policy, Secrets, Supply Chain Security, Platform Integration, Incident Response). Sử dụng để tự kiểm tra kiến thức trước Capstone W11-W12.*
