/**
 * CẦU NỐI LƯU ẢNH XƯỞNG CÁN LÊN GOOGLE DRIVE (KHÔNG BAO GIỜ HẾT HẠN TOKEN)
 *
 * HƯỚNG DẪN CÀI ĐẶT CHUẨN 100% LÊN ẢNH DRIVE:
 * 1. Truy cập https://script.google.com và mở dự án của bạn (hoặc tạo Dự án mới).
 * 2. Xóa toàn bộ mã cũ và dán toàn bộ đoạn mã dưới đây vào.
 * 3. [QUAN TRỌNG NHẤT] Trên thanh công cụ phía trên của trang Script, chọn hàm "capQuyenDrive"
 *    rồi bấm nút "Run (Chạy)". Một bảng yêu cầu cấp quyền sẽ hiện ra:
 *    - Bấm "Review permissions (Xem lại quyền)" -> Chọn tài khoản Google của bạn.
 *    - Bấm "Advanced (Nâng cao)" -> Bấm "Go to ... (unsafe)" -> Bấm "Allow (Cho phép)".
 * 4. Bấm nút "Triển khai (Deploy)" ở góc trên bên phải -> "Tùy chọn triển khai mới (New deployment)".
 *    - Loại: "Ứng dụng web (Web app)"
 *    - Thực thi dưới dạng (Execute as): "Tôi (Me)"
 *    - Ai có quyền truy cập (Who has access): "Bất kỳ ai (Anyone)"
 * 5. Copy đường dẫn "URL ứng dụng web" (https://script.google.com/macros/s/.../exec)
 *    dán vào màn hình "Cấu hình Google Drive" trong app iOS và bấm nút "Test thử tải ảnh lên Drive"!
 */

function capQuyenDrive() {
  var root = DriveApp.getRootFolder();
  Logger.log("Đã cấp quyền Google Drive thành công! Thư mục gốc: " + root.getName());
}

function tachFolderId(input) {
  if (!input) return "";
  var s = input.toString().trim();
  var m = s.match(/\/folders\/([a-zA-Z0-9_-]+)/);
  if (m && m[1]) return m[1];
  return s;
}

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    result: "success",
    message: "Cau noi Google Drive Xuong Can dang hoat dong!"
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);

    if (data.action === "upload_drive") {
      var fid = tachFolderId(data.folderId);
      var folder = fid ? DriveApp.getFolderById(fid) : DriveApp.getRootFolder();

      var bytes = Utilities.base64Decode(data.base64);
      var blob = Utilities.newBlob(
        bytes,
        data.mimeType || "image/jpeg",
        data.filename || ("XuongCan_" + new Date().getTime() + ".jpg")
      );

      var file = folder.createFile(blob);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      var fileId = file.getId();

      return ContentService.createTextOutput(JSON.stringify({
        result: "success",
        fileId: fileId,
        url: "https://drive.google.com/uc?export=view&id=" + fileId
      })).setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService.createTextOutput(JSON.stringify({
      result: "success"
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      result: "error",
      error: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
