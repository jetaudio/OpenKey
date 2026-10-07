# Review 8 PR đang mở và tích hợp vào fork

Ngày kiểm tra: 07/10/2026. Repo: `tuyenvm/OpenKey`; master được kiểm tra: `89c2fd3bf258562f2349f89b49d81e2f140c3fc3`. Fork: [jetaudio/OpenKey](https://github.com/jetaudio/OpenKey).

Đã đọc diff đầy đủ, lịch sử commit, bình luận, review và trạng thái kiểm tra của cả 8 PR. Tại thời điểm tải metadata, cả 8 PR đều không có kết quả CI; #324 có xung đột với master. Các thay đổi dưới đây được chỉnh lại và tích hợp trên fork, không merge các PR trên repo gốc.

| PR / tác giả | Kết quả review | Xử lý trên fork |
| --- | --- | --- |
| [#333 – hungmtuci](https://github.com/tuyenvm/OpenKey/pull/333) | Có các sửa lỗi hữu ích, nhưng phạm vi rộng và lẫn thay đổi hành vi. Đổi Option+Z đã lưu sang Ctrl+Z; mặc định developer app bỏ các bit bảng mã; khôi phục ký tự gọi `SendKeyCode` bằng mã ký tự thay vì keycode; nhánh chunk vẫn có thể bỏ phần dư của ký tự hai đơn vị UTF-16. Build script lấy storyboard/Info.plist từ app đã cài hoặc giữ placeholder chưa thay thế. Nhận diện Spotlight chỉ bằng frontmost bundle không chứng minh ô Spotlight đang nhận phím. | Cấp phát cặp Backspace mới; guard lịch sử `_syncKey`; watchdog 0,5 giây có cleanup; bỏ subscription kéo chuột; sửa ownership TIS; SMAppService trên macOS 13+ và bỏ đăng ký login item trong `fillData`; setter ngôn ngữ rõ ràng; mặc định English cho developer app trên macOS nhưng giữ bảng mã và lựa chọn đã lưu. Viết lại việc gửi chuỗi theo độ dài UTF-16 thực tế. Giữ phím tắt người dùng. Giữ cách build bằng Xcode từ toàn bộ tài nguyên repo. Không lấy README quảng cáo, bộ lọc ứng dụng chưa kiểm chứng, Makefile/build script cũ hoặc event tag dư thừa. |
| [#332 – duyhnynh](https://github.com/tuyenvm/OpenKey/pull/332) | Guard notification timeout/user-input ở đầu callback là đúng chỗ; giúp tránh dereference event của notification. Bình luận có thử gây timeout, nhưng chưa xác nhận độ ổn định dài hạn. | Tích hợp guard và hàm C bật lại tap; thêm reset trạng thái modifier/composition. Kiểm thử hai notification, event NULL và lifecycle watchdog. |
| [#329 – Quocker22](https://github.com/tuyenvm/OpenKey/pull/329) | Alpha/layer loại bỏ cửa sổ ẩn, nhưng cửa sổ đang fade vẫn có alpha > 0 và layer > 0, nên chưa đủ xác định nơi nhận phím. PR cũng chấp nhận metadata alpha/layer bị thiếu. | Đòi đủ alpha/layer/PID; xác nhận PID đích của event, hoặc PID của AX focused element nếu event không cung cấp đích. Giới hạn timeout AX 20 ms, không bật selection replacement khi truy vấn thất bại. Chỉ truy vấn một lần cho một lần thay chuỗi; dùng cùng lựa chọn cho macro. |
| [#324 – luatnd](https://github.com/tuyenvm/OpenKey/pull/324) | Có xung đột; phần gỡ `CFRunLoopRun()` đã tồn tại trên master. Chỉ thêm bit Fn vào hàm kiểm tra chưa ngăn Fn+phím khác gây đổi ngôn ngữ lúc nhả Fn. Căn giữa mỗi lần mở sẽ làm mất vị trí cửa sổ đang hợp lệ. | Tích hợp checkbox/hint/outlet Fn; chọn Fn cấu hình một lần nhấn, vẫn cho phép chọn tổ hợp sau đó. Dùng modifier hiện tại cho shortcut ký tự, theo dõi chuỗi nhấn/nhả cho shortcut modifier; tránh Fn+arrow và nhả từng phần của Fn+Control. Đưa cả 4 cửa sổ ra trước và chỉ phục hồi vị trí khi thanh tiêu đề không còn tiếp cận được trên màn hình nào. |
| [#317 – uponatime2019](https://github.com/tuyenvm/OpenKey/pull/317) | WTS unlock phù hợp với lỗi. Timer gỡ/cài lại hook mỗi 10 giây làm gián đoạn gõ bình thường và không đo health. Không kiểm tra lỗi cài hook. File `.claude/settings.local.json` không thuộc sửa lỗi sản phẩm. | Chỉ phục hồi khi nhận `WTS_SESSION_UNLOCK`; đăng ký/hủy notification theo vòng đời window; dựng đủ hook mới trước khi bỏ hook cũ, rollback nếu thất bại; đồng bộ modifier đang giữ và reset composition/cache. Bỏ timer và local settings. |
| [#297 – nhutuananh](https://github.com/tuyenvm/OpenKey/pull/297) | Sửa ý tưởng giữ case khi bỏ dấu, nhưng xóa fallback decode ký tự một byte của VNI/CP1258. Tái hiện từ chính mã PR: `Đa Ơi` qua VNI trở lại thành `Ña Ôi`; qua CP1258 thành `Ða Õi`. Nhánh bỏ dấu cũng chưa dùng yêu cầu viết hoa chữ đầu. | Giữ cả decode hai đơn vị và fallback một đơn vị; dùng chung xử lý case/output encoding cho hai nhánh; giữ case khi bỏ dấu và xử lý uppercase/lowercase/title/sentence; guard bảng mã lỗi. TCVN3 có byte trùng giữa hoa/thường: những byte không phân biệt được case được decode về chữ thường, không tự đoán từ font. |
| [#289 – kurokeita](https://github.com/tuyenvm/OpenKey/pull/289) | Engine đã có Simple Telex 2; thiếu lựa chọn Windows. Hai icon thay đổi không cần cho tính năng và không có mô tả kiểm chứng hình ảnh. | Tích hợp Simple Telex 1/2 vào danh sách và menu Windows, giữ index 0/1/2 cũ. Không thay icon. |
| [#287 – quyleanh](https://github.com/tuyenvm/OpenKey/pull/287) | Mục tiêu sửa đường dẫn artifact hợp lý; cấu hình OutDir/IntDir tương đối và cùng thư mục chưa đảm bảo cách ly output/intermediate. Cần kiểm tra cả app và updater, cả hai kiến trúc. | Workflow dùng đường dẫn tuyệt đối, IntDir riêng từng project/kiến trúc; build cả app/updater; kiểm tra file tồn tại và PE machine x86/x64; upload đúng 4 EXE và báo lỗi nếu thiếu. Thêm kiểm thử engine bằng MSVC và Windows keycode. |

## Các head PR đã review

```text
333 2dfb0fa49c53f29924490a1c27c2ad3cb31c6c4f
332 21b98e3660f6acdb3c31d2a805aa87d872b2123f
329 b702fa712f8b68cba7eb92bab521f0af085fcb3b
324 8d763b5ff8439c20eb919b6ce35c248f90dfee92
317 0a28652026550b74afa5ead58ae36c83d70ef5ee
297 3878e6caee951bdff2c9de18ca0ec9380e9fec3d
289 4564741117fdbb966951275d7add5d46c866ddfd
287 496e1016b5a1f6dae363ca7a7e87f3cf9b54e0c8
```

## Kiểm chứng

- Cục bộ Apple Silicon: 3.376 assertions engine; 87 assertions macOS event; 12 assertions lifecycle tap, với AddressSanitizer và UndefinedBehaviorSanitizer. Event posting, truy vấn window/focus, input source và event tap được mock để không gửi phím hoặc cài hook vào máy người dùng.
- Các bài kiểm tra gồm case/bỏ dấu, 25 cặp bảng mã cho ký tự Việt, chuỗi trộn ASCII/emoji, dữ liệu preference lỗi, bit bảng mã, override/cache Smart Switch; timeout/user-input; Fn đơn, Fn+arrow, nhả Fn+Control; Spotlight fade/ẩn/focus lỗi; cấp phát Backspace; chuỗi dài Unicode/VNI/tổ hợp, macro có surrogate pair; control key lúc restore; ownership input source; khởi tạo/thất bại/dừng/watchdog.
- [CI macOS cuối](https://github.com/jetaudio/OpenKey/actions/runs/37567989734): thành công, commit `22690773b47dcad7f4bb851611119ebbc19d7e23`, Xcode 26.6 (17F113), cả 3 bộ kiểm thử và Release universal.
- [CI Windows cuối](https://github.com/jetaudio/OpenKey/actions/runs/37567989731): thành công trên cùng commit; 3.376 assertions với MSVC/Windows keycode; build app/updater x86/x64, kiểm tra PE machine, upload artifact và provenance attestation.
- Bản DMG `bc7f7c5` đã được tải về: storyboard và outlet Fn tải được; kiểm tra thao tác Fn và render phát hiện title “Điều khiển” chồng lên label “Kiểu gõ”. Đã hạ các hàng điều khiển 14 px và thêm kiểm tra vùng header/label. UI QA kiểm tra bản cũ báo lỗi overlap; bản cuối vượt qua kiểm tra. Đã render lại và xem ảnh xác nhận các hàng không chồng chữ.
- Bản cuối: `OpenKey-2.0.4-22690773b47d-universal.dmg`, khoảng 798 KiB. SHA-256 khớp artifact; `hdiutil verify` hợp lệ; mount chỉ đọc kiểm tra plist, chữ ký ad hoc và `lipo -archs` xác nhận `x86_64 arm64`. Bản này dùng phiên bản `2.0.4` / build `48` từ project của upstream master; commit trong tên file xác định phần thay đổi của fork. Các cập nhật báo cáo và công cụ QA sau commit này không thay đổi mã ứng dụng hoặc storyboard.

```text
f0364aeeeb29f17c761442f1c16418ed97889fa2d5a918bdb6061fedb000feca  OpenKey-2.0.4-22690773b47d-universal.dmg
```

Mã nguồn cục bộ: `/Users/hoangmanhlinh/Desktop/OpenKeys/OpenKey`.
DMG và ảnh render cục bộ: `/Users/hoangmanhlinh/Desktop/OpenKeys/builds/final/`.

Chưa xác nhận bằng sử dụng tương tác dài hạn: gõ thực tế trong Apple Mail/WebKit/Spotlight, sleep/wake, Login Items và Windows lock/unlock. Kiểm thử mock, build, kiến trúc, chữ ký và integrity DMG không chứng minh các tình huống này đã chạy ổn định. Bản fork được ký ad hoc và chưa notarize.
