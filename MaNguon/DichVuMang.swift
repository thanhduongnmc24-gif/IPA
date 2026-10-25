import UIKit

// MARK: - 1. Bộ Nhớ Đệm Ảnh 2 Tầng (RAM NSCache + Disk Cache) — Không lưu ảnh lên Supabase

final class BoNhoDemAnh {
    static let dungChung = BoNhoDemAnh()

    private let boNhoRAM = NSCache<NSString, UIImage>()
    private let hangDoi = DispatchQueue(label: "vn.duongnt.ghichu.imagecache", qos: .userInitiated, attributes: .concurrent)

    private init() {
        boNhoRAM.countLimit = 200
        boNhoRAM.totalCostLimit = 120 * 1024 * 1024
    }

    private func duongDanTep(maAnh: String) -> URL {
        let tenAnToan = maAnh.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return ThuMucDuLieu.dungChung.thuMucAnhCache.appendingPathComponent("\(tenAnToan).jpg")
    }

    /// Lưu ảnh vào cả RAM và bộ nhớ đĩa (Disk Cache) để lần sau mở tức thì
    func luuAnh(_ anh: UIImage, maAnh: String) {
        let khoa = maAnh as NSString
        boNhoRAM.setObject(anh, forKey: khoa)
        let url = duongDanTep(maAnh: maAnh)
        hangDoi.async(flags: .barrier) {
            if let data = anh.jpegData(compressionQuality: 0.82) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// Lấy ảnh ngay lập tức nếu có trong RAM hoặc Disk Cache
    func layAnhTucThi(maAnh: String) -> UIImage? {
        let khoa = maAnh as NSString
        if let anhRAM = boNhoRAM.object(forKey: khoa) {
            return anhRAM
        }
        let url = duongDanTep(maAnh: maAnh)
        if let data = try? Data(contentsOf: url), let anhDisk = UIImage(data: data) {
            boNhoRAM.setObject(anhDisk, forKey: khoa)
            return anhDisk
        }
        return nil
    }

    /// Lấy ảnh từ Bộ nhớ đệm của ứng dụng (RAM -> Disk), nếu chưa có mới tải từ Google Drive về lưu vào Cache
    func taiAnh(thongTin: ThongTinAnhXuongCan, hoanThanh: @escaping (UIImage?) -> Void) {
        // 1. Kiểm tra RAM & Disk Cache theo maAnh
        if let anhCoSan = layAnhTucThi(maAnh: thongTin.maAnh) {
            hoanThanh(anhCoSan)
            return
        }
        // 2. Kiểm tra theo driveFileId nếu có
        if let fileId = thongTin.driveFileId, !fileId.isEmpty,
           let anhDriveCache = layAnhTucThi(maAnh: fileId) {
            hoanThanh(anhDriveCache)
            return
        }

        // 3. Tải ảnh từ Google Drive về và lưu vào bộ nhớ đệm cho các lần mở sau
        guard let fileId = thongTin.driveFileId, !fileId.isEmpty else {
            hoanThanh(nil)
            return
        }

        DichVuGoogleDrive.dungChung.taiAnhTuDrive(fileId: fileId, driveUrl: thongTin.driveUrl) { [weak self] anhTaiVe in
            guard let self else { return }
            if let anhTaiVe {
                self.luuAnh(anhTaiVe, maAnh: thongTin.maAnh)
                self.luuAnh(anhTaiVe, maAnh: fileId)
            }
            DispatchQueue.main.async {
                hoanThanh(anhTaiVe)
            }
        }
    }

    func dungLuongBoNhoDemChuoi() -> String {
        let tm = ThuMucDuLieu.dungChung.thuMucAnhCache
        guard let cacTep = try? FileManager.default.contentsOfDirectory(at: tm, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 KB"
        }
        var tongBytes: Int64 = 0
        for tep in cacTep {
            if let kichThuoc = try? tep.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                tongBytes += Int64(kichThuoc)
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: tongBytes)
    }

    func xoaBoNhoDem() {
        boNhoRAM.removeAllObjects()
        let tm = ThuMucDuLieu.dungChung.thuMucAnhCache
        if let cacTep = try? FileManager.default.contentsOfDirectory(at: tm, includingPropertiesForKeys: nil) {
            for tep in cacTep {
                try? FileManager.default.removeItem(at: tep)
            }
        }
    }
}

// MARK: - 2. Dịch Vụ Lưu & Tải Ảnh Google Drive

final class DichVuGoogleDrive {
    static let dungChung = DichVuGoogleDrive()
    private init() {}

    /// Tự động tách lấy Folder ID chuẩn nếu người dùng dán nguyên đường link thư mục Google Drive
    static func chuanHoaFolderId(_ chuoi: String) -> String {
        let raw = chuoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if let range = raw.range(of: "/folders/") {
            let sauFolders = String(raw[range.upperBound...])
            let id = sauFolders.components(separatedBy: CharacterSet(charactersIn: "?/#&")).first ?? sauFolders
            return id.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let url = URLComponents(string: raw),
           let idParam = url.queryItems?.first(where: { $0.name == "id" })?.value {
            return idParam.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    /// Tải ảnh lên Google Drive
    func taiAnhLenDrive(
        anh: UIImage,
        tenTep: String,
        hoanThanh: @escaping (_ fileId: String?, _ driveUrl: String?, _ thongBaoLoi: String?) -> Void
    ) {
        // Nén ảnh hợp lý (kích thước tối đa 1600px, JPEG 0.78) để gửi qua Google Apps Script nhanh và không bị quá tải
        let anhNen = thuNhoAnhNeuCan(anh, kichThuocToiDa: 1600)
        guard let jpegData = anhNen.jpegData(compressionQuality: 0.78) else {
            hoanThanh(nil, nil, "Không thể tạo dữ liệu JPEG từ ảnh.")
            return
        }

        let cd = KhoDuLieu.dungChung.caiDat
        let folderId = Self.chuanHoaFolderId(cd.driveFolderId)

        // Ưu tiên 1: Nếu người dùng đã nhập Link Google Apps Script ở ô driveScriptUrl hoặc ô driveKey
        let scriptStr = !cd.driveScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cd.driveScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            : (cd.driveKey.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("https://script.google.com")
                ? cd.driveKey.trimmingCharacters(in: .whitespacesAndNewlines)
                : "")

        if !scriptStr.isEmpty {
            guard let scriptURL = URL(string: scriptStr) else {
                hoanThanh(nil, nil, "Đường dẫn Google Apps Script không hợp lệ: \(scriptStr)")
                return
            }
            taiLenQuaAppsScript(url: scriptURL, jpegData: jpegData, tenTep: tenTep, folderId: folderId, hoanThanh: hoanThanh)
            return
        }

        // Ưu tiên 2: Nếu người dùng cấu hình OAuth2 Refresh Token
        if !cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            layAccessTokenTuRefreshToken(
                clientId: cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                refreshToken: cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
            ) { [weak self] token, loi in
                guard let self else { return }
                if let token {
                    self.taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: token, apiKey: nil, hoanThanh: hoanThanh)
                } else {
                    hoanThanh(nil, nil, loi ?? "Không lấy được Access Token từ Refresh Token.")
                }
            }
            return
        }

        // Ưu tiên 3: Nếu chỉ có Key mặc định mà chưa dán Link Google Apps Script
        hoanThanh(
            nil,
            nil,
            "Chưa có Link Web App Google Apps Script! Hãy bấm biểu tượng Ổ đĩa ở góc trái trên màn hình Xưởng Cán -> dán Link https://script.google.com/macros/s/.../exec vào ô đầu tiên và bấm Lưu."
        )
    }

    private func thuNhoAnhNeuCan(_ anh: UIImage, kichThuocToiDa: CGFloat) -> UIImage {
        let maxCanh = max(anh.size.width, anh.size.height)
        guard maxCanh > kichThuocToiDa else { return anh }
        let tyLe = kichThuocToiDa / maxCanh
        let kichThuocMoi = CGSize(width: floor(anh.size.width * tyLe), height: floor(anh.size.height * tyLe))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: kichThuocMoi, format: format).image { _ in
            anh.draw(in: CGRect(origin: .zero, size: kichThuocMoi))
        }
    }

    private func taiLenQuaAppsScript(
        url: URL,
        jpegData: Data,
        tenTep: String,
        folderId: String,
        hoanThanh: @escaping (String?, String?, String?) -> Void
    ) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        let payload: [String: Any] = [
            "action": "upload_drive",
            "filename": tenTep,
            "mimeType": "image/jpeg",
            "folderId": folderId,
            "base64": jpegData.base64EncodedString()
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Lỗi kết nối mạng tới Script: \(error.localizedDescription)")
                }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, !data.isEmpty else {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Google Apps Script trả về dữ liệu rỗng (HTTP \(statusCode)).")
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let fileId = json["fileId"] as? String, !fileId.isEmpty {
                    let viewUrl = (json["url"] as? String) ?? "https://drive.google.com/uc?export=view&id=\(fileId)"
                    DispatchQueue.main.async { hoanThanh(fileId, viewUrl, nil) }
                    return
                }
                if let err = json["error"] as? String {
                    DispatchQueue.main.async {
                        hoanThanh(nil, nil, "Lỗi từ Google Apps Script: \(err)\n\n(Gợi ý: Nếu báo lỗi quyền DriveApp, hãy mở script.google.com -> chọn hàm capQuyenDrive trên thanh công cụ -> bấm Run/Chạy để cấp quyền truy cập Drive, sau đó chọn Deploy -> Manage deployments -> Edit -> New version -> Deploy).")
                    }
                    return
                }
            }

            let rawText = String(data: data, encoding: .utf8) ?? ""
            if rawText.contains("<!DOCTYPE html>") || rawText.contains("<html") {
                DispatchQueue.main.async {
                    hoanThanh(
                        nil,
                        nil,
                        "Script trả về trang HTML thay vì JSON (HTTP \(statusCode)). Nguyên nhân thường gặp:\n1. Khi Deploy Web App, mục 'Who has access (Ai có quyền truy cập)' chưa chọn là 'Anyone (Bất kỳ ai)'.\n2. Hoặc bạn chưa bấm nút 'Run (Chạy)' hàm capQuyenDrive trong script.google.com để cấp quyền tạo file trên Google Drive."
                    )
                }
            } else {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Phản hồi không đúng định dạng từ Script: \(rawText.prefix(160))")
                }
            }
        }.resume()
    }

    private func layAccessTokenTuRefreshToken(
        clientId: String,
        clientSecret: String,
        refreshToken: String,
        hoanThanh: @escaping (String?, String?) -> Void
    ) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            hoanThanh(nil, "URL OAuth2 không hợp lệ")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error {
                hoanThanh(nil, error.localizedDescription)
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                hoanThanh(nil, "Không thể đổi Refresh Token lấy Access Token.")
                return
            }
            hoanThanh(accessToken, nil)
        }.resume()
    }

    private func taiLenQuaDriveREST(
        jpegData: Data,
        tenTep: String,
        folderId: String,
        bearerToken: String?,
        apiKey: String?,
        hoanThanh: @escaping (String?, String?, String?) -> Void
    ) {
        let urlStr = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink,webContentLink"
        guard let url = URL(string: urlStr) else {
            hoanThanh(nil, nil, "URL Google Drive API không hợp lệ.")
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let bearerToken, !bearerToken.isEmpty {
            req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        var metaDict: [String: Any] = [
            "name": tenTep,
            "mimeType": "image/jpeg"
        ]
        if !folderId.isEmpty {
            metaDict["parents"] = [folderId]
        }
        let metaData = (try? JSONSerialization.data(withJSONObject: metaDict)) ?? Data("{}".utf8)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metaData)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                DispatchQueue.main.async { hoanThanh(nil, nil, error.localizedDescription) }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(statusCode),
               let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fileId = json["id"] as? String {
                let driveUrl = "https://drive.google.com/uc?export=view&id=\(fileId)"
                DispatchQueue.main.async { hoanThanh(fileId, driveUrl, nil) }
            } else {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Lỗi tải lên Google Drive REST API (HTTP \(statusCode)).")
                }
            }
        }.resume()
    }

    func taiAnhTuDrive(fileId: String, driveUrl: String?, hoanThanh: @escaping (UIImage?) -> Void) {
        let urlStr = "https://drive.google.com/uc?export=download&id=\(fileId)"
        guard let url = URL(string: urlStr) else {
            hoanThanh(nil)
            return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let img = UIImage(data: data) else {
                hoanThanh(nil)
                return
            }
            hoanThanh(img)
        }.resume()
    }
}

// MARK: - 3. Dịch Vụ Đồng Bộ Supabase (Không lưu dữ liệu ảnh lên Supabase, chỉ lưu cấu trúc bảng, chữ & ID ảnh Drive)

enum TrangThaiDongBo: String {
    case ranh = "idle"
    case dangDongBo = "syncing"
    case dangTaiVe = "downloading"
    case thanhCong = "success"
    case loi = "error"
}

final class DichVuSupabase {
    static let dungChung = DichVuSupabase()

    let supabaseUrl = "https://mrgsyxgucwochzhbzbrt.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yZ3N5eGd1Y3dvY2h6aGJ6YnJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjk3MTUsImV4cCI6MjA3OTgwNTcxNX0.nPuAqdbjXoZ-upuU_LQrv6IVNR_2NMeioquRap-BYcE"

    private let kEmail = "SUPABASE_USER_EMAIL"
    private let kUserId = "SUPABASE_USER_ID"
    private let kAccessToken = "SUPABASE_ACCESS_TOKEN"

    var emailNguoiDung: String? {
        get { UserDefaults.standard.string(forKey: kEmail) }
        set { UserDefaults.standard.setValue(newValue, forKey: kEmail) }
    }

    var userId: String? {
        get { UserDefaults.standard.string(forKey: kUserId) }
        set { UserDefaults.standard.setValue(newValue, forKey: kUserId) }
    }

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: kAccessToken) }
        set { UserDefaults.standard.setValue(newValue, forKey: kAccessToken) }
    }

    var daDangNhap: Bool {
        guard let uid = userId, let token = accessToken else { return false }
        return !uid.isEmpty && !token.isEmpty
    }

    private(set) var trangThai: TrangThaiDongBo = .ranh {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .trangThaiDongBoThayDoi, object: self.trangThai)
            }
        }
    }

    private init() {}

    private func ganHeaderChuan(_ req: inout URLRequest, dungTokenNguoiDung: Bool = true) {
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        let bearer = (dungTokenNguoiDung ? accessToken : nil) ?? supabaseAnonKey
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // MARK: Đăng nhập & Đăng ký
    func dangNhap(email: String, matKhau: String, hoanThanh: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=password") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        ganHeaderChuan(&req, dungTokenNguoiDung: false)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": matKhau])

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phản hồi không hợp lệ"])))
                }
                return
            }
            if let token = json["access_token"] as? String,
               let userObj = json["user"] as? [String: Any],
               let uid = userObj["id"] as? String {
                self?.accessToken = token
                self?.userId = uid
                self?.emailNguoiDung = (userObj["email"] as? String) ?? email
                // Tự động khôi phục ngay dữ liệu Ghi chú, Lịch, Nhắc nhở sau khi đăng nhập
                self?.khoiPhucTuMay { _, _ in
                    DispatchQueue.main.async { hoanThanh(.success(email)) }
                }
            } else {
                let msg = (json["error_description"] as? String) ?? (json["msg"] as? String) ?? "Sai email hoặc mật khẩu."
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Supabase", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    func dangKy(email: String, matKhau: String, hoanThanh: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/signup") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        ganHeaderChuan(&req, dungTokenNguoiDung: false)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": matKhau])

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phản hồi không hợp lệ"])))
                }
                return
            }
            if let token = json["access_token"] as? String,
               let userObj = json["user"] as? [String: Any],
               let uid = userObj["id"] as? String {
                self?.accessToken = token
                self?.userId = uid
                self?.emailNguoiDung = email
                DispatchQueue.main.async { hoanThanh(.success("Đã đăng ký và đăng nhập thành công!")) }
            } else if json["id"] != nil || json["user"] != nil {
                DispatchQueue.main.async { hoanThanh(.success("Đã tạo tài khoản! Hãy kiểm tra email để xác nhận.")) }
            } else {
                let msg = (json["msg"] as? String) ?? (json["error_description"] as? String) ?? "Không thể đăng ký."
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Supabase", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    func dangXuat() {
        emailNguoiDung = nil
        userId = nil
        accessToken = nil
    }

    // MARK: Đồng bộ Xưởng Cán lên Supabase (Chỉ lưu cấu trúc bảng, chữ và ID ảnh Google Drive)
    func dongBoXuongCanTuDong(hoanThanh: ((Bool, String) -> Void)? = nil) {
        trangThai = .dangDongBo
        let danhSachBang = KhoDuLieu.dungChung.danhSachBangXuongCan
        let boMaHoa = JSONEncoder()
        boMaHoa.dateEncodingStrategy = .iso8601

        guard let duLieuJSON = try? boMaHoa.encode(danhSachBang),
              let mangBangObj = try? JSONSerialization.jsonObject(with: duLieuJSON) as? [[String: Any]] else {
            trangThai = .loi
            hoanThanh?(false, "Lỗi mã hóa dữ liệu Xưởng Cán.")
            return
        }

        guard let url = URL(string: "\(supabaseUrl)/rest/v1/xuong_can_bang?on_conflict=id") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        ganHeaderChuan(&req)
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let cacDongUpsert: [[String: Any]] = danhSachBang.enumerated().map { idx, bang in
            return [
                "id": bang.id,
                "ten_bang": bang.tenBang,
                "mo_ta": bang.moTa,
                "du_lieu": mangBangObj[idx],
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: cacDongUpsert)

        URLSession.shared.dataTask(with: req) { [weak self] _, response, _ in
            guard let self else { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bangChuyenDungOK = (200...299).contains(code)

            if self.daDangNhap {
                self.saoLuuTatCaLenMay { ok, msg in
                    self.trangThai = (ok || bangChuyenDungOK) ? .thanhCong : .loi
                    self.henTatTrangThai()
                    DispatchQueue.main.async {
                        hoanThanh?(ok || bangChuyenDungOK, (ok || bangChuyenDungOK) ? "Đã đồng bộ bảng Xưởng Cán lên Supabase ☁️" : msg)
                    }
                }
            } else {
                self.trangThai = bangChuyenDungOK ? .thanhCong : .ranh
                self.henTatTrangThai()
                DispatchQueue.main.async {
                    if bangChuyenDungOK {
                        hoanThanh?(true, "Đã đồng bộ bảng Xưởng Cán lên Supabase ☁️")
                    } else {
                        hoanThanh?(false, "Đã lưu cục bộ. Để đồng bộ đám mây, hãy đăng nhập tài khoản ở Cài đặt hoặc chạy mã SQL tạo bảng xuong_can_bang trên Supabase.")
                    }
                }
            }
        }.resume()
    }

    func taiXuongCanTuSupabase(hoanThanh: @escaping (Bool, String) -> Void) {
        trangThai = .dangTaiVe
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/xuong_can_bang?select=du_lieu&order=updated_at.desc") else {
            trangThai = .loi
            hoanThanh(false, "URL không hợp lệ")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        ganHeaderChuan(&req)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let self else { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code),
               let data,
               let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               !rows.isEmpty {
                let duLieuMang = rows.compactMap { $0["du_lieu"] }
                if let jsonData = try? JSONSerialization.data(withJSONObject: duLieuMang),
                   let cacBang = ThuMucDuLieu.dungChung.giaiMaDuLieu([BangXuongCan].self, tu: jsonData),
                   !cacBang.isEmpty {
                    DispatchQueue.main.async {
                        KhoDuLieu.dungChung.luuBangXuongCan(cacBang, dongBoSupabase: false)
                        self.trangThai = .thanhCong
                        self.henTatTrangThai()
                        hoanThanh(true, "Đã tải \(cacBang.count) bảng Xưởng Cán từ Supabase!")
                    }
                    return
                }
            }

            if self.daDangNhap {
                self.khoiPhucTuMay { ok, msg in
                    self.trangThai = ok ? .thanhCong : .ranh
                    self.henTatTrangThai()
                    DispatchQueue.main.async { hoanThanh(ok, msg) }
                }
            } else {
                self.trangThai = .ranh
                DispatchQueue.main.async {
                    hoanThanh(false, "Chưa có dữ liệu trên bảng xuong_can_bang hoặc bạn chưa đăng nhập tài khoản đồng bộ.")
                }
            }
        }.resume()
    }

    /// Tự động kiểm tra và khôi phục Ghi chú / Lịch / Nhắc nhở từ Supabase khi mở app
    func tuDongKhoiPhucGhiChuNeuCan() {
        if daDangNhap {
            khoiPhucTuMay { _, _ in }
            return
        }
        // Nếu chưa đăng nhập nhưng bảng user_sync cho phép đọc bản sao lưu gần nhất và máy đang trống ghi chú:
        guard KhoDuLieu.dungChung.ghiChuNhanh.isEmpty,
              let url = URL(string: "\(supabaseUrl)/rest/v1/user_sync?select=backup_data&order=updated_at.desc&limit=1") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        ganHeaderChuan(&req, dungTokenNguoiDung: false)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(code),
                  let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let backup = arr.first?["backup_data"] as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.apDungDuLieuBackup(backup)
            }
        }.resume()
    }

    // MARK: Sao lưu & Khôi phục toàn bộ ứng dụng qua bảng `user_sync`
    func saoLuuTatCaLenMay(hoanThanh: @escaping (Bool, String) -> Void) {
        guard let uid = userId, !uid.isEmpty else {
            hoanThanh(false, "Vui lòng đăng nhập tài khoản trước khi sao lưu.")
            return
        }
        trangThai = .dangDongBo
        let kho = KhoDuLieu.dungChung
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let notesArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.ghiChuNhanh))) ?? []
        let calDict = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.ghiChuLich))) ?? [:]
        let remArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.nhacNho))) ?? []
        let xuongCanArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.danhSachBangXuongCan))) ?? []

        let backupData: [String: Any] = [
            "QUICK_NOTES": notesArr,
            "CALENDAR_NOTES": calDict,
            "USER_REMINDERS": remArr,
            "CYCLE_START_DATE": ISO8601DateFormatter().string(from: kho.caiDat.ngayBatDauChuKy),
            "NOTIF_ENABLED": kho.caiDat.batThongBao,
            "GEMINI_API_KEY": kho.caiDat.geminiApiKey,
            "WORK_CYCLE_PATTERN": kho.caiDat.chuKyLamViec,
            "XUONG_CAN_TABLES": xuongCanArr,
            "DRIVE_KEY": kho.caiDat.driveKey,
            "DRIVE_FOLDER_ID": kho.caiDat.driveFolderId,
            "DRIVE_SCRIPT_URL": kho.caiDat.driveScriptUrl
        ]

        let bodyObj: [String: Any] = [
            "user_id": uid,
            "backup_data": backupData,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        guard let url = URL(string: "\(supabaseUrl)/rest/v1/user_sync?on_conflict=user_id") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        ganHeaderChuan(&req)
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyObj)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            if let error {
                self?.trangThai = .loi
                self?.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(false, error.localizedDescription) }
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code) {
                self?.trangThai = .thanhCong
                self?.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(true, "Đã lưu dữ liệu lên đám mây Supabase ☁️") }
            } else {
                let errText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(code)"
                self?.trangThai = .loi
                self?.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(false, "Lỗi sao lưu: \(errText)") }
            }
        }.resume()
    }

    func khoiPhucTuMay(hoanThanh: @escaping (Bool, String) -> Void) {
        guard let uid = userId, !uid.isEmpty else {
            hoanThanh(false, "Vui lòng đăng nhập tài khoản trước khi khôi phục.")
            return
        }
        trangThai = .dangTaiVe
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/user_sync?user_id=eq.\(uid)&select=backup_data") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        ganHeaderChuan(&req)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            if let error {
                self?.trangThai = .loi
                self?.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(false, error.localizedDescription) }
                return
            }
            guard let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = arr.first,
                  let backup = first["backup_data"] as? [String: Any] else {
                self?.trangThai = .ranh
                DispatchQueue.main.async { hoanThanh(false, "Không tìm thấy bản sao lưu nào trên đám mây.") }
                return
            }

            DispatchQueue.main.async {
                self?.apDungDuLieuBackup(backup)
                self?.trangThai = .thanhCong
                self?.henTatTrangThai()
                hoanThanh(true, "Đã khôi phục toàn bộ dữ liệu (Ghi chú, Lịch, Nhắc nhở, Xưởng Cán) về máy!")
            }
        }.resume()
    }

    /// Giải mã linh hoạt cả dạng Mảng JSON lẫn chuỗi JSON (Stringified JSON) từ bản React Native cũ
    private func layDataJSON(tu giaTri: Any?) -> Data? {
        guard let giaTri else { return nil }
        if let str = giaTri as? String {
            return str.data(using: .utf8)
        }
        return try? JSONSerialization.data(withJSONObject: giaTri)
    }

    private func apDungDuLieuBackup(_ backup: [String: Any]) {
        let tm = ThuMucDuLieu.dungChung
        let kho = KhoDuLieu.dungChung

        if let d = layDataJSON(tu: backup["QUICK_NOTES"]),
           let list = tm.giaiMaDuLieu([GhiChuNhanh].self, tu: d) {
            kho.luuGhiChuNhanh(list)
        }
        if let d = layDataJSON(tu: backup["CALENDAR_NOTES"]),
           let dict = tm.giaiMaDuLieu([String: GhiChuNgay].self, tu: d) {
            kho.luuGhiChuLich(dict)
        }
        if let d = layDataJSON(tu: backup["USER_REMINDERS"]),
           let list = tm.giaiMaDuLieu([SuKienNhacNho].self, tu: d) {
            kho.luuNhacNho(list)
        }
        if let d = layDataJSON(tu: backup["XUONG_CAN_TABLES"]),
           let list = tm.giaiMaDuLieu([BangXuongCan].self, tu: d), !list.isEmpty {
            kho.luuBangXuongCan(list, dongBoSupabase: false)
        }

        var cd = kho.caiDat
        if let sDate = backup["CYCLE_START_DATE"] as? String,
           let d = TienIchLich.docNgayISO(sDate) {
            cd.ngayBatDauChuKy = d
        }
        if let notif = backup["NOTIF_ENABLED"] as? Bool {
            cd.batThongBao = notif
        } else if let notifStr = backup["NOTIF_ENABLED"] as? String {
            cd.batThongBao = (notifStr == "true")
        }
        if let gKey = backup["GEMINI_API_KEY"] as? String, !gKey.isEmpty {
            cd.geminiApiKey = gKey
        }
        if let pat = backup["WORK_CYCLE_PATTERN"] as? [String], !pat.isEmpty {
            cd.chuKyLamViec = pat
        } else if let dPat = layDataJSON(tu: backup["WORK_CYCLE_PATTERN"]),
                  let pat = tm.giaiMaDuLieu([String].self, tu: dPat), !pat.isEmpty {
            cd.chuKyLamViec = pat
        }
        if let dKey = backup["DRIVE_KEY"] as? String, !dKey.isEmpty {
            cd.driveKey = dKey
        }
        if let dFolder = backup["DRIVE_FOLDER_ID"] as? String, !dFolder.isEmpty {
            cd.driveFolderId = dFolder
        }
        if let dScript = backup["DRIVE_SCRIPT_URL"] as? String, !dScript.isEmpty {
            cd.driveScriptUrl = dScript
        }
        kho.luuCaiDat(cd)
        NotificationCenter.default.post(name: .duLieuDongBoXong, object: nil)
    }

    private func henTatTrangThai() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.trangThai = .ranh
        }
    }

    static let sqlTaoBangXuongCan = """
    -- Chạy đoạn SQL này trong Supabase -> SQL Editor để tạo bảng đồng bộ Xưởng Cán:
    create table if not exists public.xuong_can_bang (
      id text primary key,
      ten_bang text not null,
      mo_ta text default '',
      du_lieu jsonb not null,
      updated_at timestamptz default now()
    );

    alter table public.xuong_can_bang enable row level security;

    drop policy if exists "Cho phep doc ghi xuong_can_bang" on public.xuong_can_bang;

    create policy "Cho phep doc ghi xuong_can_bang"
      on public.xuong_can_bang
      for all
      using (true)
      with check (true);
    """
}

// MARK: - 4. Dịch Vụ Gemini AI (Media Creator)

final class DichVuGemini {
    static let dungChung = DichVuGemini()
    private init() {}

    func goiGemini(prompt: String, hoanThanh: @escaping (Result<String, Error>) -> Void) {
        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có Gemini API Key. Hãy vào tab Cài đặt để nhập Key Gemini!"])))
            return
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)") else {
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phản hồi AI không hợp lệ."])))
                }
                return
            }
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                DispatchQueue.main.async { hoanThanh(.success(text)) }
            } else if let err = json["error"] as? [String: Any],
                      let msg = err["message"] as? String {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            } else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không nhận được nội dung từ Gemini."])))
                }
            }
        }.resume()
    }
}
