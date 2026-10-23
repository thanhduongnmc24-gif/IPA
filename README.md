# Ghi Chú & Xưởng Cán (Swift UIKit - iOS 16+)

Ứng dụng `ipa-main` đã được chuyển đổi hoàn toàn sang ngôn ngữ **Swift (UIKit thuần, iOS 16+)** theo đúng kiến trúc của dự án `tinh-cong-doan` (dùng `XcodeGen` + `project.yml` + GitHub Actions `.github/workflows/tao-ipa.yml` để đóng gói bản `.ipa` chưa ký dùng cho ESign/Scarlet).

## Tính năng chính

1. **🏭 Xưởng Cán (Tính năng mới)**:
   - Có **nút chuyển nhanh sang Xưởng Cán** ngay trên thanh điều hướng của mọi màn hình, đầu màn hình Lịch và trên thanh TabBar.
   - Quản lý nhiều bảng: tạo bảng mới, đổi tên bảng, xóa bảng.
   - Thêm cột động vào từng bảng với 2 kiểu dữ liệu: **Chữ (`Text`)** hoặc **Ảnh chụp (`Image` - chụp trực tiếp từ Camera hoặc chọn từ Thư viện ảnh)**.
   - Thêm hàng và điền dữ liệu chữ hoặc ảnh chụp, xem ảnh phóng to toàn màn hình (hỗ trợ zoom 2 ngón tay).
   - **Bộ nhớ đệm ảnh 2 tầng (`RAM NSCache` + `Disk Cache` tại `Documents/DuLieuGhiChu/AnhCacheXuongCan`)**: ảnh sau khi chụp hoặc tải về lần đầu sẽ lưu ngay vào bộ nhớ đệm của ứng dụng để các lần mở sau hiển thị tức thì (0ms) mà không cần tải lại.
   - **Lưu ảnh lên Google Drive & Đồng bộ toàn bộ vào Supabase**: tự động tải ảnh lên Google Drive và đồng bộ cấu trúc bảng, cột, dòng, liên kết ảnh (kèm ảnh thu nhỏ dự phòng) lên Supabase (`xuong_can_bang` & `user_sync`).
2. **📅 Lịch làm việc & Âm lịch**:
   - Lịch tháng kèm ngày Âm lịch tự động, tính ca làm việc theo chu kỳ (`Ca Ngày`, `Ca Đêm`, `Ngày Nghỉ`), ghi chú nhiều dòng theo ngày và bảng Tổng hợp ghi chú (`Theo Ngày` / `Theo Tên`).
3. **📝 Ghi chú nhanh**:
   - Tìm kiếm tức thì, ghim ghi chú quan trọng lên đầu, mở trực tiếp liên kết `http/https`, vuốt để xóa.
4. **📊 Sheets**:
   - Gửi dữ liệu chữ và hình ảnh theo tọa độ ô (`A1`, `B2`...) lên Google Sheets thông qua Google Apps Script.
5. **🎬 Media Creator (Gemini AI)**:
   - Tạo Prompt Video VEO3 8s, Prompt Ảnh, 5 Tiêu đề YouTube/Shorts, và Sáng tác Nhạc & Lời kèm Studio Sáng Tạo AI (Hòa âm, Dịch Anh, Ảnh bìa, Phê bình, Kịch bản MV, Nhạc lý).
6. **🔔 Nhắc nhở**:
   - Đặt lịch hẹn giờ thông báo cục bộ và đọc to nội dung nhắc nhở bằng giọng nói Tiếng Việt (`AVSpeechSynthesizer`).
7. **⚙️ Cài đặt & Đồng bộ đám mây**:
   - Đăng nhập/Đăng ký Supabase, Sao lưu & Khôi phục đám mây, Cấu hình Google Drive & Bộ nhớ đệm ảnh, Chế độ Sáng/Tối, Bật/Tắt từng Tab, Cấu hình Gemini API Key và Chu kỳ ca làm việc.

## Hướng dẫn cấu hình Supabase & Google Drive

- Xem chi tiết trong tệp `supabase_xuong_can.sql` và `google_apps_script_drive.gs`, hoặc bấm trực tiếp nút **Cấu hình Drive & Supabase** ngay bên trong màn hình **Xưởng Cán** của ứng dụng.
