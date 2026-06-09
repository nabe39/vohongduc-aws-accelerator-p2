## SLI và SLO là gì? (Mục tiêu & Chỉ số)

    Đây là hai khái niệm cốt lõi trong SRE (Site Reliability Engineering) dùng để định nghĩa và đo lường độ tin cậy của dịch vụ.
    
    SLI (Service Level Indicator) — Chỉ số mức độ dịch vụ
    Khái niệm: Là chỉ số thực tế đo lường hiệu năng của dịch vụ tại một thời điểm. Nó là câu trả lời cho câu hỏi: "Hệ thống hiện tại đang chạy tốt ra sao?
    
    SLO (Service Level Objective) — Mục tiêu mức độ dịch vụ
    Khái niệm: Là mục tiêu hay cái ngưỡng (target) mà bạn mong muốn SLI của mình phải đạt được trong một khoảng thời gian (ví dụ: 30 ngày). Nó là câu trả lời cho câu hỏi: "Hệ thống cần đạt mức độ tốt tối thiểu là bao nhiêu?


    
    Mối quan hệ: Bạn theo dõi SLI để đảm bảo nó không vi phạm cam kết của SLO.

## A) OpenTelemetry là:

    Một khung và bộ công cụ quan sát được thiết kế để hỗ trợ
        Việc tạo                 (Generation)
        Việc xuất                (Export)
        Việc thu thập            (Collection)

    Dữ liệu đo từ xa như dấu vết (traces), số liệu (metrics) và nhật ký (logs).

    Mã nguồn mở, cũng như không phụ thuộc vào nhà cung cấp và công cụ, có nghĩa là nó có thể được sử dụng với nhiều hệ thống quan sát khác nhau, bao gồm các công cụ mã nguồn mở như Jaeger và Prometheus, cũng như các sản phẩm thương mại. Bản thân OpenTelemetry không phải là một hệ thống quan sát.

    Mục tiêu chính của OpenTelemetry là cho phép dễ dàng đo lường các ứng dụng và hệ thống của bạn, bất kể ngôn ngữ lập trình, cơ sở hạ tầng và môi trường thời gian chạy được sử dụng.

    Phần xử lý dữ liệu (lưu trữ) và phần hiển thị (trực quan hóa) được cố ý để cho các công cụ khác đảm nhiệm.

Khả năng quan sát là gì? (observability)

    Khả năng quan sát là khả năng hiểu được trạng thái bên trong của một hệ thống bằng cách kiểm tra các đầu ra của nó.

    Trong phần mềm, điều này thường đạt được bằng cách phân tích dữ liệu đo từ xa như dấu vết, số liệu và nhật ký.

    Để làm cho một hệ thống có thể quan sát được, nó phải được trang bị công cụ đo lường (instrumented). Nghĩa là, mã phải phát ra các dấu vết, số liệu hoặc nhật ký. Dữ liệu đã được trang bị sau đó phải được gửi đến một hệ thống phụ trợ quan sát.

OTel SDK + Collector hoạt động như thế nào?

    Để mang dữ liệu từ ứng dụng của bạn về hệ thống phân tích, OpenTelemetry chia làm hai thành phần chính: SDK (nằm trong ứng dụng) và Collector (một con proxy trung gian đứng độc lập).

OTel SDK (Software Development Kit)

    Nhiệm vụ: Được tích hợp trực tiếp vào mã nguồn ứng dụng của bạn (qua thư viện Java, Node.js, Go, Python...).

    Chức năng: Nó chịu trách nhiệm thu thập (Collect) các dữ liệu tự động (như HTTP request, database query) hoặc dữ liệu do bạn tự cấu hình (custom metrics) ngay bên trong ứng dụng, sau đó chuyển đổi chúng thành định dạng chuẩn của OpenTelemetry (OTLP) để gửi ra ngoài.

OTel Collector

    Nhiệm vụ: Là một dịch vụ proxy chạy độc lập (thường chạy như một container riêng bên cạnh ứng dụng - Sidecar hoặc Cluster service).

    Chức năng: Nó tiếp nhận dữ liệu từ OTel SDK gửi sang, xử lý nó rồi đẩy về các backend lưu trữ. Nó hoạt động theo mô hình đường ống (Pipeline)


## B) Prometheus là gì?

    Prometheus là một bộ công cụ giám sát và cảnh báo hệ thống mã nguồn mở.

    Prometheus thu thập và lưu trữ các chỉ số của nó dưới dạng dữ liệu chuỗi thời gian, tức là thông tin chỉ số được lưu trữ cùng với dấu thời gian tại thời điểm ghi lại, cùng với các cặp khóa-giá trị tùy chọn được gọi là nhãn.

Các tính năng chính của Prometheus bao gồm:

    Mô hình dữ liệu đa chiều với dữ liệu chuỗi thời gian được xác định bằng tên chỉ số và các cặp khóa/giá trị

    PromQL, một ngôn ngữ truy vấn linh hoạt để tận dụng chiều dữ liệu này

    Không phụ thuộc vào lưu trữ phân tán; các nút máy chủ đơn lẻ hoạt động độc lập

    Việc thu thập dữ liệu chuỗi thời gian được thực hiện thông qua mô hình kéo (pull model) qua HTTP

    Việc đẩy dữ liệu chuỗi thời gian được hỗ trợ thông qua cổng trung gian

    Các mục tiêu được phát hiện thông qua khám phá dịch vụ hoặc cấu hình tĩnh

    Hỗ trợ nhiều chế độ vẽ đồ thị và bảng điều khiển

Số liệu thống kê là gì?  (Metrics)

    Theo cách hiểu đơn giản, số liệu thống kê là các phép đo bằng số. Thuật ngữ chuỗi thời gian đề cập đến việc ghi lại các thay đổi theo thời gian. Những gì người dùng muốn đo lường sẽ khác nhau tùy thuộc vào ứng dụng.

Khi nào thì nên sử dụng?

    Prometheus hoạt động tốt để ghi lại bất kỳ chuỗi thời gian thuần túy dạng số nào -> theo hướng giám sát. 

    Trong thế giới của các dịch vụ vi mô, khả năng hỗ trợ thu thập và truy vấn dữ liệu đa chiều (multi-dimensional data collection and querying) là một thế mạnh đặc biệt của nó.

    Thiết kế để hoạt động đáng tin cậy, trở thành hệ thống bạn có thể sử dụng trong trường hợp xảy ra sự cố để nhanh chóng chẩn đoán vấn đề

    Bạn có thể dựa vào nó khi các phần khác của cơ sở hạ tầng bị lỗi, và bạn không cần phải thiết lập cơ sở hạ tầng phức tạp để sử dụng nó.

Khi nào thì nó không phù hợp?

    Nếu bạn cần độ chính xác 100%, chẳng hạn như để tính phí theo từng yêu cầu, Prometheus không phải là lựa chọn tốt vì dữ liệu thu thập được có thể không đủ chi tiết và đầy đủ.


## C) Grafana là gì?

    Grafana cho phép bạn truy vấn, trực quan hóa, thiết lập cảnh báo và khám phá các chỉ số, nhật ký và dấu vết của mình bất kể chúng được lưu trữ ở đâu.

    VD: Cơ sở dữ liệu chuỗi thời gian như Prometheus và CloudWatch, các công cụ ghi nhật ký như Loki và Elasticsearch, cơ sở dữ liệu NoSQL/SQL như Postgres, công cụ CI/CD như GitHub,.... Grafana OSS cung cấp cho bạn các công cụ để hiển thị dữ liệu đó trên bảng điều khiển trực tiếp với các biểu đồ và hình ảnh trực quan đầy đủ thông tin

Grafana Loki là gì?

    Khác với các hệ thống ghi nhật ký khác, Loki được xây dựng dựa trên ý tưởng chỉ lập chỉ mục siêu dữ liệu (index metadata) về nhãn nhật ký của bạn (logs’ labels) (giống như nhãn của Prometheus). Dữ liệu nhật ký sau đó được nén và lưu trữ thành từng khối trong các kho lưu trữ đối tượng như Amazon Simple Storage Service (S3) hoặc Google Cloud Storage (GCS), hoặc thậm chí cục bộ trên hệ thống tệp.

## D) Phân biệt

    Nhóm Thu thập và Chuẩn hóa dữ liệu: OTel SDK + Collector.

    Nhóm Lưu trữ và Hiển thị dữ liệu: Prometheus + Loki + Grafana.

## Hệ thống Thu thập và Quản lý Dữ liệu Giám sát (Observability Stack)

| Công cụ / Khái niệm | Dữ liệu chính | Vai trò trong hệ thống | Ví dụ thực tế |
| :--- | :--- | :--- | :--- |
| **OTel SDK** | Traces, Metrics, Logs | **Thu thập & Tạo dữ liệu** từ bên trong mã nguồn ứng dụng. | *Đo xem hàm `login()` mất bao lâu để chạy và xuất ra định dạng chuẩn OTLP.* |
| **OTel Collector** | Traces, Metrics, Logs | **Thu gom, Xử lý trung gian & Điều hướng** dữ liệu từ ứng dụng ra bên ngoài. | *Gom dữ liệu từ 100 microservices, lọc bỏ thông tin nhạy cảm (token/password), rồi chia luồng gửi đi.* |
| **Prometheus** | **Metrics** (Chuỗi thời gian) | **Lưu trữ & Truy vấn** các thông số đo lường dạng số. | *Lưu trữ tỷ lệ CPU sử dụng, số lượng request/giây, tỷ lệ lỗi HTTP 500.* |
| **Loki** | **Logs** (Nhật ký) | **Lưu trữ & Truy vấn** văn bản nhật ký hệ thống (Log lines). | *Lưu lại dòng chữ nhật ký: `User 'admin' failed to login at 10:00:00`.* |
| **Grafana** | Tất cả | **Trực quan hóa (Dashboard)** dữ liệu và cấu hình cảnh báo (Alerting). | *Vẽ biểu đồ đường thẳng hiển thị lượng CPU tăng giảm, hiển thị bảng hiển thị các dòng Logs lỗi màu đỏ.* |
### Luồng Di Chuyển Của Dữ Liệu (Architecture Workflow)

```mermaid
graph TD
    %% Định nghĩa các Block chính
    APP[" Ứng dụng của bạn"]
    SDK[" OTel SDK <br><i>(Thu thập & Chuẩn hóa bên trong App)</i>"]
    COLLECTOR[" OTel Collector <br><i>(Nhận -> Lọc & Xử lý -> Phân loại)</i>"]
    
    %% Cơ sở dữ liệu
    PROMETHEUS[(" Prometheus <br><i>(Lưu trữ Metrics)</i>")]
    LOKI[(" Loki <br><i>(Lưu trữ Logs)</i>")]
    
    %% Hiển thị
    GRAFANA[" Grafana <br><i>(Dashboard trực quan hóa)</i>"]
    USER[" Người vận hành hệ thống"]

    %% Luồng kết nối dữ liệu
    APP -->|Tự động thu thập| SDK
    SDK -->|Đẩy dữ liệu chuẩn OTLP| COLLECTOR
    
    COLLECTOR -->|Phân loại: Metrics| PROMETHEUS
    COLLECTOR -->|Phân loại: Logs| LOKI
    
    PROMETHEUS -.->|Grafana kết nối lấy data| GRAFANA
    LOKI -.->|Grafana kết nối lấy data| GRAFANA
    
    GRAFANA -->|Theo dõi & Giám sát| USER

    %% Định nghĩa màu sắc cho sơ đồ (Style)
    style APP fill:#0000,stroke:#333,stroke-width:2px
    style SDK fill:#000,stroke:#0288d1,stroke-width:2px
    style COLLECTOR fill:#000,stroke:#f57c00,stroke-width:2px
    style PROMETHEUS fill:#000,stroke:#d32f2f,stroke-width:2px
    style LOKI fill:#000,stroke:#388e3c,stroke-width:2px
    style GRAFANA fill:#000,stroke:#7b1fa2,stroke-width:2px
    style USER fill:#000,stroke:#455a64,stroke-width:2px