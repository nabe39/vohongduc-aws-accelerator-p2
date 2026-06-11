# README — Tổng hợp kiến thức cơ bản cho T2, T3, T4 của W9

Tài liệu này tổng hợp các khái niệm cốt lõi xuất hiện trong lịch học W9, tập trung vào ba mảng: **GitOps & CI/CD** ở T2, **Observability — SLO/SLI/OTel** ở T3, và **Progressive Delivery (Canary)** ở T4. Theo thông báo tuần W9, mục tiêu cuối tuần là đưa cluster từ cách vận hành thủ công sang mô hình GitOps-managed, có observability stack để đo SLO và burn rate, đồng thời triển khai canary có khả năng auto-abort khi metric xấu.

## Nội dung theo ngày

| Ngày | Chủ đề chính | Các ý quan trọng |
|---|---|---|
| T2 | GitOps & CI/CD | GitHub Actions, plan-on-PR, apply-on-merge, ArgoCD vs Flux, app-of-apps, sync waves, rollback bằng `git revert` và `kubectl rollout undo`. |
| T3 | Observability | OpenTelemetry SDK và Collector, Prometheus, Grafana, Loki, SLO/SLI, burn rate alert nhiều cửa sổ thời gian. |
| T4 | Progressive Delivery (Canary) | Argo Rollouts, Rollout CRD, AnalysisTemplate, Prometheus query, abort criteria, tích hợp burn rate để tự động dừng rollout xấu. |

## T2 — GitOps & CI/CD

### GitOps là gì

GitOps là cách vận hành hạ tầng và ứng dụng mà trong đó Git được xem là **nguồn sự thật duy nhất** cho trạng thái mong muốn của hệ thống. Trong lịch W9, GitOps được gắn trực tiếp với ArgoCD hoặc Flux để đồng bộ cấu hình từ Git xuống Kubernetes thay vì apply manifest thủ công.

OpenGitOps mô tả GitOps dựa trên các nguyên tắc như hệ thống phải được mô tả bằng declarative, trạng thái mong muốn được lưu trong hệ thống versioned và approved, thay đổi được pull tự động vào môi trường, và phần mềm agent liên tục đảm bảo trạng thái thực tế khớp trạng thái mong muốn.[web:2]

### CI/CD trong bối cảnh bài học này

Trong thông báo W9, CI/CD được thể hiện theo hướng `plan-on-PR` và `apply-on-merge`, nghĩa là khi mở pull request thì hệ thống kiểm tra hoặc dựng kế hoạch thay đổi, còn khi merge thì mới áp dụng vào môi trường. Cách làm này giúp tách rõ giai đoạn kiểm chứng thay đổi với giai đoạn phát hành, đồng thời giảm rủi ro đẩy cấu hình lỗi lên cluster.

GitHub Actions là nền tảng automation của GitHub để tạo workflow build, test, và deploy theo sự kiện trong repository như push, pull request, hoặc merge vào nhánh chính. Trong bài lab W9, đây là mắt xích CI quan trọng trước khi ArgoCD thực hiện phần CD/GitOps.

### ArgoCD, Flux, app-of-apps, sync waves, rollback

ArgoCD là công cụ Continuous Delivery dựa trên GitOps cho Kubernetes, có khả năng theo dõi repository Git, phát hiện độ lệch giữa trạng thái trong Git và trạng thái thật trong cluster, rồi đồng bộ lại về trạng thái mong muốn.[web:2][web:3] Flux cũng là một lựa chọn GitOps thay thế ArgoCD trong cùng hệ sinh thái cloud-native.

Mô hình **app-of-apps** trong ArgoCD thường được dùng để quản lý nhiều ứng dụng con hoặc nhiều thành phần của hệ thống từ một ứng dụng cha; điều này phù hợp với mục tiêu “GitOps-ify platform” vì có thể tách app, infra, monitoring thành nhiều lớp quản lý. **Sync waves** là kỹ thuật sắp xếp thứ tự đồng bộ tài nguyên để những thành phần nền tảng được apply trước và workload phụ thuộc được apply sau, giúp quá trình rollout ổn định hơn trong hệ thống nhiều thành phần.

Có hai hướng rollback được nhắc trong lịch học: `git revert` và `kubectl rollout undo`. `git revert` phù hợp với tinh thần GitOps hơn vì trạng thái mong muốn trong Git cũng được đưa về phiên bản an toàn; còn `kubectl rollout undo` tác động trực tiếp lên cluster và có thể làm trạng thái thật tạm thời lệch khỏi Git nếu chưa cập nhật lại repository.

### Tài liệu và video tiếng Việt nên xem

- Video: [ArgoCD & Cách sử dụng | CD GitOps cho Kubernetes](https://www.youtube.com/watch?v=Vtv9Jmc1XBQ) — giới thiệu ArgoCD, cách cài, truy cập tool và deploy demo.[web:2]
- Video: [Setup ArgoCD để tự động hoá quy trình triển khai ứng dụng trên Kubernetes (GitOps)](https://www.youtube.com/watch?v=xy1WFAY0qH8) — có demo setup ArgoCD và repo mẫu để làm theo.[web:3]
- Video: [Kubernetes CICD – triển khai ứng dụng trên Kubernetes với Argo CD](https://www.youtube.com/watch?v=LrS6MgrrTlE) — đi gần hơn vào bài lab CI/CD + ArgoCD trên Kubernetes.[web:5]
- Docs chính thống: [ArgoCD Docs](https://argo-cd.readthedocs.io), [GitHub Actions Docs](https://docs.github.com/en/actions), [Flux Docs](https://fluxcd.io/flux), [OpenGitOps](https://opengitops.dev).

### Lab gợi ý cho T2

1. Tạo một repo chứa manifest Kubernetes hoặc Helm/Kustomize cho ứng dụng mẫu.
2. Viết GitHub Actions để chạy kiểm tra khi có PR và chỉ cho phép merge khi pass.
3. Cài ArgoCD lên Minikube hoặc cluster cá nhân, kết nối repo Git và tạo Application để auto-sync.
4. Thử sửa image tag hoặc replica trong Git rồi quan sát ArgoCD đồng bộ thay đổi.
5. Thử rollback bằng `git revert` và so sánh với `kubectl rollout undo` để hiểu khác biệt GitOps.

## T3 — Observability: SLO, SLI, OpenTelemetry, Prometheus, Grafana, Loki

### Observability là gì

Observability là khả năng hiểu được trạng thái bên trong của hệ thống thông qua các tín hiệu như metrics, logs và traces. Trong lịch W9, phần T3 nêu rõ bộ stack học gồm OpenTelemetry SDK + Collector, Prometheus + Grafana + Loki, cùng phương pháp SLO để đo availability và latency.

OpenTelemetry là framework observability mã nguồn mở, trung lập nhà cung cấp, cho phép instrument ứng dụng để thu thập metrics, logs, traces và gửi dữ liệu telemetry sang các backend phân tích khác nhau. Khi dùng chung với Grafana stack, luồng phổ biến là instrument ứng dụng bằng OTel, chuyển dữ liệu qua Collector hoặc pipeline tương đương, sau đó đưa metrics vào backend tương thích Prometheus, logs vào Loki, và trực quan hóa trên Grafana.

### SLI và SLO

**SLI** là chỉ số đo chất lượng dịch vụ, ví dụ tỉ lệ request thành công hoặc độ trễ p95; còn **SLO** là mục tiêu mong muốn đặt ra cho các chỉ số đó, ví dụ 99.9% request thành công trong 30 ngày. Trong W9, phương pháp SLO tập trung vào hai khía cạnh availability và latency.

Google SRE mô tả SLO như nền tảng để cân bằng giữa tốc độ phát triển và độ ổn định hệ thống; khi dịch vụ tiêu tốn quá nhanh “error budget”, đội ngũ phải giảm thay đổi rủi ro và tập trung cải thiện độ tin cậy. Đây chính là nền tảng để phần T4 tích hợp canary với burn rate nhằm tự động dừng rollout khi chất lượng suy giảm.

### OpenTelemetry SDK và Collector

OTel SDK là thư viện được nhúng vào ứng dụng để phát sinh telemetry như trace, metric, log. OTel Collector đóng vai trò bộ thu gom và trung chuyển, giúp tách phần instrument ứng dụng khỏi phần routing, xử lý và export dữ liệu đi các backend quan sát khác nhau.

Trong thực tế lab, có thể hình dung luồng cơ bản như sau: ứng dụng phát telemetry bằng OTel, Collector nhận dữ liệu OTLP, sau đó metrics được Prometheus scrape hoặc receive, logs được đẩy sang Loki, và dashboard hiển thị trên Grafana.

### Prometheus, Grafana, Loki

Prometheus là hệ thống monitoring và alerting mã nguồn mở, chuyên thu thập và lưu metrics dạng time-series. Grafana là công cụ dashboard và trực quan hóa dữ liệu, thường dùng để đọc dữ liệu từ Prometheus và hiển thị thành biểu đồ, panel, và cảnh báo.

Loki là hệ thống log aggregation được thiết kế theo triết lý gần với Prometheus nhưng dành cho logs, giúp gom log từ nhiều service để tìm kiếm và phân tích tập trung.Bộ ba Prometheus + Grafana + Loki vì vậy rất hợp cho bài lab nền tảng observability cơ bản: metrics để đo sức khỏe, logs để tra lỗi, dashboard để quan sát tổng thể.

### Burn rate alert nhiều cửa sổ thời gian

Thông báo W9 nêu rõ kiểu alert nhiều cửa sổ thời gian: fast 1h × 5min và slow 6h × 30min. Ý tưởng của burn rate là đo tốc độ tiêu hao error budget; nếu tốc độ này quá cao trong cửa sổ ngắn và dài, hệ thống có thể phát hiện cả sự cố bùng phát nhanh lẫn suy giảm kéo dài.

Mô hình multi-window burn-rate alert được dùng nhiều trong thực hành SRE vì nó giảm nhiễu hơn so với chỉ nhìn một ngưỡng metric đơn giản. Nó cũng đặc biệt phù hợp để làm tín hiệu đầu vào cho cơ chế auto-abort ở canary rollout.

### Tài liệu và video tiếng Việt nên xem

- Docs chính thống: [OpenTelemetry Docs](https://opentelemetry.io/docs), [Prometheus Docs](https://prometheus.io/docs), [Grafana Docs](https://grafana.com/docs/grafana/latest), [Loki Docs](https://grafana.com/docs/loki/latest), [Google SRE Book — SLO chapter](https://sre.google/sre-book/service-level-objectives), [Implementing SLOs](https://sre.google/workbook/implementing-slos), [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos).
- Tài liệu dễ hình dung pipeline OTel → Prometheus/Grafana: [OpenTelemetry: Export to Prometheus and Grafana](https://opentelemetry.io/docs/languages/dotnet/metrics/getting-started-prometheus-grafana/).
- Tài liệu mô tả OTel và cách ingest vào Grafana stack: [Grafana OpenTelemetry Docs](https://grafana.com/docs/opentelemetry/).
- Vì kết quả tìm kiếm video tiếng Việt cho OTel/Grafana/Loki còn rời rạc, nên ưu tiên đọc docs chính thống trước rồi mới tìm video theo từng công cụ riêng lẻ như “Prometheus tiếng Việt”, “Grafana tiếng Việt”, “OpenTelemetry tiếng Việt”.

### Lab gợi ý cho T3

1. Chạy Prometheus, Grafana và Loki bằng Docker Compose hoặc trên Kubernetes.
2. Instrument một service demo bằng OpenTelemetry SDK để phát metric cơ bản như request count, error count, latency histogram.
3. Cấu hình Collector hoặc exporter để đẩy metric sang Prometheus-compatible backend và log sang Loki.
4. Tạo dashboard Grafana hiển thị availability, latency p95, request rate và error rate.
5. Viết rule burn rate đơn giản cho một SLO availability, rồi kiểm tra alert khi tạo lỗi giả lập bằng load test.

## T4 — Progressive Delivery (Canary)

### Progressive Delivery là gì

Progressive Delivery là cách phát hành phiên bản mới theo từng bước nhỏ thay vì tung ngay cho toàn bộ người dùng. Trong lịch W9, phần này được triển khai qua chiến lược canary bằng Argo Rollouts, có AnalysisTemplate, Prometheus query, abort criteria và gắn với burn rate.

CNCF xem progressive delivery là nhóm kỹ thuật mở rộng từ continuous delivery nhằm kiểm soát rủi ro phát hành bằng cách phát hành dần, đo tín hiệu hệ thống hoặc hành vi người dùng, rồi quyết định promote hoặc rollback. Argo Rollouts là một công cụ rất phù hợp cho mô hình đó trong Kubernetes.

### Canary là gì

Canary deployment là chiến lược chỉ đưa một phần nhỏ traffic sang phiên bản mới trước để kiểm tra chất lượng. Nếu metric ổn thì tăng dần tỉ lệ traffic; nếu metric xấu thì dừng hoặc rollback sớm, nhờ vậy giảm blast radius khi phát hành lỗi.

Argo Rollouts cung cấp controller và CRD để triển khai các chiến lược nâng cao như canary, blue-green, phân bổ traffic theo trọng số, và phân tích metric tự động trong lúc rollout.

### Rollout CRD, AnalysisTemplate, abort criteria

**Rollout CRD** là tài nguyên Kubernetes thay cho Deployment truyền thống khi dùng Argo Rollouts; nó cho phép mô tả các bước tăng traffic, tạm dừng, kiểm tra metric và hành vi promote/abort.**AnalysisTemplate** định nghĩa cách lấy và đánh giá metric, ví dụ query Prometheus để đo error rate hoặc latency trong lúc rollout.

**Abort criteria** là điều kiện dừng rollout khi metric vượt ngưỡng xấu, chẳng hạn error rate tăng cao hoặc burn rate vượt ngưỡng SLO. Khi kết hợp với dữ liệu Prometheus và logic burn rate từ T3, canary không chỉ rollout “từ từ” mà còn tự bảo vệ bằng cách auto-abort khi ảnh hưởng người dùng bắt đầu tăng.
### Tài liệu và video nên xem

- Docs chính thống: [Argo Rollouts Docs](https://argoproj.github.io/argo-rollouts), [Canary feature docs](https://argo-rollouts.readthedocs.io/en/stable/features/canary/), [Flagger Docs](https://flagger.app), bài viết [CNCF về progressive delivery](https://www.cncf.io/blog/2024/01/26/progressive-delivery/).
- Nguồn chính thống dễ đọc nhất cho phần này vẫn là docs Argo Rollouts vì mô tả rõ controller, CRD, chiến lược canary và phân tích metric tự động.
- Với video tiếng Việt, kết quả phù hợp trực tiếp cho Argo Rollouts/Canary còn ít hơn ArgoCD; cách học hiệu quả là xem video ArgoCD/GitOps để hiểu nền phát hành trên Kubernetes trước, sau đó đọc docs Argo Rollouts để làm lab.

### Lab gợi ý cho T4

1. Cài Argo Rollouts vào cluster và chuyển một Deployment mẫu sang Rollout CRD.
2. Cấu hình canary theo nhiều bước, ví dụ 10% → 30% → 50% → 100%, có pause giữa các bước để quan sát metric.
3. Tạo AnalysisTemplate dùng Prometheus query để đo error rate hoặc latency p95 của phiên bản mới.
4. Cấu hình abort criteria khi error rate hoặc burn rate vượt ngưỡng.
5. Sinh tải bằng k6 hoặc Vegeta để mô phỏng traffic thật và xác nhận rollout tốt được promote, rollout xấu bị abort.

## Bộ lab tổng hợp nên làm cuối tuần

Theo thông báo W9, lab chính là “GitOps-ify W8 platform + bolt-on observability + canary”. Có thể triển khai theo chuỗi sau:

1. Đưa toàn bộ manifest ứng dụng W8 vào Git repo có cấu trúc `day-a`, `day-b`, `day-c`, `lab` như lịch gợi ý.
2. Cài ArgoCD để cluster tự đồng bộ từ Git thay vì apply tay.[web:2]
3. Gắn observability stack gồm OTel, Prometheus, Grafana, Loki để đo availability và latency.
4. Thiết lập SLO và burn rate alert làm tín hiệu đánh giá chất lượng phát hành.
5. Dùng Argo Rollouts để rollout canary và auto-abort nếu metric xấu hoặc burn rate vượt ngưỡng.
6. Dùng k6 hoặc Vegeta để load test trong lúc rollout nhằm tạo dữ liệu thật cho dashboard và analysis.
## Tài nguyên tham khảo nhanh

| Nhóm | Tài nguyên | Gợi ý dùng |
|---|---|---|
| GitOps | [ArgoCD Docs](https://argo-cd.readthedocs.io) | Học cài đặt, Application, sync, app-of-apps. |
| GitOps | [Video ArgoCD tiếng Việt](https://www.youtube.com/watch?v=Vtv9Jmc1XBQ) | Hợp để xem nhanh demo từ đầu đến cuối.|
| CI/CD | [GitHub Actions Docs](https://docs.github.com/en/actions) | Viết workflow kiểm tra PR và deploy theo merge. |
| Observability | [OpenTelemetry Docs](https://opentelemetry.io/docs) | Hiểu telemetry, SDK, Collector. |
| Metrics | [Prometheus Docs](https://prometheus.io/docs) | Thu thập metrics, alerting rule. |
| Dashboard | [Grafana Docs](https://grafana.com/docs/grafana/latest) | Vẽ dashboard và cảnh báo. |
| Logs | [Loki Docs](https://grafana.com/docs/loki/latest) | Gom log tập trung. |
| SLO | [Google SRE Book — SLO](https://sre.google/sre-book/service-level-objectives) | Hiểu SLI, SLO, error budget. |
| Canary | [Argo Rollouts Docs](https://argoproj.github.io/argo-rollouts) | Tạo Rollout, AnalysisTemplate, canary. |
| Load test | [k6 Docs](https://k6.io/docs) / [Vegeta](https://github.com/tsenart/vegeta) | Tạo tải cho lab observability và canary. |

## Kết luận thực hành

Nếu học theo đúng trục của W9 thì thứ tự hợp lý là: hiểu GitOps trước, quan sát hệ thống bằng observability sau, rồi mới làm progressive delivery. Ba phần này liên kết rất chặt: GitOps giúp phát hành có kiểm soát, observability tạo tín hiệu đo chất lượng, còn canary dùng chính tín hiệu đó để quyết định có nên tiếp tục rollout hay dừng lại.
