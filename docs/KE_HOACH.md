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
| Sửa Học cách giải/Giải nhanh bị lỗi trên web; âm thanh khi xoay và khi xáo trộn, có nút bật/tắt | `127be7c` |
| Âm thanh không làm dừng nhạc nền; phát hành bản APK 1.0.0 trên GitHub Releases | `154fb09` |
| Chọn trình độ **Newbie/Pro**. Pro giải bằng **CFOP**: Cross tối ưu, 41 F2L (sinh bằng máy, chỉ dùng R/U/F), 57 OLL, 21 PLL. Thư viện chia *Công thức cơ bản* / *Công thức nâng cao*, có hình nhận dạng. Ký hiệu xoay 2 tầng (r, f, u…) | `0fe307e` |
| Trình độ **Master**: phương pháp ZB với **302 ZBLS + 472 ZBLL** (nhập từ Alg Trainer, MIT, mỗi công thức được kiểm chứng; phủ 1192/1192 trạng thái cặp cuối, 7488/7488 tầng cuối). F2L đánh số lại theo bảng chuẩn. Thư viện có tab ZB | `5e2d507` |
| Nút lát giữa M / M' / M2 trên bàn phím xoay | `68ca3a7` |
| Menu góc trái trên: **Hẹn giờ giải** (WCA, Ao5/Ao12, lưu lịch sử bằng `shared_preferences`) và **Công thức xáo trộn** (WCA trạng thái ngẫu nhiên, nhanh, luyện OLL/PLL/ZBLL) | `b433cfe` |
| Nút bóng đèn 💡 trên khối 3D: gợi ý bước tiếp theo theo trình độ (công thức, nước xoay), có nút "Xoay giúp tôi" | `c7ea08b` |
| Menu **Ký hiệu & cách xoay** cho người mới: 6 mặt, R / R' / R2, lát giữa M E S, 2 tầng (r…), xoay cả khối x y z; khối 3D minh hoạ có mũi tên chỉ hướng; phần luyện tập đoán ký hiệu | `64c74ee` |
| Phát hành bản **1.1.0** (APK) | `7f71f96` |
| **Máy tính / web**: bố cục 2 cột khi cửa sổ rộng ≥ 840 px (khối 3D lớn bên trái, điều khiển bên phải; thư viện và xáo trộn dạng lưới); cửa sổ Windows/macOS mặc định 1280×800; web có tiêu đề, mô tả và biểu tượng của app; sửa lỗi chạm "bất kỳ đâu" để dừng đồng hồ chỉ nhận ở cột giữa | `53d9697` |
| Cửa sổ Windows tự vừa màn hình (125–150%) và căn giữa | `6b886c3` |
| Menu **Luyện tập**: chọn bộ F2L / OLL / PLL / ZBLS / ZBLL và từng trường hợp (theo nhóm), app xáo ra trường hợp ngẫu nhiên trong số đã chọn, bấm giờ, gợi ý đáp án, thống kê trường hợp chậm nhất | `73b839d` |
| **Quét camera trên web và Windows**: chế độ chụp ảnh (các nền tảng này không có luồng khung hình): mỗi mặt một ảnh, đọc màu 9 ô rồi dùng chung bộ nhận diện màu; Windows sửa lật gương; khung xem trước vừa màn hình | `da1ea79` |
| **Báo cập nhật trong app**: khi mở app (Android) và từ menu "Kiểm tra cập nhật", app hỏi GitHub bản mới nhất; có bản mới thì hiện nội dung và nút tải APK (cài đè, không mất dữ liệu). Phát hành bản **1.2.0** | `bd11c60` |
| **Tự động chụp khi quét**: khi cả 9 ô rõ màu, tâm đúng mặt cần quét và màu đứng yên ~1 giây thì app tự chụp (rung nhẹ + báo "Đã chụp mặt …"), có thanh tiến độ và công tắc tắt/bật; web và Windows chụp ảnh ~0,7 s/lần để đọc màu liên tục | `98f3252` |
| **Giải cùng camera**: menu → quét 6 mặt (camera trước) → app tìm lời giải ngắn nhất, đọc to từng nước (giọng tiếng Việt, không có thì tiếng Anh) và hiện công thức; camera so mặt trước với vị trí dự kiến để biết nước đã xong (nhận cả khi giải nhanh hơn giọng đọc, tối đa 4 nước), nước mặt sau camera không thấy thì tự sang sau 2,5 s và kiểm lại ở nước sau; xoay nhầm một nước thì nhận ra và chỉ cách sửa; bấm giờ, đọc từng nước hoặc 3 nước một lần. Quét: tự nhận camera cho ảnh lật gương; đọc màu theo màu thật của khối đã quét | `40e3c7d` |
| Sửa **không mở được camera** (`cameraNotReadable`) trên web/Windows khi máy có camera ảo (OBS Virtual Camera…) mà chương trình của nó đang tắt: bỏ qua camera không khởi động được, ưu tiên camera thật, thử lần lượt từng camera; thêm nút **đổi camera** trên khung hình | `ea06d35` |
| Nhận đúng **cam nhạt (màu cá hồi)** khi quét: khối có màu cam mang sắc độ của đỏ (5–10°) dưới webcam sáng bị đọc thành đỏ và không tự chụp được. Đỏ/cam giờ phân biệt theo tâm đỏ và tâm cam của chính khối đã quét (tâm của mặt đang quét theo hướng dẫn); ranh giới đỏ/cam không còn làm ô bị coi là "chưa rõ" | `75db817` |
| **Tự tìm mặt khối ở bất cứ đâu trong khung hình** (gần hay xa, không cần khớp ô vuông) khi quét và khi giải cùng camera: dò lưới 3×3 mọi vị trí/kích thước trên ảnh thu nhỏ, mặt phải nổi bật khỏi xung quanh (viền, đường nối giữa ô), chọn mặt rõ nhất rồi mới xét màu tâm; khi giải còn ưu tiên màu đúng vị trí dự kiến. Không thấy mặt thì không đọc gì (không lấy nhầm tường trắng làm mặt trắng). Giải: cứ xoay là app tự nhận và đọc nước tiếp; nút "Đã xoay" chỉ còn là dự phòng | `afe2d9d` |
| Nhận được **mặt một màu của khối không viền** (stickerless, không có khe đen giữa các ô): chấp nhận khi là một hình vuông tách hẳn khỏi xung quanh và không phải một ô của mặt lớn hơn | `9eb7a75` |
| Sửa **báo "Đã giải xong" khi chưa xong**: một góc toàn xanh của mặt trước (vd. hai hàng dưới) bị đọc như mặt đã giải. Giờ lưới một màu nằm trong một mặt nhiều màu thì nhường cho cả mặt; nhảy cóc nhiều nước phải khớp đủ 9/9, nhảy từ 3 nước trở lên hoặc tới cuối phải giữ yên 1,2 giây | `50b295e` |
| **Kiểm tra lại nhận diện màu** bằng mô phỏng khối thật (màu đo từ ảnh webcam của người dùng) dưới 6 kiểu ánh sáng, 20 khối mỗi kiểu: sửa không tự chụp được dưới **đèn vàng** (trắng ngả kem) và **phòng tối** (ngưỡng trắng); khi giải, trắng so theo độ sáng lúc quét, bớt chặt khi ánh sáng đổi; tìm mặt khối không nhận nhầm sọc màn/tường, áo + cổ áo (mỗi cạnh của mặt phải có viền, ô phải đều màu) và vẫn thấy ô cam nhạt khi cháy sáng | `8fee16a` |
| Nhận được **mặt tâm vàng bị cháy sáng** (vàng nhạt gần thành trắng): trắng/vàng giờ cũng phân biệt theo tâm trắng của chính khối đã quét (như đỏ/cam); tâm của mặt đang quét theo hướng dẫn | `9794460` |
| **Tự chụp chậm và chắc hơn** để không lộn màu: giữ yên ~1,4 giây và ít nhất 3 khung hình; "đứng yên" giờ xét cả màu thật từng ô (không chỉ nhãn màu) và vị trí/kích thước mặt khối; không chụp lại mặt đã chụp | (commit này) |
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
