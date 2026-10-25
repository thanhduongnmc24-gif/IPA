import UIKit
import UserNotifications

// MARK: - 1. Mô hình Lịch & Ghi chú nhanh & Nhắc nhở (Tương thích 100% dữ liệu cũ từ React Native / Supabase)

struct GhiChuNgay: Codable, Hashable {
    var type: String
    var noteLines: [String]

    init(type: String = "", noteLines: [String] = []) {
        self.type = type
        self.noteLines = noteLines
    }

    enum CodingKeys: String, CodingKey {
        case type, noteLines
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        self.noteLines = (try? c.decodeIfPresent([String].self, forKey: .noteLines)) ?? []
    }
}

struct GhiChuNhanh: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var content: String
    var date: String
    var isPinned: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        date: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, date, isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let strId = try? c.decodeIfPresent(String.self, forKey: .id), !strId.isEmpty {
            self.id = strId
        } else if let intId = try? c.decodeIfPresent(Int64.self, forKey: .id) {
            self.id = String(intId)
        } else if let dblId = try? c.decodeIfPresent(Double.self, forKey: .id) {
            self.id = String(Int64(dblId))
        } else {
            self.id = UUID().uuidString
        }
        self.title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        self.content = (try? c.decodeIfPresent(String.self, forKey: .content)) ?? ""
        self.date = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .isPinned) {
            self.isPinned = b
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .isPinned) {
            self.isPinned = (i != 0)
        } else {
            self.isPinned = false
        }
    }
}

struct SuKienNhacNho: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var content: String
    var dateTime: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        dateTime: Date
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.dateTime = dateTime
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, dateTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let strId = try? c.decodeIfPresent(String.self, forKey: .id), !strId.isEmpty {
            self.id = strId
        } else if let intId = try? c.decodeIfPresent(Int64.self, forKey: .id) {
            self.id = String(intId)
        } else {
            self.id = UUID().uuidString
        }
        self.title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        self.content = (try? c.decodeIfPresent(String.self, forKey: .content)) ?? ""
        if let d = try? c.decodeIfPresent(Date.self, forKey: .dateTime) {
            self.dateTime = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .dateTime),
                  let parsed = TienIchLich.docNgayISO(s) {
            self.dateTime = parsed
        } else {
            self.dateTime = Date()
        }
    }
}

struct MucChuSheet: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var cell: String = ""
    var content: String = ""
}

struct MucAnhSheet: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var cell: String = ""
    var maAnh: String? = nil
    var base64: String? = nil
}

// MARK: - 2. Mô hình Xưởng Cán (Chỉ lưu siêu dữ liệu & ID ảnh Google Drive lên Supabase, KHÔNG lưu dữ liệu ảnh lên Supabase)

enum LoaiCotXuongCan: String, Codable, CaseIterable {
    case chu = "text"
    case anh = "image"

    var tenHienThi: String {
        switch self {
        case .chu: return "Chữ (Text)"
        case .anh: return "Ảnh chụp (Image)"
        }
    }

    var bieuTuong: String {
        switch self {
        case .chu: return "text.alignleft"
        case .anh: return "camera.fill"
        }
    }
}

struct CotXuongCan: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var tenCot: String
    var loai: LoaiCotXuongCan
    var thuTu: Int
}

struct ThongTinAnhXuongCan: Codable, Hashable {
    var maAnh: String // Khóa lưu trong Bộ nhớ đệm của ứng dụng (RAM + Disk Cache)
    var driveFileId: String? // ID file ảnh trên Google Drive
    var driveUrl: String? // Đường dẫn xem/tải ảnh từ Google Drive
    var capNhatLuc: Date = Date()
    var daTaiLenDrive: Bool = false

    enum CodingKeys: String, CodingKey {
        case maAnh, driveFileId, driveUrl, capNhatLuc, daTaiLenDrive
    }
}

struct GiaTriOXuongCan: Codable, Hashable {
    var vanBan: String?
    var anh: ThongTinAnhXuongCan?
}

struct DongXuongCan: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var giaTri: [String: GiaTriOXuongCan] = [:] // Key = CotXuongCan.id
    var capNhatLuc: Date = Date()
}

struct BangXuongCan: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var tenBang: String
    var moTa: String = ""
    var cot: [CotXuongCan]
    var dong: [DongXuongCan]
    var capNhatLuc: Date = Date()
}

// MARK: - 3. Cấu hình & Cài đặt Ứng dụng

struct TrangThaiTab: Codable, Hashable {
    var xuongCan: Bool = true
    var calendar: Bool = true
    var notes: Bool = true
    var sheets: Bool = true
    var media: Bool = true
    var reminders: Bool = true
}

struct CaiDatUngDung: Codable {
    var giaoDienToi: Bool = false
    var trangThaiTab: TrangThaiTab = TrangThaiTab()
    var ngayBatDauChuKy: Date = Date()
    var daChonNgayBatDau: Bool = true
    var chuKyLamViec: [String] = ["ngay", "dem", "nghi"]
    var batThongBao: Bool = false
    var gioCaNgay: Date = TienIchLich.taoGio(gio: 6, phut: 0)
    var gioCaDem: Date = TienIchLich.taoGio(gio: 18, phut: 0)
    var gioNgayNghi: Date = TienIchLich.taoGio(gio: 8, phut: 0)
    var gioBinhThuong: Date = TienIchLich.taoGio(gio: 7, phut: 0)
    var geminiApiKey: String = ""
    var sheetWebhookUrl: String = "https://script.google.com/macros/s/AKfycbwmGmcshrvrCsfmqXmj1qlyERulh0CtawveADAMK8rwR4g-Oa5h4NMEo73EiSrIiNcK/exec"

    // Cấu hình Google Drive cho Xưởng Cán
    var driveKey: String = "AQ.Ab8RN6IGGziGDdVjRVKCwe06oAOX8OldcVLm3fLdoRu3ZpwEsg"
    var driveFolderId: String = ""
    var driveScriptUrl: String = ""
    var driveClientId: String = ""
    var driveClientSecret: String = ""
    var driveRefreshToken: String = ""
}

// MARK: - 4. Bảng màu Giao diện

struct BangMauChuDe {
    let laToi: Bool
    var bg: UIColor { laToi ? UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1) : UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1) }
    var card: UIColor { laToi ? UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1) : .white }
    var text: UIColor { laToi ? UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1) : UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1) }
    var subText: UIColor { laToi ? UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1) : UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1) }
    var border: UIColor { laToi ? UIColor(red: 0.20, green: 0.25, blue: 0.33, alpha: 1) : UIColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1) }
    var primary: UIColor { laToi ? UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1) : UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1) }
    var iconBg: UIColor { laToi ? UIColor(red: 0.15, green: 0.20, blue: 0.28, alpha: 1) : UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1) }
    var success: UIColor { laToi ? UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1) : UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1) }
    var error: UIColor { laToi ? UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1) : UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1) }
    var xuongCanAccent: UIColor { laToi ? UIColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1) : UIColor(red: 0.92, green: 0.35, blue: 0.05, alpha: 1) }
}

extension Notification.Name {
    static let caiDatThayDoi = Notification.Name("CaiDatUngDungThayDoi")
    static let duLieuDongBoXong = Notification.Name("DuLieuDongBoXong")
    static let xuongCanCapNhat = Notification.Name("XuongCanCapNhat")
    static let trangThaiDongBoThayDoi = Notification.Name("TrangThaiDongBoThayDoi")
}

// MARK: - 5. Kho Lưu Trữ Cục Bộ & Tự Động Di Chuyển Dữ Liệu Cũ Từ React Native (AsyncStorage)

final class ThuMucDuLieu {
    static let dungChung = ThuMucDuLieu()

    let thuMuc: URL
    let thuMucAnhCache: URL
    let tepLich: URL
    let tepGhiChuNhanh: URL
    let tepNhacNho: URL
    let tepCaiDat: URL
    let tepXuongCan: URL

    private let maHoa: JSONEncoder = {
        let bo = JSONEncoder()
        bo.outputFormatting = [.prettyPrinted, .sortedKeys]
        bo.dateEncodingStrategy = .iso8601
        return bo
    }()

    private let giaiMa: JSONDecoder = {
        let bo = JSONDecoder()
        bo.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = TienIchLich.docNgayISO(str) {
                return d
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return bo
    }()

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        thuMuc = documents.appendingPathComponent("DuLieuGhiChu", isDirectory: true)
        thuMucAnhCache = thuMuc.appendingPathComponent("AnhCacheXuongCan", isDirectory: true)
        tepLich = thuMuc.appendingPathComponent("lich-ghi-chu.json")
        tepGhiChuNhanh = thuMuc.appendingPathComponent("ghi-chu-nhanh.json")
        tepNhacNho = thuMuc.appendingPathComponent("nhac-nho.json")
        tepCaiDat = thuMuc.appendingPathComponent("cai-dat.json")
        tepXuongCan = thuMuc.appendingPathComponent("xuong-can.json")

        try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thuMucAnhCache, withIntermediateDirectories: true)
    }

    func doc<T: Decodable>(_ loai: T.Type, tu tep: URL) -> T? {
        guard let data = try? Data(contentsOf: tep) else { return nil }
        return try? giaiMa.decode(loai, from: data)
    }

    func giaiMaDuLieu<T: Decodable>(_ loai: T.Type, tu data: Data) -> T? {
        return try? giaiMa.decode(loai, from: data)
    }

    @discardableResult
    func ghi<T: Encodable>(_ giaTri: T, vao tep: URL) -> Bool {
        do {
            let data = try maHoa.encode(giaTri)
            try data.write(to: tep, options: .atomic)
            return true
        } catch {
            print("Lỗi ghi tệp \(tep.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }
}

final class KhoDuLieu {
    static let dungChung = KhoDuLieu()

    private(set) var ghiChuLich: [String: GhiChuNgay] = [:]
    private(set) var ghiChuNhanh: [GhiChuNhanh] = []
    private(set) var nhacNho: [SuKienNhacNho] = []
    private(set) var danhSachBangXuongCan: [BangXuongCan] = []
    var caiDat: CaiDatUngDung = CaiDatUngDung()

    var mauSac: BangMauChuDe {
        BangMauChuDe(laToi: caiDat.giaoDienToi)
    }

    private init() {
        napTatCa()
        khoiPhucTuAsyncStorageNeuCan()
    }

    func napTatCa() {
        let tm = ThuMucDuLieu.dungChung
        if let d = tm.doc([String: GhiChuNgay].self, tu: tm.tepLich) {
            ghiChuLich = d
        }
        if let d = tm.doc([GhiChuNhanh].self, tu: tm.tepGhiChuNhanh) {
            ghiChuNhanh = sapXepGhiChuNhanh(d)
        }
        if let d = tm.doc([SuKienNhacNho].self, tu: tm.tepNhacNho) {
            nhacNho = d
        }
        if let d = tm.doc(CaiDatUngDung.self, tu: tm.tepCaiDat) {
            caiDat = d
            if caiDat.driveKey.isEmpty {
                caiDat.driveKey = "AQ.Ab8RN6IGGziGDdVjRVKCwe06oAOX8OldcVLm3fLdoRu3ZpwEsg"
            }
        } else {
            tm.ghi(caiDat, vao: tm.tepCaiDat)
        }
        if let d = tm.doc([BangXuongCan].self, tu: tm.tepXuongCan), !d.isEmpty {
            danhSachBangXuongCan = d
        } else {
            let cot1 = CotXuongCan(tenCot: "Mã lô / Phôi", loai: .chu, thuTu: 0)
            let cot2 = CotXuongCan(tenCot: "Thông số cán", loai: .chu, thuTu: 1)
            let cot3 = CotXuongCan(tenCot: "Ảnh chụp kiểm tra", loai: .anh, thuTu: 2)
            let cot4 = CotXuongCan(tenCot: "Ghi chú", loai: .chu, thuTu: 3)
            let dongMau = DongXuongCan(giaTri: [
                cot1.id: GiaTriOXuongCan(vanBan: "LO-01", anh: nil),
                cot2.id: GiaTriOXuongCan(vanBan: "Đạt chuẩn", anh: nil),
                cot4.id: GiaTriOXuongCan(vanBan: "Ca sáng", anh: nil)
            ])
            let bangMau = BangXuongCan(
                tenBang: "Bảng Cán Thép Ca 1",
                moTa: "Bảng theo dõi thông số và hình ảnh thực tế tại Xưởng Cán",
                cot: [cot1, cot2, cot3, cot4],
                dong: [dongMau]
            )
            danhSachBangXuongCan = [bangMau]
            tm.ghi(danhSachBangXuongCan, vao: tm.tepXuongCan)
        }
    }

    /// Tự động đọc dữ liệu cũ từ AsyncStorage của bản React Native (nếu cài đè lên ứng dụng cũ trên iPhone)
    private func khoiPhucTuAsyncStorageNeuCan() {
        let fm = FileManager.default
        var cacThuMucUngVien: [URL] = []
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            cacThuMucUngVien.append(appSupport.appendingPathComponent("RCTAsyncLocalStorage_V1"))
            if let bundleId = Bundle.main.bundleIdentifier {
                cacThuMucUngVien.append(appSupport.appendingPathComponent(bundleId).appendingPathComponent("RCTAsyncLocalStorage_V1"))
            }
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            cacThuMucUngVien.append(docs.appendingPathComponent("RCTAsyncLocalStorage_V1"))
        }

        for thuMuc in cacThuMucUngVien {
            let manifestURL = thuMuc.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if ghiChuNhanh.isEmpty,
               let rawNotes = manifest["QUICK_NOTES"] as? String,
               let dNotes = rawNotes.data(using: .utf8),
               let list = ThuMucDuLieu.dungChung.giaiMaDuLieu([GhiChuNhanh].self, tu: dNotes),
               !list.isEmpty {
                luuGhiChuNhanh(list)
            }

            if ghiChuLich.isEmpty,
               let rawCal = manifest["CALENDAR_NOTES"] as? String,
               let dCal = rawCal.data(using: .utf8),
               let dict = ThuMucDuLieu.dungChung.giaiMaDuLieu([String: GhiChuNgay].self, tu: dCal),
               !dict.isEmpty {
                luuGhiChuLich(dict)
            }

            if nhacNho.isEmpty,
               let rawRem = manifest["USER_REMINDERS"] as? String,
               let dRem = rawRem.data(using: .utf8),
               let list = ThuMucDuLieu.dungChung.giaiMaDuLieu([SuKienNhacNho].self, tu: dRem),
               !list.isEmpty {
                luuNhacNho(list)
            }
        }
    }

    func luuGhiChuLich(_ moi: [String: GhiChuNgay]) {
        ghiChuLich = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepLich)
    }

    func sapXepGhiChuNhanh(_ ds: [GhiChuNhanh]) -> [GhiChuNhanh] {
        ds.sorted { a, b in
            if a.isPinned && !b.isPinned { return true }
            if !a.isPinned && b.isPinned { return false }
            return false
        }
    }

    func luuGhiChuNhanh(_ moi: [GhiChuNhanh]) {
        let daSapXep = sapXepGhiChuNhanh(moi)
        ghiChuNhanh = daSapXep
        ThuMucDuLieu.dungChung.ghi(daSapXep, vao: ThuMucDuLieu.dungChung.tepGhiChuNhanh)
    }

    func luuNhacNho(_ moi: [SuKienNhacNho]) {
        nhacNho = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepNhacNho)
    }

    func luuCaiDat(_ moi: CaiDatUngDung, thongBao: Bool = true) {
        caiDat = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepCaiDat)
        if thongBao {
            NotificationCenter.default.post(name: .caiDatThayDoi, object: nil)
        }
    }

    func luuBangXuongCan(_ moi: [BangXuongCan], dongBoSupabase: Bool = true) {
        danhSachBangXuongCan = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepXuongCan)
        NotificationCenter.default.post(name: .xuongCanCapNhat, object: nil)
        if dongBoSupabase {
            DichVuSupabase.dungChung.dongBoXuongCanTuDong()
        }
    }

    func capNhatMotBangXuongCan(_ bang: BangXuongCan, dongBoSupabase: Bool = true) {
        var ds = danhSachBangXuongCan
        if let idx = ds.firstIndex(where: { $0.id == bang.id }) {
            ds[idx] = bang
        } else {
            ds.append(bang)
        }
        luuBangXuongCan(ds, dongBoSupabase: dongBoSupabase)
    }
}

// MARK: - 6. Tiện ích Lịch Dương, Âm Lịch, Ca Làm Việc & Thông Báo

enum TienIchLich {
    static var lich: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "vi_VN")
        cal.timeZone = .current
        cal.firstWeekday = 2
        return cal
    }

    static let dinhDangKhoaNgay: DateFormatter = {
        let df = DateFormatter()
        df.calendar = lich
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    static let dinhDangNgayViet: DateFormatter = {
        let df = DateFormatter()
        df.calendar = lich
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM/yyyy"
        return df
    }()

    static let dinhDangGioPhut: DateFormatter = {
        let df = DateFormatter()
        df.calendar = lich
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "HH:mm"
        return df
    }()

    private static let isoCoPhanThapPhan: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoChuan: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func docNgayISO(_ chuoi: String) -> Date? {
        if let d = isoCoPhanThapPhan.date(from: chuoi) { return d }
        if let d = isoChuan.date(from: chuoi) { return d }
        if let d = dinhDangKhoaNgay.date(from: chuoi) { return d }
        return nil
    }

    static func taoGio(gio: Int, phut: Int) -> Date {
        lich.date(bySettingHour: gio, minute: phut, second: 0, of: Date()) ?? Date()
    }

    static func dauThang(_ ngay: Date) -> Date {
        lich.date(from: lich.dateComponents([.year, .month], from: ngay)) ?? ngay
    }

    static func cacNgayTrongLuoiThang(_ thang: Date) -> [Date] {
        let dThang = dauThang(thang)
        guard let phamVi = lich.range(of: .day, in: .month, for: dThang),
              let cuoiThang = lich.date(byAdding: .day, value: phamVi.count - 1, to: dThang) else {
            return []
        }
        let weekdayDau = lich.component(.weekday, from: dThang)
        let luiNgay = (weekdayDau + 5) % 7
        let batDauLuoi = lich.date(byAdding: .day, value: -luiNgay, to: dThang)!

        let weekdayCuoi = lich.component(.weekday, from: cuoiThang)
        let tienNgay = (8 - weekdayCuoi) % 7
        let ketThucLuoi = lich.date(byAdding: .day, value: tienNgay, to: cuoiThang)!

        var ketQua: [Date] = []
        var hienTai = batDauLuoi
        while hienTai <= ketThucLuoi {
            ketQua.append(hienTai)
            hienTai = lich.date(byAdding: .day, value: 1, to: hienTai)!
        }
        return ketQua
    }

    static func thongTinAmLich(_ ngay: Date) -> (chuoi: String, laMungMot: Bool) {
        var lichAm = Calendar(identifier: .chinese)
        lichAm.locale = Locale(identifier: "vi_VN")
        lichAm.timeZone = .current
        let tp = lichAm.dateComponents([.day, .month], from: ngay)
        guard let ngayAm = tp.day, let thangAm = tp.month else { return ("", false) }
        if ngayAm == 1 {
            return ("\(ngayAm)/\(thangAm)", true)
        }
        return ("\(ngayAm)", false)
    }

    static func tinhCaTuDong(cho ngay: Date) -> String? {
        let cd = KhoDuLieu.dungChung.caiDat
        guard cd.daChonNgayBatDau, !cd.chuKyLamViec.isEmpty else { return nil }
        let d1 = lich.startOfDay(for: cd.ngayBatDauChuKy)
        let d2 = lich.startOfDay(for: ngay)
        let soNgay = lich.dateComponents([.day], from: d1, to: d2).day ?? 0
        let doDai = cd.chuKyLamViec.count
        let du = ((soNgay % doDai) + doDai) % doDai
        return cd.chuKyLamViec[du]
    }

    static func xinQuyenThongBao() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func datThongBaoLich(ngay: Date, dongGhiChu: [String], loaiCa: String) {
        let cd = KhoDuLieu.dungChung.caiDat
        guard cd.batThongBao, !dongGhiChu.isEmpty else { return }

        let gioChon: Date
        let tieuDeCa: String
        switch loaiCa {
        case "ngay":
            gioChon = cd.gioCaNgay
            tieuDeCa = "Ca Ngày"
        case "dem":
            gioChon = cd.gioCaDem
            tieuDeCa = "Ca Đêm"
        case "nghi":
            gioChon = cd.gioNgayNghi
            tieuDeCa = "Ngày Nghỉ"
        default:
            gioChon = cd.gioBinhThuong
            tieuDeCa = "Ghi chú"
        }

        let tpGio = lich.dateComponents([.hour, .minute], from: gioChon)
        guard let thoiDiem = lich.date(bySettingHour: tpGio.hour ?? 7, minute: tpGio.minute ?? 0, second: 0, of: ngay),
              thoiDiem > Date() else { return }

        let noiDung = UNMutableNotificationContent()
        noiDung.title = "🔔 Lịch: \(tieuDeCa)"
        noiDung.body = dongGhiChu.joined(separator: "\n")
        noiDung.sound = .default

        let tpTrigger = lich.dateComponents([.year, .month, .day, .hour, .minute], from: thoiDiem)
        let trigger = UNCalendarNotificationTrigger(dateMatching: tpTrigger, repeats: false)
        let id = "LICH_\(dinhDangKhoaNgay.string(from: ngay))"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: noiDung, trigger: trigger))
    }

    static func datThongBaoNhacNho(_ suKien: SuKienNhacNho) {
        guard suKien.dateTime > Date() else { return }
        let noiDung = UNMutableNotificationContent()
        noiDung.title = "🔔 \(suKien.title)"
        noiDung.body = suKien.content.isEmpty ? "Đến giờ hẹn rồi đại ca ơi!" : suKien.content
        noiDung.sound = .default

        let tp = lich.dateComponents([.year, .month, .day, .hour, .minute], from: suKien.dateTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: tp, repeats: false)
        let id = "REMINDER_\(suKien.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: noiDung, trigger: trigger))
    }
}
