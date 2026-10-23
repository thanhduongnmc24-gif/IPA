/**
 * CẦU NỐI LƯU ẢNH XƯỞNG CÁN LÊN GOOGLE DRIVE (KHÔNG BAO GIỜ HẾT HẠN TOKEN)
 *
 * HƯỚNG DẪN CÀI ĐẶT TRONG 1 PHÚT:
 * 1. Truy cập https://script.google.com và bấm "Dự án mới" (New project).
 * 2. Xóa đoạn mã mặc định và dán toàn bộ đoạn mã dưới đây vào.
 * 3. Bấm nút "Triển khai" (Deploy) ở góc trên bên phải -> "Tùy chọn triển khai mới" (New deployment).
 * 4. Ở mục "Chọn loại" (Select type - biểu tượng bánh răng), chọn "Ứng dụng web" (Web app).
 * 5. Cấu hình:
 *    - Thực thi dưới dạng (Execute as): "Tôi" (Me)
 *    - Ai có quyền truy cập (Who has access): "Bất kỳ ai" (Anyone)
 * 6. Bấm "Triển khai" (Deploy), cấp quyền truy cập Google Drive cho tài khoản của bạn.
 * 7. Copy đường dẫn "URL ứng dụng web" (https://script.google.com/macros/s/.../exec)
 *    và dán vào mục "Cấu hình Drive & Supabase" trong ứng dụng iOS!
 */

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);

    // 1. Nhánh tải ảnh từ Xưởng Cán lên Google Drive
    if (data.action === "upload_drive") {
      var folder = (data.folderId && data.folderId.trim() !== "")
        ? DriveApp.getFolderById(data.folderId.trim())
        : DriveApp.getRootFolder();

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

    // 2. Nhánh gửi dữ liệu sang Google Sheets (tương thích tab Sheets)
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
