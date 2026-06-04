Docker là gì
Bốn khái niệm
    Image: bản đóng gói chỉ-đọc chứa ứng dụng và mọi thứ nó cần để chạy. Hình dung image như một "khuôn" hoặc bản thiết kế.
    Container: một bản đang chạy của image. Từ một image có thể tạo ra nhiều container giống nhau. Image là khuôn, container là sản phẩm đúc ra từ khuôn đó.
    Registry: kho chứa image để tải lên và tải về. Phổ biến nhất là Docker Hub. Bạn pull (kéo) image về từ registry, hoặc push (đẩy) image của mình lên.
    Dockerfile: một file văn bản mô tả cách dựng image — cài gì, copy gì, chạy lệnh nào. Bạn viết Dockerfile rồi build ra image.

Vòng đời cơ bản: viết Dockerfile → build ra image → run image thành container → có thể push image lên registry để máy khác dùng.