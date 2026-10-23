import UIKit

// MARK: - 1. Bộ Nhớ Đệm Ảnh 2 Tầng (RAM NSCache + Disk Cache)

final class BoNhoDemAnh {
    static let dungChung = BoNhoDemAnh()

    private let boNhoRAM = NSCache<NSString, UIImage>()
    private let hangDoi = DispatchQueue(label: "vn.duongnt.ghichu.imagecache", qos: .userInitiated, attributes: .concurrent)

    private init() {
        boNhoRAM.countLimit = 200
        boNhoRAM.totalCostLimit = 120 * 1024 * 1024 // 120 MB RAM cache
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

    /// Tạo chuỗi Base64 thu nhỏ để đồng bộ kèm vào bảng Supabase (giúp hiển thị ngay cả khi mở trên thiết bị mới)
    func taoThumbnailBase64(tu anh: UIImage, kichThuocToiDa: CGFloat = 480) -> String? {
        let tyLe = min(kichThuocToiDa / max(anh.size.width, 1), kichThuocToiDa / max(anh.size.height, 1), 1.0)
        let kichThuocMoi = CGSize(width: anh.size.width * tyLe, height: anh.size.height * tyLe)
        let dinhDang = UIGraphicsImageRendererFormat()
        dinhDang.scale = 1.0
        let boVe = UIGraphicsImageRenderer(size: kichThuocMoi, format: dinhDang)
        let anhNho = boVe.image { _ in
            anh.draw(in: CGRect(origin: .zero, size: kichThuocMoi))
        }
        return anhNho.jpegData(compressionQuality: 0.65)?.base64EncodedString()
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

    /// Lấy ảnh từ Bộ nhớ đệm (RAM -> Disk -> Thumbnail Supabase -> Tải từ Google Drive và lưu vào Cache)
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

        // 3. Nếu có ảnh thumbnail đồng bộ từ Supabase, hiển thị trước ngay lập tức
        var daTraVeTam = false
        if let thumbB64 = thongTin.thumbnailBase64,
           let data = Data(base64Encoded: thumbB64),
           let anhThumb = UIImage(data: data) {
            boNhoRAM.setObject(anhThumb, forKey: thongTin.maAnh as NSString)
            hoanThanh(anhThumb)
            daTraVeTam = true
        }

        // 4. Tải ảnh gốc chất lượng cao từ Google Drive về lưu vào bộ nhớ đệm
        guard let fileId = thongTin.driveFileId, !fileId.isEmpty else {
            if !daTraVeTam { hoanThanh(nil) }
            return
        }

        DichVuGoogleDrive.dungChung.taiAnhTuDrive(fileId: fileId, driveUrl: thongTin.driveUrl) { [weak self] anhTaiVe in
            guard let self else { return }
            if let anhTaiVe {
                self.luuAnh(anhTaiVe, maAnh: thongTin.maAnh)
                self.luuAnh(anhTaiVe, maAnh: fileId)
                DispatchQueue.main.async {
                    hoanThanh(anhTaiVe)
                }
            } else if !daTraVeTam {
                DispatchQueue.main.async {
                    hoanThanh(nil)
                }
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

    /// Tải ảnh lên Google Drive (hỗ trợ Google Apps Script Bridge, OAuth2 Refresh Token, hoặc Access Token/Key)
    func taiAnhLenDrive(
        anh: UIImage,
        tenTep: String,
        hoanThanh: @escaping (_ fileId: String?, _ driveUrl: String?, _ thongBaoLoi: String?) -> Void
    ) {
        guard let jpegData = anh.jpegData(compressionQuality: 0.78) else {
            hoanThanh(nil, nil, "Không thể nén dữ liệu ảnh JPEG.")
            return
        }

        let cd = KhoDuLieu.dungChung.caiDat

        // Ưu tiên 1: Nếu người dùng đã cấu hình Google Apps Script URL cho Drive
        if !cd.driveScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let scriptURL = URL(string: cd.driveScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines)) {
            taiLenQuaAppsScript(url: scriptURL, jpegData: jpegData, tenTep: tenTep, folderId: cd.driveFolderId, hoanThanh: hoanThanh)
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
                    self.taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: cd.driveFolderId, bearerToken: token, apiKey: nil, hoanThanh: hoanThanh)
                } else {
                    hoanThanh(nil, nil, loi ?? "Không lấy được Access Token từ Refresh Token.")
                }
            }
            return
        }

        // Ưu tiên 3: Sử dụng Drive Key được cung cấp (ví dụ AQ.Ab8RN6... hoặc ya29...)
        let key = cd.driveKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            if key.hasPrefix("https://script.google.com") {
                if let url = URL(string: key) {
                    taiLenQuaAppsScript(url: url, jpegData: jpegData, tenTep: tenTep, folderId: cd.driveFolderId, hoanThanh: hoanThanh)
                    return
                }
            }
            // Thử gửi với Bearer token trước, nếu lỗi thử query ?key=
            taiLenQuaDriveREST(jpegData: jpegData, tenTep: tenTep, folderId: cd.driveFolderId, bearerToken: key, apiKey: key, hoanThanh: hoanThanh)
            return
        }

        hoanThanh(nil, nil, "Chưa cấu hình Google Drive Key hoặc Link Apps Script.")
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
        req.timeoutInterval = 45

        let payload: [String: Any] = [
            "action": "upload_drive",
            "filename": tenTep,
            "mimeType": "image/jpeg",
            "folderId": folderId,
            "base64": jpegData.base64EncodedString()
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error {
                DispatchQueue.main.async { hoanThanh(nil, nil, error.localizedDescription) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { hoanThanh(nil, nil, "Phản hồi từ Apps Script không hợp lệ.") }
                return
            }
            if let fileId = json["fileId"] as? String, !fileId.isEmpty {
                let viewUrl = (json["url"] as? String) ?? "https://drive.google.com/uc?export=view&id=\(fileId)"
                DispatchQueue.main.async { hoanThanh(fileId, viewUrl, nil) }
            } else {
                let err = (json["error"] as? String) ?? "Apps Script chưa trả về fileId."
                DispatchQueue.main.async { hoanThanh(nil, nil, err) }
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
                hoanThanh(nil, "Không thể đổi Refresh Token lấy Access Token. Kiểm tra lại Client ID/Secret/Refresh Token.")
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
        var urlStr = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink,webContentLink"
        if let apiKey, !apiKey.isEmpty, (bearerToken == nil || apiKey.hasPrefix("AIza") || apiKey.hasPrefix("AQ.")) {
            let encoded = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
            urlStr += "&key=\(encoded)"
        }
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
        let cleanFolder = folderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanFolder.isEmpty {
            metaDict["parents"] = [cleanFolder]
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
                let msg = "Key hiện tại (\(apiKey?.prefix(10) ?? "trống")...) không có quyền ghi (POST) trực tiếp vào Google Drive API v3 (HTTP \(statusCode)). Ảnh đã được lưu an toàn vào Bộ nhớ đệm & đồng bộ Supabase! Xem mục Hướng dẫn Key Drive trong Cài đặt để kết nối Google Apps Script hoặc OAuth2."
                DispatchQueue.main.async { hoanThanh(nil, nil, msg) }
            }
        }.resume()
    }

    func taiAnhTuDrive(fileId: String, driveUrl: String?, hoanThanh: @escaping (UIImage?) -> Void) {
        let cd = KhoDuLieu.dungChung.caiDat
        let urlStr: String
        if let driveUrl, driveUrl.hasPrefix("http") {
            urlStr = driveUrl
        } else if !cd.driveKey.isEmpty && cd.driveKey.hasPrefix("AIza") {
            urlStr = "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media&key=\(cd.driveKey)"
        } else {
            urlStr = "https://drive.google.com/uc?export=download&id=\(fileId)"
        }
        guard let url = URL(string: urlStr) else {
            hoanThanh(nil)
            return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        if cd.driveKey.hasPrefix("ya29.") {
            req.setValue("Bearer \(cd.driveKey)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let img = UIImage(data: data) else {
                hoanThanh(nil)
                return
            }
            hoanThanh(img)
        }.resume()
    }
}

// MARK: - 3. Dịch Vụ Đồng Bộ Supabase (Auth + Backup/Restore + Đồng bộ Bảng Xưởng Cán)

enum TrangThaiDongBo: String {
    case ranh = "idle"
    case dangDongBo = "syncing"
    case dangTaiVe = "downloading"
    case thanhCong = "success"
    case loi = "error"
}

final class DichVuSupabase {
    static let dungChung = DichVuSupabase()

    // Giữ nguyên cấu hình Supabase từ supabaseConfig.ts của dự án ipa-main
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

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
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
                DispatchQueue.main.async { hoanThanh(.success(email)) }
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

    // MARK: Đồng bộ Xưởng Cán lên Supabase (Bảng xuong_can_bang + user_sync dự phòng)
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

        // 1. Đồng bộ vào bảng chuyên dụng `xuong_can_bang` trên Supabase (POST upsert)
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

            // 2. Nếu đã đăng nhập, đồng bộ luôn vào `user_sync` để đảm bảo 100% có bản lưu trên Supabase
            if self.daDangNhap {
                self.saoLuuTatCaLenMay { ok, msg in
                    self.trangThai = (ok || bangChuyenDungOK) ? .thanhCong : .loi
                    self.henTatTrangThai()
                    DispatchQueue.main.async {
                        hoanThanh?(ok || bangChuyenDungOK, (ok || bangChuyenDungOK) ? "Đã đồng bộ Xưởng Cán lên Supabase ☁️" : msg)
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

    /// Tải dữ liệu các bảng Xưởng Cán từ Supabase về máy
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
                if let jsonData = try? JSONSerialization.data(withJSONObject: duLieuMang) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let cacBang = try? decoder.decode([BangXuongCan].self, from: jsonData), !cacBang.isEmpty {
                        DispatchQueue.main.async {
                            KhoDuLieu.dungChung.luuBangXuongCan(cacBang, dongBoSupabase: false)
                            self.trangThai = .thanhCong
                            self.henTatTrangThai()
                            hoanThanh(true, "Đã tải \(cacBang.count) bảng Xưởng Cán từ Supabase!")
                        }
                        return
                    }
                }
            }

            // Nếu bảng `xuong_can_bang` trống hoặc chưa tạo, thử khôi phục từ `user_sync`
            if self.daDangNhap {
                self.khoiPhucTuMay { ok, msg in
                    self.trangThai = ok ? .thanhCong : .ranh
                    self.henTatTrangThai()
                    DispatchQueue.main.async {
                        hoanThanh(ok, msg)
                    }
                }
            } else {
                self.trangThai = .ranh
                DispatchQueue.main.async {
                    hoanThanh(false, "Chưa có dữ liệu trên bảng xuong_can_bang hoặc bạn chưa đăng nhập tài khoản đồng bộ.")
                }
            }
        }.resume()
    }

    // MARK: Sao lưu & Khôi phục toàn bộ ứng dụng qua bảng `user_sync` (tương thích ngược 100% với ipa-main)
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
                DispatchQueue.main.async { hoanThanh(true, "Đã lưu toàn bộ dữ liệu (bao gồm Xưởng Cán) lên đám mây Supabase ☁️") }
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

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
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

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let kho = KhoDuLieu.dungChung

            DispatchQueue.main.async {
                if let qn = backup["QUICK_NOTES"],
                   let d = try? JSONSerialization.data(withJSONObject: qn),
                   let list = try? decoder.decode([GhiChuNhanh].self, from: d) {
                    kho.luuGhiChuNhanh(list)
                }
                if let cn = backup["CALENDAR_NOTES"],
                   let d = try? JSONSerialization.data(withJSONObject: cn),
                   let dict = try? decoder.decode([String: GhiChuNgay].self, from: d) {
                    kho.luuGhiChuLich(dict)
                }
                if let rem = backup["USER_REMINDERS"],
                   let d = try? JSONSerialization.data(withJSONObject: rem),
                   let list = try? decoder.decode([SuKienNhacNho].self, from: d) {
                    kho.luuNhacNho(list)
                }
                if let xc = backup["XUONG_CAN_TABLES"],
                   let d = try? JSONSerialization.data(withJSONObject: xc),
                   let list = try? decoder.decode([BangXuongCan].self, from: d), !list.isEmpty {
                    kho.luuBangXuongCan(list, dongBoSupabase: false)
                }

                var cd = kho.caiDat
                if let sDate = backup["CYCLE_START_DATE"] as? String,
                   let d = ISO8601DateFormatter().date(from: sDate) {
                    cd.ngayBatDauChuKy = d
                }
                if let notif = backup["NOTIF_ENABLED"] as? Bool {
                    cd.batThongBao = notif
                }
                if let gKey = backup["GEMINI_API_KEY"] as? String, !gKey.isEmpty {
                    cd.geminiApiKey = gKey
                }
                if let pat = backup["WORK_CYCLE_PATTERN"] as? [String], !pat.isEmpty {
                    cd.chuKyLamViec = pat
                }
                if let dKey = backup["DRIVE_KEY"] as? String, !dKey.isEmpty {
                    cd.driveKey = dKey
                }
                if let dFolder = backup["DRIVE_FOLDER_ID"] as? String {
                    cd.driveFolderId = dFolder
                }
                if let dScript = backup["DRIVE_SCRIPT_URL"] as? String {
                    cd.driveScriptUrl = dScript
                }
                kho.luuCaiDat(cd)

                self?.trangThai = .thanhCong
                self?.henTatTrangThai()
                NotificationCenter.default.post(name: .duLieuDongBoXong, object: nil)
                hoanThanh(true, "Đã khôi phục toàn bộ dữ liệu về máy thành công!")
            }
        }.resume()
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
