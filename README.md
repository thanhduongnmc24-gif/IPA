# Ghi Chú & Xưởng Cán (Swift UIKit - iOS 16+)

Ứng dụng `ipa-main` viết bằng **Swift (UIKit thuần, iOS 16+)** theo cấu trúc `XcodeGen` (`project.yml`, `MaNguon/`, `TaiNguyen/`, `.github/workflows/tao-ipa.yml`).

## Điểm nổi bật

* **Xưởng Cán (Tab đầu tiên)**:
  * Giao diện tinh gọn tối đa: thanh chọn bảng nằm trên 1 hàng mỏng (`30pt`), các nút `+Cột`, `+Dòng`, `⋯` tích hợp ngay trên thanh điều hướng.
  * Tự động tạo và đồng bộ các bảng Xưởng Cán thẳng vào Supabase (`user_sync`) mà không cần tạo bảng SQL thủ công.
  * Ảnh chụp chỉ lưu tại **Google Drive** (kết nối trực tiếp qua **Google Drive REST API v3 OAuth 2.0** — không cần dùng Google Apps Script) và **Bộ nhớ đệm (Cache) của ứng dụng**, không lưu dữ liệu ảnh lên Supabase.
* **Cài đặt có nút Lưu riêng biệt**:
  * Khi thay đổi giao diện, bật/tắt tab hay chỉnh chu kỳ ca, màn hình giữ nguyên vị trí và không tự nhảy tab; chỉ khi bấm nút **Lưu** mới áp dụng thay đổi.
