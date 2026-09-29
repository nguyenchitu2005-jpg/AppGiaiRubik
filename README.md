# AppGiaiRubik

App Android (Flutter/Dart) hướng dẫn giải Rubik 3x3:

- Mô hình **3D** khối Rubik, kéo để xoay, có animation từng bước
- **Nhập trạng thái khối** bằng cách tô màu trên sơ đồ 2D hoặc **quét 6 mặt bằng camera**
- Hai chế độ giải: **Học** (phương pháp tầng cho người mới, 7 giai đoạn có giải thích) và **Giải nhanh** (Kociemba, khoảng 20 bước)

## Tiến độ

| Tuần | Nội dung | Trạng thái |
|---|---|---|
| 1 | Phần lõi xử lý khối (54 ô màu, phép xoay, biểu diễn góc/cạnh) | Xong |
| 2 | Vẽ khối 3D bằng `CustomPainter` | Xong |
| 3 | Animation xoay tầng và sơ đồ 2D để nhập màu | Xong |
| 4 | Kiểm tra khối hợp lệ và chế độ Giải nhanh (Kociemba) | Xong |
| 5–6 | Chế độ Học (phương pháp tầng) | Xong |
| 7 | Màn hình hướng dẫn giải và thư viện công thức | Xong |
| 8–9 | Quét camera và nhận diện màu | Xong (cần thử trên máy thật) |
| 10 | Hoàn thiện, build bản phát hành | |

## Chạy dự án

```bash
flutter pub get
flutter run          # cần máy Android hoặc máy ảo
flutter test         # chạy toàn bộ test
```

## Cấu trúc thư mục

```
lib/
  core/cube/          phần lõi: trạng thái khối, phép xoay, xáo trộn, kiểm tra hợp lệ
  core/vision/        xử lý ảnh: đọc màu từ camera, phân loại màu, ghép 6 mặt
  core/solver/        bộ giải: Kociemba (package cuber) và phương pháp tầng cho người mới
  features/viewer3d/  vẽ khối 3D
  features/home/      màn hình chính
  features/input/     màn hình nhập màu (tô trên sơ đồ 2D hoặc khối 3D)
  features/guide/     màn hình hướng dẫn: chế độ Học / Giải nhanh, mũi tên chỉ hướng xoay
  features/library/   thư viện công thức kèm minh hoạ
  features/scanner/   quét 6 mặt bằng camera
  shared/             bảng màu và widget dùng chung (sơ đồ 2D)
  state/              quản lý trạng thái (Riverpod)
test/                 unit test và widget test
```
