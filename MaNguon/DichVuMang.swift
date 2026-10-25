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

    func taiAnh(thongTin: ThongTinAnhXuongCan, hoanThanh: @escaping (UIImage?) -> Void) {
        if let anhCoSan = layAnhTucThi(maAnh: thongTin.maAnh) {
            hoanThanh(anhCoSan)
            return
        }
        if let fileId = thongTin.driveFileId, !fileId.isEmpty,
           let anhDriveCache = layAnhTucThi(maAnh: fileId) {
            hoanThanh(anhDriveCache)
            return
        }
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

// MARK: - 2. Dịch Vụ Lưu & Tải Ảnh Google Drive Trực Tiếp Qua Google Drive REST API v3 (OAuth 2.0)

final class DichVuGoogleDrive {
    static let dungChung = DichVuGoogleDrive()
    private init() {}

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

    /// Tải ảnh trực tiếp lên Google Drive REST API v3 bằng OAuth 2.0 (Client ID + Client Secret + Refresh Token) hoặc Access Token
    func taiAnhLenDrive(
        anh: UIImage,
        tenTep: String,
        hoanThanh: @escaping (_ fileId: String?, _ driveUrl: String?, _ thongBaoLoi: String?) -> Void
    ) {
        let anhNen = thuNhoAnhNeuCan(anh, kichThuocToiDa: 1600)
        guard let jpegData = anhNen.jpegData(compressionQuality: 0.80) else {
            hoanThanh(nil, nil, "Không thể tạo dữ liệu JPEG từ ảnh.")
            return
        }

        let cd = KhoDuLieu.dungChung.caiDat
        let folderId = Self.chuanHoaFolderId(cd.driveFolderId)
        let clientId = cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyHoacToken = cd.driveKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // Cách 1 (Khuyên dùng & Bền vững nhất): OAuth 2.0 Refresh Token + Client ID + Client Secret gọi thẳng Google Drive API v3
        if !refreshToken.isEmpty && !clientId.isEmpty && !clientSecret.isEmpty {
            layAccessTokenTuRefreshToken(clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken) { [weak self] token, loi in
                guard let self else { return }
                if let token {
                    self.taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: token, hoanThanh: hoanThanh)
                } else {
                    DispatchQueue.main.async {
                        hoanThanh(nil, nil, loi ?? "Không lấy được Access Token từ Refresh Token.")
                    }
                }
            }
            return
        }

        // Cách 2: Nếu người dùng dán trực tiếp OAuth2 Access Token (bắt đầu bằng ya29.) vào ô Refresh Token hoặc ô Access Token
        if refreshToken.hasPrefix("ya29.") {
            taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: refreshToken, hoanThanh: hoanThanh)
            return
        }
        if keyHoacToken.hasPrefix("ya29.") {
            taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: keyHoacToken, hoanThanh: hoanThanh)
            return
        }

        // Cách 3 (Tùy chọn dự phòng nếu vẫn còn lưu link Script cũ)
        let scriptStr = cd.driveScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scriptStr.isEmpty, let scriptURL = URL(string: scriptStr) {
            taiLenQuaAppsScript(url: scriptURL, jpegData: jpegData, tenTep: tenTep, folderId: folderId, hoanThanh: hoanThanh)
            return
        }

        hoanThanh(
            nil,
            nil,
            "Chưa kết nối OAuth 2.0 Google Drive! Hãy bấm biểu tượng Ổ đĩa ở góc trên trái màn hình Xưởng Cán để điền Client ID, Client Secret và Refresh Token (hoặc Access Token ya29...)."
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
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                hoanThanh(nil, "Phản hồi OAuth2 không hợp lệ.")
                return
            }
            if let accessToken = json["access_token"] as? String {
                hoanThanh(accessToken, nil)
            } else {
                let errDesc = (json["error_description"] as? String) ?? (json["error"] as? String) ?? "Kiểm tra lại Client ID, Client Secret và Refresh Token."
                hoanThanh(nil, "Lỗi OAuth2: \(errDesc)")
            }
        }.resume()
    }

    private func taiLenQuaDriveREST(
        jpegData: Data,
        tenTep: String,
        folderId: String,
        bearerToken: String,
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
        req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

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

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
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
                // Mở quyền xem ảnh để các máy khác có thể tải về Cache
                self?.moQuyenXemFileDrive(fileId: fileId, bearerToken: bearerToken)
                DispatchQueue.main.async { hoanThanh(fileId, driveUrl, nil) }
            } else {
                var chiTietLoi = "HTTP \(statusCode)"
                if let data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errObj = json["error"] as? [String: Any],
                   let msg = errObj["message"] as? String {
                    chiTietLoi = msg
                }
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Lỗi tải lên Google Drive API v3: \(chiTietLoi)")
                }
            }
        }.resume()
    }

    private func moQuyenXemFileDrive(fileId: String, bearerToken: String) {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)/permissions") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["role": "reader", "type": "anyone"])
        URLSession.shared.dataTask(with: req).resume()
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
                DispatchQueue.main.async { hoanThanh(nil, nil, error.localizedDescription) }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fileId = json["fileId"] as? String, !fileId.isEmpty {
                let viewUrl = (json["url"] as? String) ?? "https://drive.google.com/uc?export=view&id=\(fileId)"
                DispatchQueue.main.async { hoanThanh(fileId, viewUrl, nil) }
            } else {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, "Lỗi kết nối Drive (HTTP \(statusCode)). Hãy chuyển sang dùng OAuth 2.0 (Client ID / Secret / Refresh Token) trong mục Cấu hình Drive.")
                }
            }
        }.resume()
    }

    func taiAnhTuDrive(fileId: String, driveUrl: String?, hoanThanh: @escaping (UIImage?) -> Void) {
        let cd = KhoDuLieu.dungChung.caiDat
        let clientId = cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nếu có OAuth2 Refresh Token, tải trực tiếp qua Drive API v3 alt=media
        if !refreshToken.isEmpty && !clientId.isEmpty && !clientSecret.isEmpty {
            layAccessTokenTuRefreshToken(clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken) { token, _ in
                guard let token,
                      let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media") else {
                    self.taiCongKhaiTuDrive(fileId: fileId, hoanThanh: hoanThanh)
                    return
                }
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: req) { data, _, _ in
                    if let data, let img = UIImage(data: data) {
                        hoanThanh(img)
                    } else {
                        self.taiCongKhaiTuDrive(fileId: fileId, hoanThanh: hoanThanh)
                    }
                }.resume()
            }
            return
        }
        taiCongKhaiTuDrive(fileId: fileId, hoanThanh: hoanThanh)
    }

    private func taiCongKhaiTuDrive(fileId: String, hoanThanh: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: "https://drive.google.com/uc?export=download&id=\(fileId)") else {
            hoanThanh(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else {
                hoanThanh(nil)
                return
            }
            hoanThanh(img)
        }.resume()
    }
}

// MARK: - 3. Dịch Vụ Đồng Bộ Supabase Tự Động (Tự động tạo & lưu bảng Xưởng Cán vào user_sync, không cần tạo bảng SQL thủ công)

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

    /// Tự động lưu các bảng Xưởng Cán được tạo trong App thẳng lên Supabase (qua user_sync sẵn có) mà không cần tạo bảng thủ công trên Supabase
    func dongBoXuongCanTuDong(hoanThanh: ((Bool, String) -> Void)? = nil) {
        if daDangNhap {
            saoLuuTatCaLenMay { ok, msg in
                hoanThanh?(ok, ok ? "Đã tự động đồng bộ các bảng Xưởng Cán lên Supabase ☁️" : msg)
            }
        } else {
            hoanThanh?(false, "Đã lưu bảng trên máy. Hãy đăng nhập tài khoản ở tab Cài đặt để tự động đồng bộ lên Supabase.")
        }
    }

    func taiXuongCanTuSupabase(hoanThanh: @escaping (Bool, String) -> Void) {
        if daDangNhap {
            khoiPhucTuMay(hoanThanh: hoanThanh)
        } else {
            tuDongKhoiPhucGhiChuNeuCan()
            hoanThanh(false, "Hãy đăng nhập tài khoản ở tab Cài đặt để tải dữ liệu từ Supabase.")
        }
    }

    func tuDongKhoiPhucGhiChuNeuCan() {
        if daDangNhap {
            khoiPhucTuMay { _, _ in }
            return
        }
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
            "DRIVE_CLIENT_ID": kho.caiDat.driveClientId,
            "DRIVE_CLIENT_SECRET": kho.caiDat.driveClientSecret,
            "DRIVE_REFRESH_TOKEN": kho.caiDat.driveRefreshToken
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
                DispatchQueue.main.async { hoanThanh(true, "Đã tự động đồng bộ toàn bộ bảng Xưởng Cán & Ghi chú lên Supabase ☁️") }
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
        if let dClientId = backup["DRIVE_CLIENT_ID"] as? String, !dClientId.isEmpty {
            cd.driveClientId = dClientId
        }
        if let dClientSecret = backup["DRIVE_CLIENT_SECRET"] as? String, !dClientSecret.isEmpty {
            cd.driveClientSecret = dClientSecret
        }
        if let dRefresh = backup["DRIVE_REFRESH_TOKEN"] as? String, !dRefresh.isEmpty {
            cd.driveRefreshToken = dRefresh
        }
        kho.luuCaiDat(cd, thongBao: false)
        NotificationCenter.default.post(name: .duLieuDongBoXong, object: nil)
    }

    private func henTatTrangThai() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.trangThai = .ranh
        }
    }
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
