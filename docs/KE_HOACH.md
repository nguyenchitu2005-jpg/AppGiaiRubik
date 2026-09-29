# Kế hoạch dự án AppGiaiRubik: tiến độ hiện tại

_Cập nhật: 29/09/2026_

## Tình trạng chung
Đã xong tuần 1–9 cùng các yêu cầu phát sinh. **Tạm dừng để thử camera trên điện thoại thật** trước khi làm tuần 10.

- Repo: https://github.com/nguyenchitu2005-jpg/AppGiaiRubik (nhánh `main`, commit mới nhất `7a2b1ae`)
- Thư mục: `D:\androistudio\baitap\3drubik`. Flutter 3.47.3, Dart 3.13, chỉ Android, khoá màn hình dọc.
- Kiểm thử: **92 test đều qua**, `flutter analyze` không báo lỗi, APK debug và release đều build được.
- Đã chạy trên điện thoại thật: OPPO CPH2797, Android 16 (bản release).

---

## Bảng tiến độ

| Tuần | Nội dung | Trạng thái | Commit |
|---|---|---|---|
| 1 | Phần lõi xử lý khối: 54 ô màu, phép xoay, biểu diễn góc/cạnh, xáo trộn | ✅ Xong | `f6af305` |
| 2 | Vẽ khối 3D bằng `CustomPainter` (phối cảnh, loại mặt khuất, ánh sáng) | ✅ Xong | `8903458` |
| 3 | Animation xoay tầng, tốc độ, màn hình nhập màu 2D/3D | ✅ Xong | `3b083f6` |
| 4 | Kiểm tra khối hợp lệ (thông báo tiếng Việt) và Giải nhanh (Kociemba, ~21 nước) | ✅ Xong | `b7fb7ad` |
| 5–6 | Chế độ Học: phương pháp tầng 7 giai đoạn, ~144 nước, có giải thích | ✅ Xong | `c04d8be` |
| 7 | Màn hình hướng dẫn (mũi tên hướng xoay, viền mảnh đang xử lý, tiến độ 7 giai đoạn) và thư viện công thức | ✅ Xong | `cc36e4b` |
| 8–9 | Quét 6 mặt bằng camera, phân loại màu, tự sửa mặt quét lệch, màn hình kiểm tra kết quả | ✅ Code xong, ⏳ **chờ thử trên máy thật** | `b627b97` |
| 10 | Hoàn thiện và phát hành | ⏸ Tạm dừng, đợi kết quả thử camera | — |

### Nền tảng
| Nền tảng | Trạng thái |
|---|---|
| Android | ✅ Chạy trên điện thoại thật (OPPO CPH2797, Android 16) |
| Windows | ✅ Build bản release và chạy được. Không có quét camera, vẫn nhập màu tay. **Từ khi thêm âm thanh cần bật Developer Mode** (Settings → System → For developers) thì mới build được, do plugin âm thanh cần symlink |
| Web (Chrome) | ✅ Build bản release, Giải nhanh và Học cách giải chạy tới cuối trên Chrome. Web không có isolate nên bộ giải chạy trên luồng giao diện (Giải nhanh ~0,4 s). Không có quét camera |
| iOS | ⏸ Đã có cấu hình (quyền camera, tên app, icon), **chưa build thử** vì cần máy Mac |
| macOS | ⏸ Đã có cấu hình (tên app, cửa sổ, icon), **chưa build thử** vì cần máy Mac. Không có quét camera |

### Yêu cầu phát sinh đã làm (ngoài kế hoạch gốc)
| Yêu cầu | Commit |
|---|---|
| Logo mới (khối 3D, nền xanh–tím) và huy hiệu chú chó | `9d8d90b`, `1e8b92d` |
| Chạy đa nền tảng: Android, iOS, Windows, macOS | `e9d8c74` |
| Sửa Học cách giải/Giải nhanh bị lỗi trên web; âm thanh khi xoay và khi xáo trộn, có nút bật/tắt | (commit này) |
| Ký hiệu mặt (U·Trên, F·Trước…) trên khối 3D, luôn đứng thẳng, có nút bật/tắt | `4dbec53` |
| Nút hoàn tác/làm lại ở màn hình nhập màu. Khối tự về tư thế đứng thẳng sau khi xoay | `36a5956` |
| Ký hiệu mặt trên sơ đồ 2D | `6568574` |
| Xoay khối = xoay cả khối (x/y/z): mặt trước luôn là F, không làm sai lời giải | `52d99b1` |
| Ghim khối 3D phía trên, bàn phím xoay ngay dưới | `6256865` |
| Ghim thêm sơ đồ 2D: thấy cùng lúc khối 3D, sơ đồ 2D và bàn phím | `7a2b1ae` |

---

## Đang chờ: thử camera trên điện thoại thật (người dùng làm)
Phần xử lý màu mới được kiểm chứng bằng dữ liệu giả lập (khối đúng hoàn toàn 100% ở điều kiện thường, 99,4% khi ánh sáng khắc nghiệt). Các việc cần thử trên máy thật:
1. Cắm điện thoại, chạy `flutter run` và cấp quyền camera.
2. Bấm **Quét khối bằng camera**, quét đủ 6 mặt theo hướng dẫn, ở 2–3 điều kiện ánh sáng (đèn trắng, đèn vàng, ánh sáng cửa sổ).
3. Ghi nhận:
   - Lưới xem trước có hiện đúng màu không, đặc biệt đỏ/cam và trắng/vàng.
   - Khung lưới có nằm đúng trên khối không, tức việc ánh xạ theo góc xoay cảm biến có đúng không.
   - Có ổn định được để chụp không.
   - Màn hình "Kiểm tra kết quả quét" sai bao nhiêu ô.
4. Gửi lại ảnh chụp màn hình các trường hợp nhận sai.

Khả năng phải sửa sau khi thử:
- Ngưỡng màu HSV cho lưới xem trước, trong `LiveColorClassifier` ([color_classifier.dart](../lib/core/vision/color_classifier.dart)).
- Kích thước khung lưới / vùng lấy mẫu (`_gridWidth`, `patch`), trong [scan_screen.dart](../lib/features/scanner/scan_screen.dart) và [yuv_image.dart](../lib/core/vision/yuv_image.dart).
- Câu hướng dẫn cầm khối trong `ScanController.steps` ([scan_controller.dart](../lib/features/scanner/scan_controller.dart)).

---

## Tuần 10 (làm sau khi có kết quả thử camera)
| Việc | Chi tiết |
|---|---|
| Sửa lỗi từ lần thử thật | Theo phản hồi ở trên, gồm cả camera, cảm giác xoay và bố cục |
| Lưu cài đặt | Tốc độ xoay, bật/tắt ký hiệu mặt (`shared_preferences`), trong [settings.dart](../lib/state/settings.dart) |
| Lịch sử giải | Lưu các lần giải: ngày, chế độ, số nước. Màn hình xem lại |
| Đo hiệu năng | `flutter run --profile`, mục tiêu ≥ 55 fps khi xoay/animation |
| Kiểm chứng iOS/macOS | Build thử trên Mac hoặc GitHub Actions (người dùng chọn làm sau) |
| Phát hành | Tạo keystore ký bản release (người dùng quyết định), build APK/AAB, hoàn thiện README |

### Quyết định còn treo (người dùng chưa trả lời)
- **Dung lượng APK:** package `cuber` làm APK nặng thêm 10,7 MB (16,9 → 27,5 MB release arm64). Có hai lựa chọn:
  - (a) giữ nguyên;
  - (b) tự viết Kociemba, tính bảng tra lúc mở app lần đầu. APK về khoảng 17 MB, tốn thêm khoảng 1 tuần.
- **Keystore phát hành:** hiện bản release đang ký bằng khoá debug. Cần khoá riêng nếu định đưa lên Google Play.

### Ghi chú kỹ thuật cần nhớ
- `android/gradle.properties` có `kotlin.incremental=false`. Dòng này bắt buộc vì dự án ở ổ D: còn pub cache ở ổ C:, nếu thiếu thì plugin camera build lỗi.
- Ký hiệu mặt gắn với **vị trí** chứ không gắn với màu. Màn hình hướng dẫn luôn đưa khối về hướng cầm của lời giải.
