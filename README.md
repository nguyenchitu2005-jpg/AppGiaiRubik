# AppGiaiRubik

App Android (Flutter/Dart) hướng dẫn giải Rubik 3x3:

- Mô hình **3D** khối Rubik, kéo để xoay, có animation từng bước
- **Nhập trạng thái khối** bằng cách tô màu trên sơ đồ 2D hoặc **quét 6 mặt bằng camera** (tự chụp khi nhận rõ màu)
- Chọn **trình độ**:
  - **Newbie**: *Phương pháp tầng (Layer by Layer)*, 7 giai đoạn với 7 **công thức cơ bản**, có giải thích từng bước
  - **Pro**: *CFOP (phương pháp Fridrich)*, gồm Cross → F2L → OLL → PLL với **công thức nâng cao** (41 F2L + 57 OLL + 21 PLL), khoảng 60 nước
  - **Master**: *Phương pháp ZB (Zborowski–Bruchem)*, gồm Cross → F2L 3 cặp → **ZBLS** (302) → **ZBLL** (472), khoảng 52 nước
- **Giải nhanh**: lời giải ngắn nhất do máy tính tìm (Kociemba, khoảng 20 nước)
- **Giải cùng camera** 🎙️: quét 6 mặt, app **đọc to từng nước** ("R phẩy", "U hai"…) và hiện công thức trên màn hình; camera nhìn mặt trước của khối để biết bạn đã xoay xong, rồi đọc nước tiếp. Xoay nhầm thì app nhận ra và chỉ cách sửa; có bấm giờ, chế độ đọc 3 nước một lần cho người giải nhanh
- **Gợi ý 💡**: bấm bóng đèn trên khối 3D để xem bước tiếp theo và công thức cần dùng (theo trình độ đã chọn), hoặc để app xoay giúp
- **Menu** (góc trái trên):
  - **Ký hiệu & cách xoay** cho người mới: bấm từng ký hiệu (U, R', F2, M, r, x…) để xem khối 3D chỉ hướng rồi xoay, kèm bài luyện đoán ký hiệu
  - **Luyện tập**: chọn bộ công thức (F2L, OLL, PLL, ZBLS, ZBLL) và các trường hợp muốn tập, bấm giờ từng lần, xem đáp án và trường hợp giải chậm nhất
  - **Hẹn giờ giải** kiểu thi đấu: giữ–thả–chạm hoặc phím cách, quan sát 15 giây theo WCA (+2/DNF), thống kê tốt nhất / Ao5 / Ao12 / trung bình, lịch sử lưu trên máy
  - **Công thức xáo trộn**: chuẩn WCA (trạng thái ngẫu nhiên), nhanh 25 nước, luyện OLL / PLL / ZBLL (có đáp án); sao chép, dùng cho khối 3D hoặc bấm giờ
- **Thư viện công thức** chia 3 phần Cơ bản / Nâng cao / ZB, có hình nhận dạng từng trường hợp và minh hoạ động. Công thức ZBLS/ZBLL lấy từ [Alg Trainer của Tao Yu](https://github.com/tao-yu/Alg-Trainer) (giấy phép MIT, xem `third_party/alg-trainer`)

## Tải app (Android)

**[⬇ Tải bản mới nhất](https://github.com/nguyenchitu2005-jpg/AppGiaiRubik/releases/latest)**. Mở link trên điện thoại, tải file `RubikSolver-…apk` rồi bấm vào để cài.

- Máy hỏi *"Cho phép cài ứng dụng không rõ nguồn gốc"*: chọn **Cài đặt** → bật **Cho phép từ nguồn này** → quay lại bấm **Cài đặt**.
- Nếu Google Play Protect cảnh báo *"Ứng dụng chưa được xác minh"*: bấm **Chi tiết** → **Vẫn cài đặt**. Cảnh báo này xuất hiện vì app không tải từ Google Play.
- Từ bản 1.2.0, app **tự báo khi có phiên bản mới** (lúc mở app, hoặc menu → Kiểm tra cập nhật): bấm **Cập nhật** để tải, rồi mở file và bấm **Cài đặt** (cài đè, không mất dữ liệu).
- Nếu file `RubikSolver-1.0.0.apk` báo *"Ứng dụng không tương thích"* (máy rất cũ hoặc máy ảo), tải file `RubikSolver-1.0.0-tat-ca-may.apk`.

## Tiến độ

Chi tiết (các yêu cầu phát sinh, việc đang chờ, kế hoạch tuần 10): [docs/KE_HOACH.md](docs/KE_HOACH.md)

| Tuần | Nội dung | Trạng thái |
|---|---|---|
| 1 | Phần lõi xử lý khối (54 ô màu, phép xoay, biểu diễn góc/cạnh) | Xong |
| 2 | Vẽ khối 3D bằng `CustomPainter` | Xong |
| 3 | Animation xoay tầng và sơ đồ 2D để nhập màu | Xong |
| 4 | Kiểm tra khối hợp lệ và chế độ Giải nhanh (Kociemba) | Xong |
| 5–6 | Chế độ Học (phương pháp tầng) | Xong |
| 7 | Màn hình hướng dẫn giải và thư viện công thức | Xong |
| 8–9 | Quét camera và nhận diện màu | Code xong, chờ thử camera trên máy thật |
| 10 | Hoàn thiện, build bản phát hành | Tạm dừng (đợi kết quả thử camera) |

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
  features/camera_solve/ giải cùng camera: đọc từng nước, camera theo dõi
  shared/             bảng màu và widget dùng chung (sơ đồ 2D)
  state/              quản lý trạng thái (Riverpod)
test/                 unit test và widget test
```
