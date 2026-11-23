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
        // Nếu người dùng nhập tên thư mục có dấu cách (VD: "Anh app ghi chu") thay vì mã ID, trả về rỗng để lưu vào thư mục gốc
        if raw.contains(" ") { return "" }
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

        let clientId = cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? HangSoDriveMacDinh.clientId
            : cd.driveClientId.trimmingCharacters(in: .whitespacesAndNewlines)

        let clientSecret = cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? HangSoDriveMacDinh.clientSecret
            : cd.driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        let refreshToken = cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? HangSoDriveMacDinh.refreshToken
            : cd.driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

        if refreshToken.hasPrefix("ya29.") {
            taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: refreshToken, daThuLaiRoot: false, hoanThanh: hoanThanh)
            return
        }

        layAccessTokenTuRefreshToken(clientId: clientId, clientSecret: clientSecret, refreshToken: refreshToken) { [weak self] token, loi in
            guard let self else { return }
            if let token {
                self.taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: folderId, bearerToken: token, daThuLaiRoot: false, hoanThanh: hoanThanh)
            } else {
                DispatchQueue.main.async {
                    hoanThanh(nil, nil, loi ?? "Không lấy được Access Token từ Refresh Token.")
                }
            }
        }
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
        daThuLaiRoot: Bool,
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
        if !folderId.isEmpty && !folderId.contains(" ") {
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
                self?.moQuyenXemFileDrive(fileId: fileId, bearerToken: bearerToken)
                DispatchQueue.main.async { hoanThanh(fileId, driveUrl, nil) }
            } else if statusCode == 404 && !folderId.isEmpty && !daThuLaiRoot {
                // Nếu Folder ID không tồn tại hoặc không có quyền truy cập, tự động tải thẳng vào thư mục gốc Google Drive!
                self?.taiLenQuaDriveREST(
                    jpegData: jpegData,
                    tenTep: tenTep,
                    folderId: "",
                    bearerToken: bearerToken,
                    daThuLaiRoot: true,
                    hoanThanh: hoanThanh
                )
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

    func taiAnhTuDrive(fileId: String, driveUrl: String?, hoanThanh: @escaping (UIImage?) -> Void) {
        let cd = KhoDuLieu.dungChung.caiDat
        let clientId = cd.driveClientId.isEmpty ? HangSoDriveMacDinh.clientId : cd.driveClientId
        let clientSecret = cd.driveClientSecret.isEmpty ? HangSoDriveMacDinh.clientSecret : cd.driveClientSecret
        let refreshToken = cd.driveRefreshToken.isEmpty ? HangSoDriveMacDinh.refreshToken : cd.driveRefreshToken

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

// MARK: - 3. Dịch Vụ Đồng Bộ Supabase Tự Động (Tự động làm mới JWT khi hết hạn PGRST303)

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
    private let kRefreshToken = "SUPABASE_REFRESH_TOKEN"
    private let kSavedPassword = "SUPABASE_SAVED_PASSWORD"
    private var tacVuDongBoCho: DispatchWorkItem?

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

    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: kRefreshToken) }
        set { UserDefaults.standard.setValue(newValue, forKey: kRefreshToken) }
    }

    private var matKhauLuuTam: String? {
        get { UserDefaults.standard.string(forKey: kSavedPassword) }
        set { UserDefaults.standard.setValue(newValue, forKey: kSavedPassword) }
    }

    var daDangNhap: Bool {
        guard let uid = userId else { return false }
        return !uid.isEmpty
    }

    private(set) var trangThai: TrangThaiDongBo = .ranh {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .trangThaiDongBoThayDoi, object: self.trangThai)
            }
        }
    }

    private init() {}

    /// Kiểm tra xem chuỗi JWT có bị hết hạn (hoặc sắp hết hạn trong 2 phút tới) hay không
    private func tokenDaHetHan(_ token: String?) -> Bool {
        guard let token, !token.isEmpty else { return true }
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return true }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return false
        }
        return Date().timeIntervalSince1970 + 120 >= exp
    }

    /// Tự động lấy Bearer Token hợp lệ (tự động Refresh nếu JWT hết hạn để không bao giờ bị lỗi PGRST303 JWT expired)
    private func layTokenHopLe(hoanThanh: @escaping (String?) -> Void) {
        if let token = accessToken, !tokenDaHetHan(token) {
            hoanThanh(token)
            return
        }

        // 1. Thử làm mới bằng refresh_token
        if let rf = refreshToken, !rf.isEmpty {
            lamMoiToken(refreshToken: rf) { [weak self] tokenMoi in
                if let tokenMoi {
                    hoanThanh(tokenMoi)
                } else {
                    self?.thuDangNhapNgamHoacFallback(hoanThanh: hoanThanh)
                }
            }
            return
        }

        // 2. Nếu phiên cũ từ bản trước chưa có refresh_token, thử đăng nhập ngầm hoặc dùng anonKey
        thuDangNhapNgamHoacFallback(hoanThanh: hoanThanh)
    }

    private func lamMoiToken(refreshToken: String, hoanThanh: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=refresh_token") else {
            hoanThanh(nil)
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(code),
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess = json["access_token"] as? String else {
                hoanThanh(nil)
                return
            }
            self?.accessToken = newAccess
            if let newRefresh = json["refresh_token"] as? String {
                self?.refreshToken = newRefresh
            }
            hoanThanh(newAccess)
        }.resume()
    }

    private func thuDangNhapNgamHoacFallback(hoanThanh: @escaping (String?) -> Void) {
        if let email = emailNguoiDung, !email.isEmpty,
           let pass = matKhauLuuTam, !pass.isEmpty {
            dangNhap(email: email, matKhau: pass, tuDongKhoiPhuc: false) { [weak self] _ in
                hoanThanh(self?.accessToken ?? self?.supabaseAnonKey)
            }
        } else {
            // Nếu token cũ đã hết hạn mà chưa lưu mật khẩu từ bản cũ, dùng supabaseAnonKey
            hoanThanh(supabaseAnonKey)
        }
    }

    func dangNhap(email: String, matKhau: String, tuDongKhoiPhuc: Bool = true, hoanThanh: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=password") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                self?.refreshToken = json["refresh_token"] as? String
                self?.userId = uid
                self?.emailNguoiDung = (userObj["email"] as? String) ?? email
                self?.matKhauLuuTam = matKhau
                if tuDongKhoiPhuc {
                    self?.khoiPhucTuMay { _, _ in
                        DispatchQueue.main.async { hoanThanh(.success(email)) }
                    }
                } else {
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
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                self?.refreshToken = json["refresh_token"] as? String
                self?.userId = uid
                self?.emailNguoiDung = email
                self?.matKhauLuuTam = matKhau
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
        refreshToken = nil
        matKhauLuuTam = nil
    }

    func dongBoDuLieuTuDong() {
        guard daDangNhap else { return }

        tacVuDongBoCho?.cancel()
        let tacVu = DispatchWorkItem { [weak self] in
            guard let self, self.daDangNhap else { return }
            self.saoLuuTatCaLenMay { _, _ in }
        }
        tacVuDongBoCho = tacVu
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: tacVu)
    }

    func dongBoXuongCanTuDong(hoanThanh: ((Bool, String) -> Void)? = nil) {
        if daDangNhap {
            saoLuuTatCaLenMay { ok, msg in
                hoanThanh?(ok, ok ? "Đã tự động đồng bộ các bảng Xưởng Cán lên Supabase ☁️" : msg)
            }
        } else {
            hoanThanh?(false, "Đã lưu bảng trên máy. Hãy đăng nhập tài khoản ở tab Cài đặt để đồng bộ lên Supabase.")
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
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        layTokenHopLe { [weak self] bearer in
            guard let self else { return }
            self.thucHienSaoLuu(uid: uid, bearer: bearer ?? self.supabaseAnonKey, daThuLamMoi: false, hoanThanh: hoanThanh)
        }
    }

    private func thucHienSaoLuu(
        uid: String,
        bearer: String,
        daThuLamMoi: Bool,
        hoanThanh: @escaping (Bool, String) -> Void
    ) {
        let kho = KhoDuLieu.dungChung
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let notesArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.ghiChuNhanh))) ?? []
        let calDict = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.ghiChuLich))) ?? [:]
        let remArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.nhacNho))) ?? []
        let xuongCanArr = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.danhSachBangXuongCan))) ?? []
        let thucDonObj = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.duLieuThucDon))) ?? [:]
        let lenhSXObj = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.duLieuLenhSX))) ?? [:]
        let baoCaoObj = (try? JSONSerialization.jsonObject(with: encoder.encode(kho.duLieuBaoCao))) ?? [:]

        let backupData: [String: Any] = [
            "LENH_SAN_XUAT": lenhSXObj,
            "BAO_CAO_TBM": baoCaoObj,
            "TAB_ORDER": kho.caiDat.thuTuTab,
            "QUICK_NOTES": notesArr,
            "CALENDAR_NOTES": calDict,
            "USER_REMINDERS": remArr,
            "CYCLE_START_DATE": ISO8601DateFormatter().string(from: kho.caiDat.ngayBatDauChuKy),
            "NOTIF_ENABLED": kho.caiDat.batThongBao,
            "MENU_NOTIF_ENABLED": kho.caiDat.batThongBaoThucDon,
            "MENU_NOTIF_MORNING_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoThucDonSang),
            "MENU_NOTIF_NOON_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoThucDonTrua),
            "MENU_NOTIF_AFTERNOON_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoThucDonChieu),
            "MENU_NOTIF_NIGHT_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoThucDonDem),
            "LENH_SX_NOTIF_ENABLED": kho.caiDat.batThongBaoLenhSX,
            "LENH_SX_NOTIF_DAY_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoLenhSXCaNgay),
            "LENH_SX_NOTIF_NIGHT_TIME": ISO8601DateFormatter().string(from: kho.caiDat.gioThongBaoLenhSXCaDem),
            "MENU_DATA": thucDonObj,
            "GEMINI_API_KEY": kho.caiDat.geminiApiKey,
            "GEMINI_MODEL": kho.caiDat.geminiModel,
            "WORK_CYCLE_PATTERN": kho.caiDat.chuKyLamViec,
            "XUONG_CAN_TABLES": xuongCanArr,
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
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyObj)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.trangThai = .loi
                self.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(false, error.localizedDescription) }
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code) {
                self.trangThai = .thanhCong
                self.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(true, "Đã tự động đồng bộ toàn bộ bảng Xưởng Cán & Ghi chú lên Supabase ☁️") }
                return
            }

            let errText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(code)"
            if (code == 401 || errText.contains("PGRST303") || errText.contains("JWT expired")) && !daThuLamMoi {
                // Xóa token cũ đã hết hạn và thử lại bằng anonKey hoặc làm mới phiên
                self.accessToken = nil
                self.layTokenHopLe { tokenMoi in
                    self.thucHienSaoLuu(
                        uid: uid,
                        bearer: tokenMoi ?? self.supabaseAnonKey,
                        daThuLamMoi: true,
                        hoanThanh: hoanThanh
                    )
                }
                return
            }

            self.trangThai = .loi
            self.henTatTrangThai()
            DispatchQueue.main.async {
                if errText.contains("PGRST303") || errText.contains("JWT expired") || code == 401 {
                    hoanThanh(false, "Phiên đăng nhập từ bản cũ đã hết hạn. Bạn hãy vào tab Cài đặt -> bấm Đăng xuất rồi Đăng nhập lại 1 lần để ứng dụng tự động gia hạn vĩnh viễn nhé!")
                } else {
                    hoanThanh(false, "Lỗi sao lưu: \(errText)")
                }
            }
        }.resume()
    }

    func khoiPhucTuMay(hoanThanh: @escaping (Bool, String) -> Void) {
        guard let uid = userId, !uid.isEmpty else {
            hoanThanh(false, "Vui lòng đăng nhập tài khoản trước khi khôi phục.")
            return
        }
        trangThai = .dangTaiVe
        layTokenHopLe { [weak self] bearer in
            guard let self else { return }
            self.thucHienKhoiPhuc(uid: uid, bearer: bearer ?? self.supabaseAnonKey, daThuLamMoi: false, hoanThanh: hoanThanh)
        }
    }

    private func thucHienKhoiPhuc(
        uid: String,
        bearer: String,
        daThuLamMoi: Bool,
        hoanThanh: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/user_sync?user_id=eq.\(uid)&select=backup_data") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.trangThai = .loi
                self.henTatTrangThai()
                DispatchQueue.main.async { hoanThanh(false, error.localizedDescription) }
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let rawText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            if (code == 401 || rawText.contains("PGRST303") || rawText.contains("JWT expired")) && !daThuLamMoi {
                self.accessToken = nil
                self.layTokenHopLe { tokenMoi in
                    self.thucHienKhoiPhuc(
                        uid: uid,
                        bearer: tokenMoi ?? self.supabaseAnonKey,
                        daThuLamMoi: true,
                        hoanThanh: hoanThanh
                    )
                }
                return
            }

            guard (200...299).contains(code),
                  let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = arr.first,
                  let backup = first["backup_data"] as? [String: Any] else {
                self.trangThai = .ranh
                DispatchQueue.main.async {
                    if rawText.contains("PGRST303") || rawText.contains("JWT expired") || code == 401 {
                        hoanThanh(false, "Phiên đăng nhập từ bản cũ đã hết hạn. Bạn hãy vào tab Cài đặt -> bấm Đăng xuất rồi Đăng nhập lại 1 lần để tự động gia hạn vĩnh viễn nhé!")
                    } else {
                        hoanThanh(false, "Không tìm thấy bản sao lưu nào trên đám mây.")
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.apDungDuLieuBackup(backup)
                self.trangThai = .thanhCong
                self.henTatTrangThai()
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
            kho.luuGhiChuNhanh(list, dongBoSupabase: false)
        }
        if let d = layDataJSON(tu: backup["CALENDAR_NOTES"]),
           let dict = tm.giaiMaDuLieu([String: GhiChuNgay].self, tu: d) {
            kho.luuGhiChuLich(dict, dongBoSupabase: false)
        }
        if let d = layDataJSON(tu: backup["USER_REMINDERS"]),
           let list = tm.giaiMaDuLieu([SuKienNhacNho].self, tu: d) {
            kho.luuNhacNho(list)
        }
        if let d = layDataJSON(tu: backup["XUONG_CAN_TABLES"]),
           let list = tm.giaiMaDuLieu([BangXuongCan].self, tu: d), !list.isEmpty {
            kho.luuBangXuongCan(KhoDuLieu.sapXepDanhSachBangAZ(list), dongBoSupabase: false)
        }
        if let d = layDataJSON(tu: backup["MENU_DATA"]),
           let td = tm.giaiMaDuLieu(DuLieuThucDon.self, tu: d), !td.danhSachNgay.isEmpty {
            kho.luuDuLieuThucDon(td, dongBoSupabase: false)
        }
        if let d = layDataJSON(tu: backup["LENH_SAN_XUAT"]),
           let lsx = tm.giaiMaDuLieu(DuLieuLenhSanXuat.self, tu: d) {
            kho.luuDuLieuLenhSX(lsx, dongBoSupabase: false)
        }
        if let d = layDataJSON(tu: backup["BAO_CAO_TBM"]),
           let bc = tm.giaiMaDuLieu(DuLieuBaoCaoTBM.self, tu: d),
           !bc.noiDungMau.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            kho.luuDuLieuBaoCao(bc, dongBoSupabase: false)
        }

        var cd = kho.caiDat
        let daCoThuTuCucBo = (UserDefaults.standard.stringArray(forKey: "SAVED_TAB_ORDER_V1") != nil)
        if !daCoThuTuCucBo {
            if let tabOrd = backup["TAB_ORDER"] as? [String], !tabOrd.isEmpty {
                cd.thuTuTab = CaiDatUngDung.chuanHoaDanhSachTab(tabOrd).map(\.rawValue)
            } else if let dTab = layDataJSON(tu: backup["TAB_ORDER"]),
                      let tabOrd = tm.giaiMaDuLieu([String].self, tu: dTab), !tabOrd.isEmpty {
                cd.thuTuTab = CaiDatUngDung.chuanHoaDanhSachTab(tabOrd).map(\.rawValue)
            }
        }
        if let menuNotif = backup["MENU_NOTIF_ENABLED"] as? Bool {
            cd.batThongBaoThucDon = menuNotif
        }
        if let sMorning = backup["MENU_NOTIF_MORNING_TIME"] as? String,
           let dMorning = TienIchLich.docNgayISO(sMorning) {
            cd.gioThongBaoThucDonSang = dMorning
        }
        if let sNoon = backup["MENU_NOTIF_NOON_TIME"] as? String,
           let dNoon = TienIchLich.docNgayISO(sNoon) {
            cd.gioThongBaoThucDonTrua = dNoon
        }
        if let sAfternoon = backup["MENU_NOTIF_AFTERNOON_TIME"] as? String,
           let dAfternoon = TienIchLich.docNgayISO(sAfternoon) {
            cd.gioThongBaoThucDonChieu = dAfternoon
        }
        if let sNightTime = backup["MENU_NOTIF_NIGHT_TIME"] as? String,
           let dNight = TienIchLich.docNgayISO(sNightTime) {
            cd.gioThongBaoThucDonDem = dNight
        }
        if let lsxNotif = backup["LENH_SX_NOTIF_ENABLED"] as? Bool {
            cd.batThongBaoLenhSX = lsxNotif
        }
        if let sLsxDay = backup["LENH_SX_NOTIF_DAY_TIME"] as? String,
           let dLsxDay = TienIchLich.docNgayISO(sLsxDay) {
            cd.gioThongBaoLenhSXCaNgay = dLsxDay
        }
        if let sLsxNight = backup["LENH_SX_NOTIF_NIGHT_TIME"] as? String,
           let dLsxNight = TienIchLich.docNgayISO(sLsxNight) {
            cd.gioThongBaoLenhSXCaDem = dLsxNight
        }
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
        if let gModel = backup["GEMINI_MODEL"] as? String, !gModel.isEmpty {
            cd.geminiModel = gModel
        }
        if let pat = backup["WORK_CYCLE_PATTERN"] as? [String], !pat.isEmpty {
            cd.chuKyLamViec = pat
        } else if let dPat = layDataJSON(tu: backup["WORK_CYCLE_PATTERN"]),
                  let pat = tm.giaiMaDuLieu([String].self, tu: dPat), !pat.isEmpty {
            cd.chuKyLamViec = pat
        }
        if let dFolder = backup["DRIVE_FOLDER_ID"] as? String, !dFolder.isEmpty, !dFolder.contains(" ") {
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
        cd.chuanHoaKeyDrive()
        kho.luuCaiDat(cd, thongBao: false)
        NotificationCenter.default.post(name: .duLieuDongBoXong, object: nil)
    }

    private func henTatTrangThai() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.trangThai = .ranh
        }
    }
}

// MARK: - 4. Dịch Vụ Gemini AI (Hỗ Trợ 3.5 Flash Lite & 3.1 Flash Lite Có Tự Động Dự Phòng)

final class DichVuGemini {
    static let dungChung = DichVuGemini()
    private(set) var modelVuaSuDung: String = "gemini-3.5-flash-lite"
    private init() {}

    func danhSachModelThuNghiem() -> [String] {
        let modelChon = KhoDuLieu.dungChung.caiDat.geminiModel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if modelChon.contains("3.1") {
            return [
                "gemini-3.1-flash-lite",
                "gemini-3.1-flash-lite-preview",
                "gemini-3.5-flash-lite",
                "gemini-2.5-flash-lite"
            ]
        } else {
            return [
                "gemini-3.5-flash-lite",
                "gemini-3.1-flash-lite",
                "gemini-3.1-flash-lite-preview",
                "gemini-2.5-flash-lite"
            ]
        }
    }

    static func tenThanThien(cua model: String) -> String {
        let m = model.lowercased()
        if m.contains("3.5") { return "Gemini 3.5 Flash Lite" }
        if m.contains("3.1") { return "Gemini 3.1 Flash Lite" }
        if m.contains("2.5") { return "Gemini 2.5 Flash Lite" }
        return model
    }

    func goiGemini(prompt: String, hoanThanh: @escaping (Result<String, Error>) -> Void) {
        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có Gemini API Key. Hãy vào tab Cài đặt hoặc bấm Cài đặt nhanh Key để nhập Key Gemini!"])))
            return
        }
        let danhSachModels = danhSachModelThuNghiem()
        goiTextTheoDanhSachModel(prompt: prompt, key: key, models: danhSachModels, chiSo: 0, hoanThanh: hoanThanh)
    }

    private func goiTextTheoDanhSachModel(
        prompt: String,
        key: String,
        models: [String],
        chiSo: Int,
        hoanThanh: @escaping (Result<String, Error>) -> Void
    ) {
        guard chiSo < models.count else {
            DispatchQueue.main.async {
                hoanThanh(.failure(NSError(domain: "Gemini", code: -10, userInfo: [NSLocalizedDescriptionKey: "Tất cả các model (3.5 Flash Lite & 3.1 Flash Lite) hiện đều quá tải hoặc hết hạn mức. Vui lòng thử lại sau ít giây."])))
            }
            return
        }
        let model = models[chiSo]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            goiTextTheoDanhSachModel(prompt: prompt, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 35
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if chiSo + 1 < models.count {
                    self.goiTextTheoDanhSachModel(prompt: prompt, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
                } else {
                    DispatchQueue.main.async {
                        hoanThanh(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phản hồi AI không hợp lệ."])))
                    }
                }
                return
            }

            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                self.modelVuaSuDung = model
                DispatchQueue.main.async { hoanThanh(.success(text)) }
                return
            }

            let errObj = json["error"] as? [String: Any]
            let msg = (errObj?["message"] as? String) ?? "HTTP \(statusCode)"
            let msgLower = msg.lowercased()

            // Nếu lỗi do Key không hợp lệ thì dừng ngay để báo người dùng
            if msgLower.contains("api_key_invalid") || msgLower.contains("api key not valid") {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key không hợp lệ. Vui lòng kiểm tra lại Key trong Cài đặt."])))
                }
                return
            }

            // Nếu hết quota (429), quá tải (503 High Demand), hoặc mã model chưa mở (404/400), tự động chuyển sang model Flash Lite dự phòng tiếp theo
            if chiSo + 1 < models.count {
                self.goiTextTheoDanhSachModel(prompt: prompt, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            } else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    private func chuanBiAnhQuet(_ anh: UIImage) -> Data? {
        let w = anh.size.width
        let h = anh.size.height
        guard w > 0, h > 0 else { return anh.jpegData(compressionQuality: 0.88) }

        let maxCanh = max(w, h)
        var tyLe: CGFloat = 1.0
        if maxCanh < 1800 {
            tyLe = min(2.4, 2200.0 / maxCanh)
        } else if maxCanh > 2600 {
            tyLe = 2400.0 / maxCanh
        }

        if abs(tyLe - 1.0) > 0.05 {
            let kichThuocMoi = CGSize(width: floor(w * tyLe), height: floor(h * tyLe))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let anhMoi = UIGraphicsImageRenderer(size: kichThuocMoi, format: format).image { _ in
                anh.draw(in: CGRect(origin: .zero, size: kichThuocMoi))
            }
            return anhMoi.jpegData(compressionQuality: 0.88)
        }
        return anh.jpegData(compressionQuality: 0.88)
    }

    func phanTichLenhSanXuat(anh: UIImage, hoanThanh: @escaping (Result<DuLieuLenhSanXuat, Error>) -> Void) {
        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có Gemini API Key. Hãy bấm '🔑 Cài đặt nhanh Gemini Key & Model' hoặc vào tab Cài đặt để dán Key!"])))
            return
        }
        guard let jpegData = chuanBiAnhQuet(anh) else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể xử lý dữ liệu ảnh JPEG."])))
            return
        }

        let b64 = jpegData.base64EncodedString()
        let prompt = """
        Bạn là hệ thống OCR chuyên dụng đọc bảng Lệnh Sản Xuất thép của Hòa Phát Dung Quất.
        Hãy đọc TOÀN BỘ các dòng dữ liệu có trong ảnh bảng (từ dòng TT = 1 cho đến dòng cuối cùng trước hàng Tổng, bất kể bảng có 6 dòng, 12 dòng hay nhiều hơn) và trích xuất chính xác 8 cột sau đây thành JSON:
        {
          "tieuDe": "BẢNG LỆNH SẢN XUẤT",
          "danhSachMuc": [
            {
              "stt": 1,
              "thoiGianDuKien": "08h00 16/11 - 08h00 19/11",
              "kichCo": "D10",
              "macThep": "CB400V",
              "sanLuong": "2,000",
              "coTinh": "40.2025/YCCN - P.CN",
              "macPhoi": "CT5",
              "soOrder": "1040004605"
            }
          ]
        }

        QUY TẮC BẮT BUỘC ĐỂ CHÍNH XÁC 100%:
        1. SỐ DÒNG (stt): Phải lấy ĐẦY ĐỦ tất cả các dòng từ TT = 1 đến hết bảng (ví dụ bảng có 12 dòng từ 1 đến 12 thì phải trả về đủ 12 phần tử, tuyệt đối không dừng ở 6 dòng). Không đưa dòng "Tổng" vào danhSachMuc.
        2. CỘT THỜI GIAN DỰ KIẾN SẢN XUẤT (thoiGianDuKien):
           - Cột thứ 2 ("Thời gian dự kiến sản xuất") được gộp ô (merged cells) theo từng cụm dòng dựa vào vạch kẻ ngang của cột đó (ví dụ: dòng 1-2 chung ô "08h00 16/11 - 08h00 19/11"; dòng 3-5 chung ô "08h00 19/11 - 08h00 22/11"; dòng 6-8 chung ô "08h00 22/11 - 08h00 24/11"; dòng 9-10 chung ô "08h00 24/11 - 08h00 25/11"; dòng 11-12 chung ô "08h00 25/11 - 08h00 26/11").
           - Hãy nhìn vạch kẻ ngang chia ô ở cột Thời gian dự kiến sản xuất để gán ĐÚNG chuỗi thời gian dạng "08h00 dd/MM - 08h00 dd/MM" cho từng dòng thuộc ô gộp đó. Không được gán trùng 2 mốc ngày giống nhau (như 24/11 - 24/11).
        3. CỘT KÍCH CỠ (kichCo): Lấy chính xác chuỗi ở cột "Sản phẩm -> Kích cỡ", giữ nguyên hậu tố chữ nếu có (ví dụ: "D10", "D12", "D12HP", "D14", "D14HP", "D16", "D18", "D20", "D22", "D25").
        4. CỘT MÁC THÉP (macThep): Lấy đầy đủ chuỗi ở cột "Sản phẩm -> Mác thép", kể cả thông tin trong ngoặc như "(L=12m)" nếu có (ví dụ: "CB300V", "CB400V", "CB500V", "Gr40", "Gr60 (L=12m)").
        5. CỘT SẢN LƯỢNG (sanLuong):
           - CHỈ LẤY số ở cột "Sản phẩm -> Sản lượng (tấn)" (nằm ngay giữa cột Mác thép và cột Cơ tính, ví dụ: "2,000", "4,000", "3,000", "1,500", "3,500", "40").
           - TUYỆT ĐỐI KHÔNG lấy nhầm sang cột "Phôi cán -> Sản lượng (tấn)" ở phía bên phải (như 2,060; 4,120; 3,090; 1,545; 3,605; 41).
           - Định dạng có dấu phẩy ngăn cách hàng nghìn (ví dụ: "4,000", "2,000", "1,500").
        6. CỘT CƠ TÍNH (coTinh): Lấy đầy đủ chuỗi ở cột "Sản phẩm -> Cơ tính" (ví dụ: "40.2025/YCCN - P.CN", "158.2026/YCTN-P.CNLT").
        7. CỘT MÁC PHÔI (macPhoi): Lấy đầy đủ toàn bộ văn bản trong cột "Phôi cán -> Mác" (ví dụ: "CT5", "CT5V", "B500B2/ CT5/ W 60 3/11 loại 1+2/ S60 3/11 loại 2", "Gr80-1").
        8. CỘT SỐ ORDER (soOrder): Lấy đúng mã 10 chữ số bắt đầu bằng 104... ở cột "Số Order" (ví dụ: "1040004605"), không lấy cột Số Batch (1111...).
        Chỉ trả về duy nhất JSON hợp lệ, không thêm lời giải thích.
        """

        let danhSachModels = danhSachModelThuNghiem()
        goiAnhTheoDanhSachModel(prompt: prompt, base64Image: b64, key: key, models: danhSachModels, chiSo: 0, hoanThanh: hoanThanh)
    }

    private func goiAnhTheoDanhSachModel(
        prompt: String,
        base64Image: String,
        key: String,
        models: [String],
        chiSo: Int,
        hoanThanh: @escaping (Result<DuLieuLenhSanXuat, Error>) -> Void
    ) {
        guard chiSo < models.count else {
            DispatchQueue.main.async {
                hoanThanh(.failure(NSError(domain: "Gemini", code: -10, userInfo: [NSLocalizedDescriptionKey: "Các model Gemini (3.5 Flash Lite & 3.1 Flash Lite) hiện đang quá tải hoặc hết quota. Bạn hãy thử lại sau vài giây hoặc chuyển sang model còn lại!"])))
            }
            return
        }

        let model = models[chiSo]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            goiAnhTheoDanhSachModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if chiSo + 1 < models.count {
                    self.goiAnhTheoDanhSachModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
                } else {
                    DispatchQueue.main.async {
                        hoanThanh(.failure(NSError(domain: "Gemini", code: -2, userInfo: [NSLocalizedDescriptionKey: "Phản hồi từ máy chủ Gemini không hợp lệ."])))
                    }
                }
                return
            }

            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                let ghepText = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if let duLieu = Self.bocTachJSONLenhSX(tu: ghepText), !duLieu.danhSachMuc.isEmpty {
                    self.modelVuaSuDung = model
                    DispatchQueue.main.async {
                        hoanThanh(.success(duLieu))
                    }
                    return
                }
            }

            let errObj = json["error"] as? [String: Any]
            let msg = (errObj?["message"] as? String) ?? "HTTP \(statusCode)"
            let msgLower = msg.lowercased()

            if msgLower.contains("api_key_invalid") || msgLower.contains("api key not valid") {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key không hợp lệ. Vui lòng kiểm tra lại Key của bạn."])))
                }
                return
            }

            if chiSo + 1 < models.count {
                self.goiAnhTheoDanhSachModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            } else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Lỗi gọi Gemini AI (\(model)): \(msg)"])))
                }
            }
        }.resume()
    }

    static func bocTachJSONLenhSX(tu text: String) -> DuLieuLenhSanXuat? {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Trích xuất khối JSON nằm giữa { ... } hoặc [ ... ] nếu AI có kèm văn bản phụ
        if let firstBrace = clean.firstIndex(of: "{"),
           let lastBrace = clean.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            let sub = String(clean[firstBrace...lastBrace])
            if let data = sub.data(using: .utf8) {
                if let decoded = try? JSONDecoder().decode(DuLieuLenhSanXuat.self, from: data), !decoded.danhSachMuc.isEmpty {
                    return decoded
                }
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let parsed = parseTuDictLinhHoat(dict), !parsed.danhSachMuc.isEmpty {
                    return parsed
                }
            }
        }

        if let firstBracket = clean.firstIndex(of: "["),
           let lastBracket = clean.lastIndex(of: "]"),
           firstBracket <= lastBracket {
            let sub = String(clean[firstBracket...lastBracket])
            if let data = sub.data(using: .utf8) {
                if let arr = try? JSONDecoder().decode([MucDongLenhSX].self, from: data), !arr.isEmpty {
                    var ds = arr
                    for i in 0..<ds.count { ds[i].stt = i + 1 }
                    return DuLieuLenhSanXuat(tieuDe: "BẢNG LỆNH SẢN XUẤT", capNhatLuc: Date(), danhSachMuc: ds)
                }
                if let rawArr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let ds = parseMangMucLinhHoat(rawArr)
                    if !ds.isEmpty {
                        return DuLieuLenhSanXuat(tieuDe: "BẢNG LỆNH SẢN XUẤT", capNhatLuc: Date(), danhSachMuc: ds)
                    }
                }
            }
        }

        return nil
    }

    private static func parseTuDictLinhHoat(_ dict: [String: Any]) -> DuLieuLenhSanXuat? {
        let tieuDe = (dict["tieuDe"] as? String) ?? (dict["title"] as? String) ?? "BẢNG LỆNH SẢN XUẤT"
        let cacKhoaMang = ["danhSachMuc", "danh_sach_muc", "rows", "items", "data"]
        for k in cacKhoaMang {
            if let rawArr = dict[k] as? [[String: Any]] {
                let ds = parseMangMucLinhHoat(rawArr)
                if !ds.isEmpty {
                    return DuLieuLenhSanXuat(tieuDe: tieuDe, capNhatLuc: Date(), danhSachMuc: ds)
                }
            }
        }
        return nil
    }

    private static func parseMangMucLinhHoat(_ rawArr: [[String: Any]]) -> [MucDongLenhSX] {
        var ketQua: [MucDongLenhSX] = []
        for (idx, item) in rawArr.enumerated() {
            func str(_ keys: [String]) -> String {
                for k in keys {
                    if let s = item[k] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return s.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let n = item[k] as? NSNumber {
                        return n.stringValue
                    }
                }
                return ""
            }
            let sttVal = Int(str(["stt", "tt", "index"])) ?? (idx + 1)
            let tg = str(["thoiGianDuKien", "thoi_gian_du_kien", "thoiGian", "time"])
            let kc = str(["kichCo", "kich_co", "size"])
            let mt = str(["macThep", "mac_thep", "steelGrade"])
            let sl = str(["sanLuong", "san_luong", "quantity", "tonnage"])
            let ct = str(["coTinh", "co_tinh", "mechanical"])
            let mp = str(["macPhoi", "mac_phoi", "mac", "billetGrade"])
            let ord = str(["soOrder", "so_order", "order"])

            let muc = MucDongLenhSX(
                stt: idx + 1 > 0 ? (idx + 1) : sttVal,
                thoiGianDuKien: tg,
                kichCo: kc,
                macThep: mt,
                sanLuong: sl,
                coTinh: ct,
                macPhoi: mp,
                soOrder: ord
            )
            ketQua.append(muc)
        }
        return ketQua
    }

    // MARK: - Phân tích ảnh thông số HMI Bargraph & TWS cho Trợ Lý Cán

    func phanTichThongSoCan(
        anhHMI: UIImage?,
        anhTWS: UIImage?,
        anhK9K20: UIImage? = nil,
        cheDo: CheDoChanDoanCan,
        kichThuocPhoi: String,
        quyCachSanPham: String = "D14 (2x14)",
        heLoHinhK9K20: String = "",
        gapThucTe: String = "",
        ghiChuThem: String,
        hoanThanh: @escaping (Result<KetQuaChanDoanCan, Error>) -> Void
    ) {
        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có Gemini API Key. Hãy nhập Key trong Cài đặt hoặc hộp thoại cài đặt nhanh!"])))
            return
        }

        var parts: [[String: Any]] = []
        let prompt = Self.taoPromptChanDoanCan(
            cheDo: cheDo,
            kichThuocPhoi: kichThuocPhoi,
            quyCachSanPham: quyCachSanPham,
            heLoHinhK9K20: heLoHinhK9K20,
            gapThucTe: gapThucTe,
            coAnhHMI: anhHMI != nil,
            coAnhTWS: anhTWS != nil,
            coAnhK9K20: anhK9K20 != nil,
            ghiChuThem: ghiChuThem
        )
        parts.append(["text": prompt])

        if let anhHMI, let dataHMI = chuanBiAnhQuet(anhHMI) {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": dataHMI.base64EncodedString()]])
        }
        if let anhTWS, let dataTWS = chuanBiAnhQuet(anhTWS) {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": dataTWS.base64EncodedString()]])
        }
        if let anhK9K20, let dataK9 = chuanBiAnhQuet(anhK9K20) {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": dataK9.base64EncodedString()]])
        }

        guard parts.count >= 2 else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể chuyển đổi ảnh sang dữ liệu JPEG."])))
            return
        }

        let models = danhSachModelThuNghiem()
        goiChanDoanCanTheoModel(
            parts: parts,
            key: key,
            models: models,
            chiSo: 0,
            cheDo: cheDo,
            kichThuocPhoi: kichThuocPhoi,
            hoanThanh: hoanThanh
        )
    }

    private static func taoPromptChanDoanCan(
        cheDo: CheDoChanDoanCan,
        kichThuocPhoi: String,
        quyCachSanPham: String,
        heLoHinhK9K20: String,
        gapThucTe: String,
        coAnhHMI: Bool,
        coAnhTWS: Bool,
        coAnhK9K20: Bool,
        ghiChuThem: String
    ) -> String {
        var dsMoTa: [String] = []
        var sttAnh = 1
        if coAnhHMI {
            dsMoTa.append("Ảnh \(sttAnh): Màn hình HMI Bargraph cán thô K1–K8 (Torque %, Sample T0, m/s, RPM, N/mm2, Act Tor, Des Tor, nhiệt độ P1).")
            sttAnh += 1
        }
        if coAnhTWS {
            dsMoTa.append("Ảnh \(sttAnh): Bảng Parameters Setup (TWS) K1–K20 (Control TENSION/NONE/LOOP, Elongation Setup vs Actual, Diameter, Groove fac, Lead speed, Tension, Loop height).")
            sttAnh += 1
        }
        if coAnhK9K20 {
            dsMoTa.append("Ảnh \(sttAnh): Ảnh màn hình TWS / HMI khu vực K9–K20 và khối tinh FFB1.1–FFB2.2 (FFB1 = Line 1, FFB2 = Line 2) chứa Elongation, Out speed, Motor RPM, Diameter, Groove fac, Lead speed, Loop height % và tải/mô-men.")
        }
        let moTaAnh = dsMoTa.joined(separator: " ")

        return """
        Bạn là kỹ sư chuyên gia vận hành & tự động hóa nhà máy cán thép dài (hệ thống Danieli HMI / TWS).
        Chuyên đề cần phân tích: \(cheDo.tieuDeNgan) — \(cheDo.moTaChuyenDe)
        Kích thước phôi đầu vào THỰC TẾ: \(kichThuocPhoi) (lưu ý: phôi có thể thay đổi kích thước theo từng mẻ/sản phẩm, KHÔNG mặc định là 150x150 nếu người dùng nhập cỡ khác)
        Quy cách sản phẩm đang cán (hệ lỗ hình K9–K20): \(quyCachSanPham)
        HỆ LỖ HÌNH K9–K20 ĐÃ LƯU CHO SẢN PHẨM NÀY:
        \(heLoHinhK9K20.isEmpty ? "Chưa có dữ liệu lưu sẵn (đọc từ ảnh K9–K20 nếu người dùng đính kèm)." : heLoHinhK9K20)
        Gap thực tế đang chạy (nếu người dùng nhập): \(gapThucTe.isEmpty ? "Chưa nhập (hãy suy luận độ lệch thực tế so với thiết kế từ Elongation dòng xanh vs dòng đen trên ảnh TWS nếu có)" : gapThucTe)
        Ghi chú vận hành thêm: \(ghiChuThem.isEmpty ? "Không có" : ghiChuThem)

        HỆ THỐNG LỖ HÌNH THAM CHIẾU CÁC GIÁ CÁN THÔ (1H – 8V, K1 – K8 — bảng tham chiếu gốc cho phôi 150x150, nếu cỡ phôi đầu vào khác thì tự điều chỉnh kích thước vật cán & lượng ép tương ứng):
        - K1 (1H - SHS 280, Ngang): Lỗ hình Hộp (Box) 162.0 x 108.0 mm | Gap thiết kế: 15.0 mm
        - K2 (2V - SHS 280, Đứng): Lỗ hình Hộp (Box) 119.0 x 119.0 mm | Gap thiết kế: 15.0 mm
        - K3 (3H - SHS 280, Ngang): Lỗ hình Ôvan (Oval) 138.0 x 81.5 mm | Gap thiết kế: 12.0 mm
        - K4 (4V - SHS 230, Đứng): Lỗ hình Tròn (Round) 99.0 x 99.0 mm | Gap thiết kế: 12.0 mm
        - K5 (5H - SHS 230, Ngang): Lỗ hình Ôvan (Oval) 112.6 x 60.0 mm | Gap thiết kế: 10.0 mm
        - K6 (6V - SHS 230, Đứng): Lỗ hình Tròn (Round) 72.5 x 72.5 mm | Gap thiết kế: 10.0 mm
        - K7 (7H - SHS 230, Ngang): Lỗ hình Ôvan (Oval) 88.2 x 42.3 mm (Gap 7.5 mm; riêng DB 2x14: 87.0 x 43.6 mm, Gap 8.8 mm)
        - K8 (8V - SHS 230, Đứng): Lỗ hình Tròn (Round) 53.5 x 53.5 mm (Gap 7.5 mm; riêng DB 2x14: 54.5 x 54.5 mm, Gap 8.5 mm)
        LƯU Ý QUAN TRỌNG VỀ LỖ HÌNH & GAP THỰC TẾ:
        - Các giá chẵn (2V, 4V, 6V, 8V) là GIÁ ĐỨNG (V) mang lỗ hình Hộp/Tròn và có giới hạn Des Tor thấp hơn các giá lẻ (1H, 3H, 5H, 7H — GIÁ NGANG mang lỗ hình Ôvan).
        - Vì Gap thực tế ngoài xưởng thường khác Gap thiết kế nên kích thước vật cán thực tế qua từng giá sẽ sai khác so với bảng thiết kế; hãy đối chiếu Elongation thực tế (dòng xanh) với Setup (dòng đen) để nhận biết giá nào đang bị ép dày/mỏng hơn thiết kế.
        - Quy luật an toàn lỗ hình khi nới Gap: Nới Gap ở giá Tròn (4V, 6V) đẩy sang giá Ôvan (5H, 7H) ít rủi ro tràn biên hơn vì rãnh Ôvan rộng (nhưng vẫn phải kiểm tra dẫn hướng vào và góc ăn phôi); ngược lại nới Gap ở giá Ôvan (3H, 5H) đẩy sang giá Tròn (4V, 6V) rất dễ gây tràn biên (overfill/vây mép) hoặc đổ phôi (rollover) nên phải hết sức thận trọng.
        Mô tả ảnh đính kèm: \(moTaAnh)

        KIẾN THỨC KỸ THUẬT BẮT BUỘC ÁP DỤNG:
        1. Phân biệt rõ % tải động cơ (Torque %) với % giới hạn cơ khí trục các đăng (Act Tor ÷ Des Tor). Các giá chẵn (S02, S04, S06) thường có Des Tor thấp hơn giá lẻ (S01, S03, S05, S07), nên động cơ 65-72% vẫn có thể báo ĐỎ/VÀNG cơ khí (≥ 94% ĐỎ, 88-93.9% VÀNG).
        2. Phân biệt đẩy phôi (N/mm2 âm, Torque % > Sample T0) với kéo căng (N/mm2 dương, Torque % < Sample T0). Nếu bị đẩy phôi nặng (<-2.5 N/mm2) thì ưu tiên triệt tiêu đẩy phôi trước khi nới ép.
        3. Quy tắc nới ép san tải với phôi \(kichThuocPhoi):
           - Khi nới Giá i để dồn tải sang Giá i+1, KHÔNG ép Giá i+1 xuống bằng lượng nới Giá i (giữ nguyên khe hở Giá i+1; chỉ ép bù cực nhẹ 0.2-0.5 mm nếu đo mẫu thấy giãn Mill Spring).
           - Tính tiết diện và kích thước phôi thực tế qua từng giá dựa theo đúng cỡ phôi đầu vào THỰC TẾ (\(kichThuocPhoi)) và Elongation đọc từ ảnh TWS (nếu phôi khác 150x150 mm thì tự quy đổi lại Δh và bước nới Gap tỷ lệ tương ứng; phôi nhỏ hơn 150x150 thì bước nới nhỏ hơn 0.5-1.0 mm, phôi lớn hơn 150x150 thì bước nới 1.0-2.0 mm).
           - Sau khi chỉnh ổn định 2-3 thanh phôi, nhắc bấm Grab -> Save trên bảng TWS.
        4. Đổi Tension setpoint trên TWS: chỉ dùng mức dương nhẹ (+1.5 đến +2.0 N/mm2) làm phụ trợ chặn đẩy phôi, không đặt quá cao tránh kéo tóp phôi.
        5. Kiểm tra nhiệt độ P1 / Furnace Out Temp / Min billet Temp (nếu < 1000 °C hoặc *** cần cảnh báo sốc đầu phôi) và kiểm tra Lead speed bất thường (VD: ≥ 8-10%).
        6. BẮT BUỘC TÍNH KÍCH THƯỚC VẬT CÁN THỰC TẾ (kichThuocThucTe) cho từng giá:
           - Từ diện tích phôi đầu vào A0 (VD: 150x150 = 22500 mm², 165x165 = 27225 mm²) chia dồn theo Elongation dòng xanh (A_i = A_{i-1} / Elong_i).
           - Chiều cao thực H_i = H_thiết_kế + (Gap_thực - Gap_thiết_kế) (nếu chưa có Gap thực thì ước tính theo √(A_i / A_TK)).
           - Chiều rộng thực B_i = A_i / (k * H_i), với k = 0.92 (Hộp), k = 0.785 (Tròn), k = 0.74 (Ôvan). Ghi rõ dấu hiệu tràn biên nếu B_i lớn hơn thiết kế >4%.
        7. PHÂN TÍCH MỞ RỘNG CHO K9–K20 VÀ KHỐI TINH FFB1.1–FFB2.2 (2 LINE):
           - Kiến trúc dây chuyền tách đôi: Vật cán khi qua K15 sẽ chẻ thành 2 line song song — Line 1 đi qua FFB1.1, FFB1.2 và Line 2 đi qua FFB2.1, FFB2.2 (lưu ý K10–K13 trở đi và FFB chạy chế độ LOOP với Loop height %).
           - LƯU Ý KÍCH THƯỚC SAU K15: Các kích thước thiết kế trên bảng cán từ K15, K16 đến FFB1.1–FFB2.2 đã thể hiện sẵn kích thước sau khi chẻ nhánh, do đó TUYỆT ĐỐI KHÔNG tự chia đôi tiết diện thêm một lần nữa; hãy tính trực tiếp theo Elongation thực tế và so sánh thẳng với kích thước mẫu từng giá. Đồng thời so sánh tải/mô-men và Loop height giữa FFB1 (Line 1) và FFB2 (Line 2) để phát hiện lệch chẻ 2 nhánh.
           - Đưa hướng xử lý mô-men xoắn, Loop height %, cân bằng 2 line FFB1/FFB2 và san tải Gap cho toàn dãy K1–K20 & FFB1.1–FFB2.2.
           - BẮT BUỘC trả về đầy đủ danhSachGia cho TẤT CẢ các giá đọc được từ K1 đến K20 và FFB1.1, FFB1.2, FFB2.1, FFB2.2 (để app hiển thị bảng so sánh kích thước vật cán thực tế vs kích thước mẫu ở bảng cán).

        Hãy đọc CHÍNH XÁC toàn bộ các con số có trong ảnh (chú ý ảnh có thể bị xoay ngang 90 độ, hãy đọc đúng cột/hàng) và trả về DUY NHẤT JSON hợp lệ theo cấu trúc:
        {
          "mucDoTongThe": "NGUY_HIEM | CANH_BAO | ON_DINH",
          "nhietDoPhoi": "Tóm tắt nhiệt độ đọc được từ ảnh (VD: P1: 989 °C | Min billet: *** °C)",
          "tomTatNguyenNhan": "Tóm tắt ngắn gọn, đi thẳng vào nguyên nhân gốc rễ (2-4 câu tiếng Việt).",
          "danhSachGia": [
            {
              "gia": "S06 (K6)",
              "mucDo": "DO | VANG | XANH",
              "actTor": "80.0 / 85 kNm",
              "phanTramCoKhi": "94.1%",
              "torqueMotor": "67% (T0: 66%)",
              "tension": "+1.7 N/mm²",
              "elongation": "1.313 (Setup 1.293)",
              "kichThuocThucTe": "B x H thực tế (mm), VD: 74.0 × 72.5",
              "kichThuocMau": "B x H mẫu ở bảng cán (mm), VD: 72.5 × 72.5",
              "chenhLechKichThuoc": "So sánh với mẫu, VD: +2.1% Đạt | +5.2% Tràn biên | -6.0% Non",
              "nhanDinh": "1 câu nhận định kỹ thuật ngắn gọn."
            }
          ],
          "cacBuocXuLy": [
            {
              "thuTu": 1,
              "tieuDe": "San tải S06 sang S07",
              "mucChinhCuThe": "Nới khe hở S06 từng bước 1.0 mm (tổng 2.0–3.0 mm), giữ nguyên khe hở S07",
              "chiTiet": "Giải thích ngắn gọn lý do và mục tiêu kNm cần đạt."
            }
          ],
          "canhBaoRuiRo": [
            "Kiểm tra phôi ra S07 không bị tràn biên (overfill) và kẹt dẫn hướng vào S07."
          ],
          "ghiChuTWS": "Sau khi chạy ổn định 2–3 thanh phôi, bấm Grab -> Save trên TWS để đồng bộ tốc độ đặt trước."
        }
        Chỉ trả về JSON thuần, không bọc markdown hay lời giải thích ngoài JSON.
        """
    }

    private func goiChanDoanCanTheoModel(
        parts: [[String: Any]],
        key: String,
        models: [String],
        chiSo: Int,
        cheDo: CheDoChanDoanCan,
        kichThuocPhoi: String,
        hoanThanh: @escaping (Result<KetQuaChanDoanCan, Error>) -> Void
    ) {
        guard chiSo < models.count else {
            DispatchQueue.main.async {
                hoanThanh(.failure(NSError(domain: "Gemini", code: -10, userInfo: [NSLocalizedDescriptionKey: "Các model Gemini hiện đều quá tải hoặc hết hạn mức. Vui lòng thử lại sau ít giây!"])))
            }
            return
        }

        let model = models[chiSo]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            goiChanDoanCanTheoModel(parts: parts, key: key, models: models, chiSo: chiSo + 1, cheDo: cheDo, kichThuocPhoi: kichThuocPhoi, hoanThanh: hoanThanh)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 55
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.15,
                "responseMimeType": "application/json"
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if chiSo + 1 < models.count {
                    self.goiChanDoanCanTheoModel(parts: parts, key: key, models: models, chiSo: chiSo + 1, cheDo: cheDo, kichThuocPhoi: kichThuocPhoi, hoanThanh: hoanThanh)
                } else {
                    DispatchQueue.main.async {
                        hoanThanh(.failure(NSError(domain: "Gemini", code: -2, userInfo: [NSLocalizedDescriptionKey: "Phản hồi từ Gemini không hợp lệ."])))
                    }
                }
                return
            }

            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let respParts = content["parts"] as? [[String: Any]] {
                let ghepText = respParts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if let ketQua = Self.bocTachJSONChanDoanCan(tu: ghepText, cheDo: cheDo, kichThuocPhoi: kichThuocPhoi, model: model) {
                    self.modelVuaSuDung = model
                    DispatchQueue.main.async { hoanThanh(.success(ketQua)) }
                    return
                }
            }

            let errObj = json["error"] as? [String: Any]
            let msg = (errObj?["message"] as? String) ?? "HTTP \(statusCode)"
            let msgLower = msg.lowercased()
            if msgLower.contains("api_key_invalid") || msgLower.contains("api key not valid") {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key không hợp lệ. Vui lòng kiểm tra lại Key trong Cài đặt."])))
                }
                return
            }

            if chiSo + 1 < models.count {
                self.goiChanDoanCanTheoModel(parts: parts, key: key, models: models, chiSo: chiSo + 1, cheDo: cheDo, kichThuocPhoi: kichThuocPhoi, hoanThanh: hoanThanh)
            } else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Lỗi gọi Gemini AI (\(model)): \(msg)"])))
                }
            }
        }.resume()
    }

    private static func bocTachJSONChanDoanCan(
        tu text: String,
        cheDo: CheDoChanDoanCan,
        kichThuocPhoi: String,
        model: String
    ) -> KetQuaChanDoanCan? {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstBrace = clean.firstIndex(of: "{"),
              let lastBrace = clean.lastIndex(of: "}"),
              firstBrace <= lastBrace else {
            return nil
        }
        let sub = String(clean[firstBrace...lastBrace])
        guard let data = sub.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let mucDo = (dict["mucDoTongThe"] as? String) ?? "CANH_BAO"
        let nhietDo = (dict["nhietDoPhoi"] as? String) ?? ""
        let tomTat = (dict["tomTatNguyenNhan"] as? String) ?? ""
        let ghiChuTWS = (dict["ghiChuTWS"] as? String) ?? ""
        let canhBao = (dict["canhBaoRuiRo"] as? [String]) ?? []

        var dsGia: [ThongSoGiaCanAI] = []
        if let rawGia = dict["danhSachGia"] as? [[String: Any]] {
            for item in rawGia {
                dsGia.append(ThongSoGiaCanAI(
                    gia: (item["gia"] as? String) ?? "",
                    mucDo: (item["mucDo"] as? String) ?? "XANH",
                    actTor: (item["actTor"] as? String) ?? "",
                    phanTramCoKhi: (item["phanTramCoKhi"] as? String) ?? "",
                    torqueMotor: (item["torqueMotor"] as? String) ?? "",
                    tension: (item["tension"] as? String) ?? "",
                    elongation: (item["elongation"] as? String) ?? "",
                    kichThuocThucTe: (item["kichThuocThucTe"] as? String) ?? "",
                    kichThuocMau: (item["kichThuocMau"] as? String) ?? "",
                    chenhLechKichThuoc: (item["chenhLechKichThuoc"] as? String) ?? "",
                    nhanDinh: (item["nhanDinh"] as? String) ?? ""
                ))
            }
        }

        var dsBuoc: [BuocXuLyCanAI] = []
        if let rawBuoc = dict["cacBuocXuLy"] as? [[String: Any]] {
            for (idx, item) in rawBuoc.enumerated() {
                let stt = (item["thuTu"] as? Int) ?? (idx + 1)
                dsBuoc.append(BuocXuLyCanAI(
                    thuTu: stt,
                    tieuDe: (item["tieuDe"] as? String) ?? "",
                    chiTiet: (item["chiTiet"] as? String) ?? "",
                    mucChinhCuThe: (item["mucChinhCuThe"] as? String) ?? ""
                ))
            }
        }

        guard !tomTat.isEmpty || !dsGia.isEmpty || !dsBuoc.isEmpty else { return nil }
        return KetQuaChanDoanCan(
            thoiGian: Date(),
            cheDo: cheDo,
            kichThuocPhoi: kichThuocPhoi,
            mucDoTongThe: mucDo,
            nhietDoPhoi: nhietDo,
            tomTatNguyenNhan: tomTat,
            danhSachGia: dsGia,
            cacBuocXuLy: dsBuoc,
            canhBaoRuiRo: canhBao,
            ghiChuTWS: ghiChuTWS,
            modelSuDung: model
        )
    }

    // MARK: - Quét ảnh Bảng Hệ Lỗ Hình mẫu (K9 – K20) bằng Gemini Vision

    func quetAnhBangLoHinhK9K20(
        anh: UIImage,
        hoanThanh: @escaping (Result<(tenGoiY: String, danhSachGia: [ThongSoLoHinhGia]), Error>) -> Void
    ) {
        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có Gemini API Key. Hãy nhập Key trong tab Cài đặt trước khi quét ảnh!"])))
            return
        }
        guard let jpegData = chuanBiAnhQuet(anh) else {
            hoanThanh(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể xử lý dữ liệu ảnh JPEG."])))
            return
        }

        let prompt = """
        Bạn là hệ thống OCR kỹ thuật chuyên đọc bảng Hệ thống lỗ hình cán thép (Pass Schedule) từ ảnh chụp bảng in tại nhà máy cán thép.
        Trong mỗi ô của bảng lỗ hình thường có:
        - Hình vẽ tiết diện lỗ hình: Hộp (Box), Ôvan (Oval), Tròn (Round), Dẹt (Flat), hoặc Tách đôi (Slit / 2 nhánh song song).
        - Kích thước rộng x cao phía dưới hình (VD: "61.1x35.0", "53.0x36.0", "26.56x13.90", "13.84x13.84").
        - Số Gap thiết kế gạch chân ở góc trên bên phải mỗi ô (VD: 8.8, 8.5, 9.8, 6.7, 4.0, 1.5, 3.0, 2.20, 1.93, 1.78, 2.80).
        - Tên quy cách sản phẩm nếu có ở cuối cột (VD: "DB 2x14", "D10", "D12", "D16"...).

        Hãy trích xuất các giá từ K9 đến K20 và khối tinh FFB1.1, FFB1.2 (Line 1), FFB2.1, FFB2.2 (Line 2) có trong ảnh (bỏ qua K1–K8; lưu ý khi qua K15 vật cán chẻ thành 2 line vào FFB1 và FFB2 — nếu bảng chỉ in 1 cột lỗ hình cho 2 nhánh giống nhau sau K16 thì gán cho FFB1.1, FFB1.2 và nhân bản tương ứng cho FFB2.1, FFB2.2 với soNhanh = 2) thành DUY NHẤT JSON hợp lệ:
        {
          "tenSanPhamGoiY": "VD: DB 2x14 (hoặc rỗng nếu không thấy)",
          "danhSachGia": [
            {
              "gia": "K9",
              "loaiLoHinh": "Hộp | Ôvan | Tròn | Dẹt | Tách đôi",
              "chieuRongTK": 61.1,
              "chieuCaoTK": 35.0,
              "gapTK": 35.5,
              "soNhanh": 1
            }
          ]
        }
        Lưu ý: Nếu là lỗ hình cán tách đôi 2 nhánh (như hình 2 lỗ tròn/ôvan cạnh nhau sau giá tách), đặt "soNhanh": 2; bình thường đặt "soNhanh": 1. Chỉ trả về JSON thuần.
        """

        let b64 = jpegData.base64EncodedString()
        let models = danhSachModelThuNghiem()
        goiQuetLoHinhTheoModel(prompt: prompt, base64Image: b64, key: key, models: models, chiSo: 0, hoanThanh: hoanThanh)
    }

    private func goiQuetLoHinhTheoModel(
        prompt: String,
        base64Image: String,
        key: String,
        models: [String],
        chiSo: Int,
        hoanThanh: @escaping (Result<(tenGoiY: String, danhSachGia: [ThongSoLoHinhGia]), Error>) -> Void
    ) {
        guard chiSo < models.count else {
            DispatchQueue.main.async {
                hoanThanh(.failure(NSError(domain: "Gemini", code: -10, userInfo: [NSLocalizedDescriptionKey: "Các model Gemini hiện quá tải hoặc hết hạn mức. Hãy thử lại sau ít giây!"])))
            }
            return
        }

        let model = models[chiSo]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            goiQuetLoHinhTheoModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if chiSo + 1 < models.count {
                    self.goiQuetLoHinhTheoModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
                } else {
                    DispatchQueue.main.async {
                        hoanThanh(.failure(NSError(domain: "Gemini", code: -2, userInfo: [NSLocalizedDescriptionKey: "Phản hồi từ Gemini không hợp lệ."])))
                    }
                }
                return
            }

            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let respParts = content["parts"] as? [[String: Any]] {
                let ghepText = respParts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if let parsed = Self.bocTachJSONLoHinh(tu: ghepText), !parsed.danhSachGia.isEmpty {
                    self.modelVuaSuDung = model
                    DispatchQueue.main.async { hoanThanh(.success(parsed)) }
                    return
                }
            }

            let errObj = json["error"] as? [String: Any]
            let msg = (errObj?["message"] as? String) ?? "HTTP \(statusCode)"
            if msg.lowercased().contains("api_key_invalid") || msg.lowercased().contains("api key not valid") {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key không hợp lệ."])))
                }
                return
            }

            if chiSo + 1 < models.count {
                self.goiQuetLoHinhTheoModel(prompt: prompt, base64Image: base64Image, key: key, models: models, chiSo: chiSo + 1, hoanThanh: hoanThanh)
            } else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "Gemini", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Lỗi quét bảng lỗ hình (\(model)): \(msg)"])))
                }
            }
        }.resume()
    }

    private static func bocTachJSONLoHinh(tu text: String) -> (tenGoiY: String, danhSachGia: [ThongSoLoHinhGia])? {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstBrace = clean.firstIndex(of: "{"),
              let lastBrace = clean.lastIndex(of: "}"),
              firstBrace <= lastBrace else { return nil }
        let sub = String(clean[firstBrace...lastBrace])
        guard let data = sub.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let tenGoiY = ((dict["tenSanPhamGoiY"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawArr = dict["danhSachGia"] as? [[String: Any]] else { return nil }

        func docSo(_ val: Any?) -> Double {
            if let d = val as? Double { return d }
            if let i = val as? Int { return Double(i) }
            if let s = val as? String {
                return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
            return 0
        }

        var ketQua: [ThongSoLoHinhGia] = []
        for (idx, item) in rawArr.enumerated() {
            let giaRaw = ((item["gia"] as? String) ?? "K\(9 + idx)").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let loai = ((item["loaiLoHinh"] as? String) ?? "Ôvan").trimmingCharacters(in: .whitespacesAndNewlines)
            let b = docSo(item["chieuRongTK"])
            let h = docSo(item["chieuCaoTK"])
            let gap = docSo(item["gapTK"])
            let nhanh = max(1, Int(docSo(item["soNhanh"])))
            if b > 0 && h > 0 {
                ketQua.append(ThongSoLoHinhGia(gia: giaRaw, loaiLoHinh: loai, chieuRongTK: b, chieuCaoTK: h, gapTK: gap, soNhanh: nhanh))
            }
        }
        return (tenGoiY, ketQua)
    }
}
