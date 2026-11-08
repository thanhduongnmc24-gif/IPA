import UIKit
import UserNotifications

// MARK: - Hằng số OAuth 2.0 Google Drive mặc định của người dùng

enum HangSoDriveMacDinh {
    static let clientId = ""
    static let clientSecret = ""
    static let refreshToken = ""
}

// MARK: - 1. Mô hình Lịch & Ghi chú nhanh & Nhắc nhở

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

// MARK: - 1B. Mô hình Thực Đơn Theo Ca / Ngày (Chuẩn 11 cột: Cải thiện, TĐ1, TĐ2, Chiều/Tối, Ăn đêm, Sáng hôm sau, Ghi chú)

struct MucThucDonNgay: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var ngayVaoCa: String       // Cột 1: Ngày vào ca (VD: "08/11/2026")
    var khoaNgay: String        // Khóa chuẩn: "2026-11-08"
    var ca: String              // Cột 2: Ca ("Ngày" hoặc "Đêm")
    var truaCaiThien: String    // Cột 3: Trưa - Cải thiện
    var td1MonChinh: String     // Cột 4: TĐ1 - Món chính
    var td1MonPhu: String       // Cột 5: TĐ1 - Món phụ
    var td2MonChinh: String     // Cột 6: TĐ2 - Món chính
    var td2MonPhu: String       // Cột 7: TĐ2 - Món phụ
    var chieuToi: String        // Cột 8: Chiều/Tối (1 thực đơn)
    var anDem: String           // Cột 9: Ăn đêm (ca đêm)
    var sangHomSau: String      // Cột 10: Sáng hôm sau
    var ghiChu: String          // Cột 11: Ghi chú

    init(
        id: String = UUID().uuidString,
        ngayVaoCa: String,
        khoaNgay: String = "",
        ca: String,
        truaCaiThien: String = "",
        td1MonChinh: String = "",
        td1MonPhu: String = "",
        td2MonChinh: String = "",
        td2MonPhu: String = "",
        chieuToi: String = "",
        anDem: String = "",
        sangHomSau: String = "",
        ghiChu: String = ""
    ) {
        self.id = id
        if let chuan = TienIchLich.chuanHoaNgayThucDon(ngayVaoCa) {
            self.ngayVaoCa = chuan.hienThi
            self.khoaNgay = khoaNgay.isEmpty ? chuan.khoa : khoaNgay
        } else {
            self.ngayVaoCa = ngayVaoCa
            self.khoaNgay = khoaNgay
        }
        self.ca = ca
        self.truaCaiThien = truaCaiThien
        self.td1MonChinh = td1MonChinh
        self.td1MonPhu = td1MonPhu
        self.td2MonChinh = td2MonChinh
        self.td2MonPhu = td2MonPhu
        self.chieuToi = chieuToi
        self.anDem = anDem
        self.sangHomSau = sangHomSau
        self.ghiChu = ghiChu
    }

    enum CodingKeys: String, CodingKey {
        case id, ngayVaoCa, khoaNgay, ca, truaCaiThien
        case td1MonChinh, td1MonPhu, td2MonChinh, td2MonPhu
        case truaMonChinh, truaMonThuHai // Tương thích ngược nếu có bản lưu cũ
        case chieuToi, anDem, sangHomSau, ghiChu
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        let rawNgay = (try? c.decodeIfPresent(String.self, forKey: .ngayVaoCa)) ?? ""
        let rawKhoa = (try? c.decodeIfPresent(String.self, forKey: .khoaNgay)) ?? ""
        if let chuan = TienIchLich.chuanHoaNgayThucDon(rawNgay) {
            self.ngayVaoCa = chuan.hienThi
            self.khoaNgay = rawKhoa.isEmpty ? chuan.khoa : rawKhoa
        } else {
            self.ngayVaoCa = rawNgay
            self.khoaNgay = rawKhoa
        }
        self.ca = (try? c.decodeIfPresent(String.self, forKey: .ca)) ?? ""
        self.truaCaiThien = (try? c.decodeIfPresent(String.self, forKey: .truaCaiThien)) ?? ""
        let m1Chinh = (try? c.decodeIfPresent(String.self, forKey: .td1MonChinh)) ?? ""
        let m1Cu = (try? c.decodeIfPresent(String.self, forKey: .truaMonChinh)) ?? ""
        self.td1MonChinh = m1Chinh.isEmpty ? m1Cu : m1Chinh

        let m1Phu = (try? c.decodeIfPresent(String.self, forKey: .td1MonPhu)) ?? ""
        let m2Cu = (try? c.decodeIfPresent(String.self, forKey: .truaMonThuHai)) ?? ""
        self.td1MonPhu = m1Phu.isEmpty ? m2Cu : m1Phu

        self.td2MonChinh = (try? c.decodeIfPresent(String.self, forKey: .td2MonChinh)) ?? ""
        self.td2MonPhu = (try? c.decodeIfPresent(String.self, forKey: .td2MonPhu)) ?? ""
        self.chieuToi = (try? c.decodeIfPresent(String.self, forKey: .chieuToi)) ?? ""
        self.anDem = (try? c.decodeIfPresent(String.self, forKey: .anDem)) ?? ""
        self.sangHomSau = (try? c.decodeIfPresent(String.self, forKey: .sangHomSau)) ?? ""
        self.ghiChu = (try? c.decodeIfPresent(String.self, forKey: .ghiChu)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ngayVaoCa, forKey: .ngayVaoCa)
        try c.encode(khoaNgay, forKey: .khoaNgay)
        try c.encode(ca, forKey: .ca)
        try c.encode(truaCaiThien, forKey: .truaCaiThien)
        try c.encode(td1MonChinh, forKey: .td1MonChinh)
        try c.encode(td1MonPhu, forKey: .td1MonPhu)
        try c.encode(td2MonChinh, forKey: .td2MonChinh)
        try c.encode(td2MonPhu, forKey: .td2MonPhu)
        try c.encode(chieuToi, forKey: .chieuToi)
        try c.encode(anDem, forKey: .anDem)
        try c.encode(sangHomSau, forKey: .sangHomSau)
        try c.encode(ghiChu, forKey: .ghiChu)
    }

    var laCaDem: Bool {
        let c = ca.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if c.contains("dem") || c.contains("đêm") || c.contains("toi") { return true }
        if c.contains("ngay") || c.contains("ngày") || c.contains("sang") { return false }
        return (!anDem.isEmpty || !sangHomSau.isEmpty) && truaCaiThien.isEmpty && td1MonChinh.isEmpty && td2MonChinh.isEmpty
    }

    var laCaNgay: Bool {
        let c = ca.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if c.contains("ngay") || c.contains("ngày") || c.contains("sang") { return true }
        if laCaDem { return false }
        return !truaCaiThien.isEmpty || !td1MonChinh.isEmpty || !td1MonPhu.isEmpty || !td2MonChinh.isEmpty || !td2MonPhu.isEmpty || !chieuToi.isEmpty
    }

    var caChuan: String {
        if laCaDem { return "dem" }
        if laCaNgay { return "ngay" }
        return "khac"
    }

    var chuoiThucDon1: String {
        [td1MonChinh, td1MonPhu]
            .map { /usr/bin/bash.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !/usr/bin/bash.isEmpty }
            .joined(separator: " + ")
    }

    var chuoiThucDon2: String {
        [td2MonChinh, td2MonPhu]
            .map { /usr/bin/bash.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !/usr/bin/bash.isEmpty }
            .joined(separator: " + ")
    }

    var tomTatThongBao: String {
        var cacDong: [String] = []
        if laCaNgay {
            let ct = truaCaiThien.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ct.isEmpty {
                cacDong.append("🍱 Cải thiện: \(ct)")
            }
            let td1 = chuoiThucDon1
            if !td1.isEmpty {
                cacDong.append("🍛 Trưa TĐ1: \(td1)")
            }
            let td2 = chuoiThucDon2
            if !td2.isEmpty {
                cacDong.append("🍛 Trưa TĐ2: \(td2)")
            }
            let chieu = chieuToi.trimmingCharacters(in: .whitespacesAndNewlines)
            if !chieu.isEmpty {
                cacDong.append("🍲 Chiều/Tối: \(chieu)")
            }
        }
        if laCaDem || (!anDem.isEmpty || !sangHomSau.isEmpty) {
            let ad = anDem.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ad.isEmpty {
                cacDong.append("🍜 Ăn đêm: \(ad)")
            }
            let shs = sangHomSau.trimmingCharacters(in: .whitespacesAndNewlines)
            if !shs.isEmpty {
                cacDong.append("🥖 Sáng hôm sau: \(shs)")
            }
        }
        let gc = ghiChu.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gc.isEmpty && cacDong.isEmpty {
            cacDong.append("📝 \(gc)")
        }
        return cacDong.isEmpty ? "Thực đơn ngày \(ngayVaoCa)" : cacDong.joined(separator: "\n")
    }
}

struct QuyTacThucDon: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var noiDung: String
    var quyTac: String
}

struct DuLieuThucDon: Codable, Hashable {
    var tenTepNguon: String
    var tenSheetChinh: String
    var capNhatLuc: Date
    var danhSachNgay: [MucThucDonNgay]
    var quyTacLoc: [QuyTacThucDon]

    init(
        tenTepNguon: String = "",
        tenSheetChinh: String = "",
        capNhatLuc: Date = Date(),
        danhSachNgay: [MucThucDonNgay] = [],
        quyTacLoc: [QuyTacThucDon] = []
    ) {
        self.tenTepNguon = tenTepNguon
        self.tenSheetChinh = tenSheetChinh
        self.capNhatLuc = capNhatLuc
        self.danhSachNgay = danhSachNgay
        self.quyTacLoc = quyTacLoc
    }

    static func duLieuMauThang11() -> DuLieuThucDon {
        let ds: [MucThucDonNgay] = [
            MucThucDonNgay(
                ngayVaoCa: "08/11/2026",
                ca: "Ngày",
                truaCaiThien: "Bánh canh chả tôm / Sữa tươi Ba Vì",
                td1MonChinh: "Bò nấu lagu",
                td1MonPhu: "Đậu khuôn chiên sốt cà",
                td2MonChinh: "Thịt kho trứng",
                td2MonPhu: "Đậu khuôn chiên sốt cà",
                chieuToi: "Cotlet rim; Chả cá rim tiêu; Cơm trắng; Cà tím xào mỡ hành; Canh dưa chua thịt bò"
            ),
            MucThucDonNgay(
                ngayVaoCa: "09/11/2026",
                ca: "Đêm",
                anDem: "Hủ tiếu giò heo / Sữa tươi Vinamilk",
                sangHomSau: "10/11: Bánh mì cà ri gà / Sữa tươi Ba Vì"
            ),
            MucThucDonNgay(
                ngayVaoCa: "11/11/2026",
                ca: "Ngày",
                truaCaiThien: "Cơm chiên Dương Châu / Sữa tươi Ba Vì / Táo",
                td1MonChinh: "Cá diêu hồng chiên mắm",
                td1MonPhu: "Gỏi dưa leo chả lụa",
                td2MonChinh: "Thịt kho tàu",
                td2MonPhu: "Gỏi dưa leo chả lụa",
                chieuToi: "Cotlet nướng mỡ hành; Trứng chiên hành; Cơm trắng; Cải thảo xào; Canh dưa chua thịt bò"
            ),
            MucThucDonNgay(
                ngayVaoCa: "12/11/2026",
                ca: "Đêm",
                anDem: "Bánh mì bò áp chảo / Sữa Yomost",
                sangHomSau: "13/11: Cháo gà kiến / Sữa tươi Vinamilk"
            ),
            MucThucDonNgay(
                ngayVaoCa: "14/11/2026",
                ca: "Ngày",
                truaCaiThien: "Bún gà nấu ớt hiểm / Sữa Yomost",
                td1MonChinh: "Tỏi gà rôty",
                td1MonPhu: "Thịt xào dưa cải",
                td2MonChinh: "Cá biển kho",
                td2MonPhu: "Thịt xào dưa cải",
                chieuToi: "Giò kho sả ớt; Ốc om chuối đậu; Cơm trắng; Bầu xào; Canh mồng tơi nấu cua/ghẹ"
            ),
            MucThucDonNgay(
                ngayVaoCa: "15/11/2026",
                ca: "Đêm",
                anDem: "Mì tôm, tôm, trứng vịt lộn / Sữa tươi Vinamilk",
                sangHomSau: "16/11: Bún giò heo / Sữa tươi Ba Vì"
            ),
            MucThucDonNgay(
                ngayVaoCa: "17/11/2026",
                ca: "Ngày",
                truaCaiThien: "Mì tôm thịt bò, trứng ốp la / Sữa tươi Ba Vì",
                td1MonChinh: "Tỏi gà chiên mắm",
                td1MonPhu: "Trứng gà luộc",
                td2MonChinh: "Tôm rim thịt",
                td2MonPhu: "Trứng gà luộc",
                chieuToi: "Cotlet nướng mỡ hành; Đậu khuôn chiên sốt cà; Cơm trắng; Bầu luộc; Canh chua chả cá"
            ),
            MucThucDonNgay(
                ngayVaoCa: "18/11/2026",
                ca: "Đêm",
                anDem: "Mì quảng thập cẩm / Sữa tươi Kun",
                sangHomSau: "19/11: Hủ tiếu thập cẩm / Sữa tươi Kun"
            ),
            MucThucDonNgay(
                ngayVaoCa: "20/11/2026",
                ca: "Ngày",
                truaCaiThien: "Hủ tiếu bò / Sữa tươi Ba Vì",
                td1MonChinh: "Sườn sốt chua ngọt",
                td1MonPhu: "Thịt xào dưa cải",
                td2MonChinh: "Cá biển chiên mắm",
                td2MonPhu: "Thịt xào dưa cải",
                chieuToi: "Bò xào hành cần; Cá cơm khô rang đậu phộng; Cơm trắng; Rau cải luộc; Canh khổ qua nấu thịt"
            ),
            MucThucDonNgay(
                ngayVaoCa: "21/11/2026",
                ca: "Đêm",
                anDem: "Bánh canh chả cá / Sữa tươi Vinamilk",
                sangHomSau: "22/11: Bánh mì thịt, xúc xích, trứng ốp la / Sữa Yomost"
            ),
            MucThucDonNgay(
                ngayVaoCa: "23/11/2026",
                ca: "Ngày",
                truaCaiThien: "Cơm tấm / Sữa Yomost / Chuối",
                td1MonChinh: "Cánh gà chiên mắm",
                td1MonPhu: "Chả cá chiên sốt cà",
                td2MonChinh: "Thịt rim mặn",
                td2MonPhu: "Chả cá chiên sốt cà",
                chieuToi: "Tôm rim; Cá biển kho; Cơm trắng; Bầu luộc; Canh bí đỏ nấu thịt"
            ),
            MucThucDonNgay(
                ngayVaoCa: "24/11/2026",
                ca: "Đêm",
                anDem: "Mì quảng thập cẩm / Sữa tươi Kun",
                sangHomSau: "25/11: Cháo lươn hoặc cháo ngao, trứng vịt lộn (tùy bếp) / Sữa tươi Vinamilk"
            ),
            MucThucDonNgay(
                ngayVaoCa: "26/11/2026",
                ca: "Ngày",
                truaCaiThien: "Bún Thái hải sản / Sữa Yomost",
                td1MonChinh: "Bò xào hành cần",
                td1MonPhu: "Thịt viên chiên sốt cà",
                td2MonChinh: "Cá biển kho tiêu",
                td2MonPhu: "Thịt viên chiên sốt cà",
                chieuToi: "Gà kho sả ớt; Thịt xào dưa cải; Cơm trắng; Mít xào lá lốt; Canh cải nấu thịt"
            ),
            MucThucDonNgay(
                ngayVaoCa: "27/11/2026",
                ca: "Đêm",
                anDem: "Mì tôm thịt bò, trứng ốp la / Sữa chua Ba Vì và Chuối",
                sangHomSau: "28/11: Bún măng vịt / Sữa tươi Ba Vì"
            ),
            MucThucDonNgay(
                ngayVaoCa: "29/11/2026",
                ca: "Ngày",
                truaCaiThien: "Phở bò / Sữa tươi Vinamilk",
                td1MonChinh: "Sườn kho sả",
                td1MonPhu: "Trứng gà luộc",
                td2MonChinh: "Cơm gà",
                td2MonPhu: "Trứng gà luộc",
                chieuToi: "Cá lóc chiên mắm xoài; Chả lụa xào nấm hành tây; Cơm trắng; Rau cải, giá luộc; Canh bí xanh nấu chả cá"
            ),
            MucThucDonNgay(
                ngayVaoCa: "30/11/2026",
                ca: "Đêm",
                anDem: "Bún sườn chua / Sữa tươi Ba Vì",
                sangHomSau: "01/12: Không có trong thực đơn tháng 11",
                ghiChu: "Cần thực đơn tháng 12 để bổ sung bữa sáng sau ca đêm 30/11."
            )
        ]

        let qt: [QuyTacThucDon] = [
            QuyTacThucDon(noiDung: "Chu kỳ kíp A", quyTac: "Ngày → Đêm → Nghỉ, lặp lại từ 08/11/2026"),
            QuyTacThucDon(noiDung: "Ca ngày", quyTac: "Ca ngày: bữa trưa gồm món cải thiện, Thực đơn 1 (món chính + món phụ), Thực đơn 2 (món chính + món phụ); bữa chiều chỉ có 1 thực đơn."),
            QuyTacThucDon(noiDung: "Ca đêm", quyTac: "Ca đêm: lấy món ăn đêm ngày vào ca và món ăn sáng của ngày kế tiếp."),
            QuyTacThucDon(noiDung: "Nguồn", quyTac: "Thực đơn tháng 11/2026 do Anh Hai cung cấp")
        ]

        return DuLieuThucDon(
            tenTepNguon: "thuc_don_kip_A_thang_11_2026_da_kiem_tra.xlsx",
            tenSheetChinh: "Kíp A tháng 11",
            capNhatLuc: Date(),
            danhSachNgay: ds,
            quyTacLoc: qt
        )
    }
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
    var giaTri: [String: GiaTriOXuongCan] = [:]
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
    var thucDon: Bool = true
    var notes: Bool = true
    var sheets: Bool = true
    var media: Bool = true
    var reminders: Bool = true

    init(
        xuongCan: Bool = true,
        calendar: Bool = true,
        thucDon: Bool = true,
        notes: Bool = true,
        sheets: Bool = true,
        media: Bool = true,
        reminders: Bool = true
    ) {
        self.xuongCan = xuongCan
        self.calendar = calendar
        self.thucDon = thucDon
        self.notes = notes
        self.sheets = sheets
        self.media = media
        self.reminders = reminders
    }

    enum CodingKeys: String, CodingKey {
        case xuongCan, calendar, thucDon, notes, sheets, media, reminders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.xuongCan = (try? c.decodeIfPresent(Bool.self, forKey: .xuongCan)) ?? true
        self.calendar = (try? c.decodeIfPresent(Bool.self, forKey: .calendar)) ?? true
        self.thucDon = (try? c.decodeIfPresent(Bool.self, forKey: .thucDon)) ?? true
        self.notes = (try? c.decodeIfPresent(Bool.self, forKey: .notes)) ?? true
        self.sheets = (try? c.decodeIfPresent(Bool.self, forKey: .sheets)) ?? true
        self.media = (try? c.decodeIfPresent(Bool.self, forKey: .media)) ?? true
        self.reminders = (try? c.decodeIfPresent(Bool.self, forKey: .reminders)) ?? true
    }
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

    // Thông báo Thực đơn (giống thông báo nghỉ luân phiên, chỉnh giờ ở Cài đặt)
    var batThongBaoThucDon: Bool = true
    var gioThongBaoThucDonNgay: Date = TienIchLich.taoGio(gio: 6, phut: 30)
    var gioThongBaoThucDonDem: Date = TienIchLich.taoGio(gio: 17, phut: 30)

    var geminiApiKey: String = ""
    var sheetWebhookUrl: String = "https://script.google.com/macros/s/AKfycbwmGmcshrvrCsfmqXmj1qlyERulh0CtawveADAMK8rwR4g-Oa5h4NMEo73EiSrIiNcK/exec"

    // Cấu hình Google Drive OAuth 2.0 cho Xưởng Cán
    var driveKey: String = ""
    var driveFolderId: String = ""
    var driveScriptUrl: String = ""
    var driveClientId: String = HangSoDriveMacDinh.clientId
    var driveClientSecret: String = HangSoDriveMacDinh.clientSecret
    var driveRefreshToken: String = HangSoDriveMacDinh.refreshToken

    init() {}

    enum CodingKeys: String, CodingKey {
        case giaoDienToi, trangThaiTab, ngayBatDauChuKy, daChonNgayBatDau, chuKyLamViec
        case batThongBao, gioCaNgay, gioCaDem, gioNgayNghi, gioBinhThuong
        case batThongBaoThucDon, gioThongBaoThucDonNgay, gioThongBaoThucDonDem
        case geminiApiKey, sheetWebhookUrl
        case driveKey, driveFolderId, driveScriptUrl, driveClientId, driveClientSecret, driveRefreshToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.giaoDienToi = (try? c.decodeIfPresent(Bool.self, forKey: .giaoDienToi)) ?? false
        self.trangThaiTab = (try? c.decodeIfPresent(TrangThaiTab.self, forKey: .trangThaiTab)) ?? TrangThaiTab()
        self.ngayBatDauChuKy = (try? c.decodeIfPresent(Date.self, forKey: .ngayBatDauChuKy)) ?? Date()
        self.daChonNgayBatDau = (try? c.decodeIfPresent(Bool.self, forKey: .daChonNgayBatDau)) ?? true
        self.chuKyLamViec = (try? c.decodeIfPresent([String].self, forKey: .chuKyLamViec)) ?? ["ngay", "dem", "nghi"]
        self.batThongBao = (try? c.decodeIfPresent(Bool.self, forKey: .batThongBao)) ?? false
        self.gioCaNgay = (try? c.decodeIfPresent(Date.self, forKey: .gioCaNgay)) ?? TienIchLich.taoGio(gio: 6, phut: 0)
        self.gioCaDem = (try? c.decodeIfPresent(Date.self, forKey: .gioCaDem)) ?? TienIchLich.taoGio(gio: 18, phut: 0)
        self.gioNgayNghi = (try? c.decodeIfPresent(Date.self, forKey: .gioNgayNghi)) ?? TienIchLich.taoGio(gio: 8, phut: 0)
        self.gioBinhThuong = (try? c.decodeIfPresent(Date.self, forKey: .gioBinhThuong)) ?? TienIchLich.taoGio(gio: 7, phut: 0)
        self.batThongBaoThucDon = (try? c.decodeIfPresent(Bool.self, forKey: .batThongBaoThucDon)) ?? true
        self.gioThongBaoThucDonNgay = (try? c.decodeIfPresent(Date.self, forKey: .gioThongBaoThucDonNgay)) ?? TienIchLich.taoGio(gio: 6, phut: 30)
        self.gioThongBaoThucDonDem = (try? c.decodeIfPresent(Date.self, forKey: .gioThongBaoThucDonDem)) ?? TienIchLich.taoGio(gio: 17, phut: 30)
        self.geminiApiKey = (try? c.decodeIfPresent(String.self, forKey: .geminiApiKey)) ?? ""
        self.sheetWebhookUrl = (try? c.decodeIfPresent(String.self, forKey: .sheetWebhookUrl)) ?? "https://script.google.com/macros/s/AKfycbwmGmcshrvrCsfmqXmj1qlyERulh0CtawveADAMK8rwR4g-Oa5h4NMEo73EiSrIiNcK/exec"
        self.driveKey = (try? c.decodeIfPresent(String.self, forKey: .driveKey)) ?? ""
        self.driveFolderId = (try? c.decodeIfPresent(String.self, forKey: .driveFolderId)) ?? ""
        self.driveScriptUrl = (try? c.decodeIfPresent(String.self, forKey: .driveScriptUrl)) ?? ""
        self.driveClientId = (try? c.decodeIfPresent(String.self, forKey: .driveClientId)) ?? HangSoDriveMacDinh.clientId
        self.driveClientSecret = (try? c.decodeIfPresent(String.self, forKey: .driveClientSecret)) ?? HangSoDriveMacDinh.clientSecret
        self.driveRefreshToken = (try? c.decodeIfPresent(String.self, forKey: .driveRefreshToken)) ?? HangSoDriveMacDinh.refreshToken
    }

    mutating func chuanHoaKeyDrive() {
        let ud = UserDefaults.standard
        if driveClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveClientId = ud.string(forKey: "DRIVE_OAUTH_CLIENT_ID") ?? HangSoDriveMacDinh.clientId
        }
        if driveClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveClientId = HangSoDriveMacDinh.clientId
        }

        if driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveClientSecret = ud.string(forKey: "DRIVE_OAUTH_CLIENT_SECRET") ?? HangSoDriveMacDinh.clientSecret
        }
        if driveClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveClientSecret = HangSoDriveMacDinh.clientSecret
        }

        if driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveRefreshToken = ud.string(forKey: "DRIVE_OAUTH_REFRESH_TOKEN") ?? HangSoDriveMacDinh.refreshToken
        }
        if driveRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            driveRefreshToken = HangSoDriveMacDinh.refreshToken
        }

        // Nếu driveFolderId chứa khoảng trắng (như "Anh app ghi chu" là tên thư mục chứ không phải ID), tự động xóa để tránh lỗi 404 File not found
        let fId = driveFolderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if fId.contains(" ") {
            driveFolderId = ""
        } else {
            driveFolderId = fId
        }
        driveScriptUrl = ""
    }
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
    static let thucDonCapNhat = Notification.Name("ThucDonCapNhat")
    static let trangThaiDongBoThayDoi = Notification.Name("TrangThaiDongBoThayDoi")
}

// MARK: - 5. Kho Lưu Trữ Cục Bộ & Tự Động Di Chuyển Dữ Liệu Cũ

final class ThuMucDuLieu {
    static let dungChung = ThuMucDuLieu()

    let thuMuc: URL
    let thuMucAnhCache: URL
    let tepLich: URL
    let tepGhiChuNhanh: URL
    let tepNhacNho: URL
    let tepCaiDat: URL
    let tepXuongCan: URL
    let tepThucDon: URL

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
        tepThucDon = thuMuc.appendingPathComponent("thuc-don.json")

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
    private(set) var duLieuThucDon: DuLieuThucDon = DuLieuThucDon.duLieuMauThang11()
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
        if var d = tm.doc(CaiDatUngDung.self, tu: tm.tepCaiDat) {
            d.chuanHoaKeyDrive()
            caiDat = d
            tm.ghi(caiDat, vao: tm.tepCaiDat)
        } else {
            caiDat.chuanHoaKeyDrive()
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
                tenBang: "Bảng Cán",
                moTa: "",
                cot: [cot1, cot2, cot3, cot4],
                dong: [dongMau]
            )
            danhSachBangXuongCan = [bangMau]
            tm.ghi(danhSachBangXuongCan, vao: tm.tepXuongCan)
        }

        if let td = tm.doc(DuLieuThucDon.self, tu: tm.tepThucDon),
           !(td.tenTepNguon == "thuc_don_kip_A_thang_11_2026.xlsx" && td.danhSachNgay.allSatisfy({ $0.td2MonChinh.isEmpty })) {
            duLieuThucDon = td
        } else {
            duLieuThucDon = DuLieuThucDon.duLieuMauThang11()
            tm.ghi(duLieuThucDon, vao: tm.tepThucDon)
        }
    }

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
                luuGhiChuNhanh(list, dongBoSupabase: false)
            }

            if ghiChuLich.isEmpty,
               let rawCal = manifest["CALENDAR_NOTES"] as? String,
               let dCal = rawCal.data(using: .utf8),
               let dict = ThuMucDuLieu.dungChung.giaiMaDuLieu([String: GhiChuNgay].self, tu: dCal),
               !dict.isEmpty {
                luuGhiChuLich(dict, dongBoSupabase: false)
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

    func luuGhiChuLich(_ moi: [String: GhiChuNgay], dongBoSupabase: Bool = true) {
        ghiChuLich = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepLich)
        if dongBoSupabase {
            DichVuSupabase.dungChung.dongBoDuLieuTuDong()
        }
    }

    func sapXepGhiChuNhanh(_ ds: [GhiChuNhanh]) -> [GhiChuNhanh] {
        ds.sorted { a, b in
            if a.isPinned && !b.isPinned { return true }
            if !a.isPinned && b.isPinned { return false }
            return false
        }
    }

    func luuGhiChuNhanh(_ moi: [GhiChuNhanh], dongBoSupabase: Bool = true) {
        let daSapXep = sapXepGhiChuNhanh(moi)
        ghiChuNhanh = daSapXep
        ThuMucDuLieu.dungChung.ghi(daSapXep, vao: ThuMucDuLieu.dungChung.tepGhiChuNhanh)
        if dongBoSupabase {
            DichVuSupabase.dungChung.dongBoDuLieuTuDong()
        }
    }

    func luuNhacNho(_ moi: [SuKienNhacNho]) {
        nhacNho = moi
        ThuMucDuLieu.dungChung.ghi(moi, vao: ThuMucDuLieu.dungChung.tepNhacNho)
    }

    func luuDuLieuThucDon(_ moi: DuLieuThucDon, dongBoSupabase: Bool = true) {
        var banLuu = moi
        banLuu.danhSachNgay.sort {
            if /usr/bin/bash.khoaNgay != $1.khoaNgay {
                return /usr/bin/bash.khoaNgay < $1.khoaNgay
            }
            return /usr/bin/bash.ngayVaoCa < $1.ngayVaoCa
        }
        duLieuThucDon = banLuu
        ThuMucDuLieu.dungChung.ghi(banLuu, vao: ThuMucDuLieu.dungChung.tepThucDon)
        TienIchLich.capNhatTatCaThongBaoThucDon()
        NotificationCenter.default.post(name: .thucDonCapNhat, object: nil)
        if dongBoSupabase {
            DichVuSupabase.dungChung.dongBoDuLieuTuDong()
        }
    }

    func luuCaiDat(_ moi: CaiDatUngDung, thongBao: Bool = true) {
        var banChuan = moi
        banChuan.chuanHoaKeyDrive()
        caiDat = banChuan

        let ud = UserDefaults.standard
        ud.setValue(banChuan.driveClientId, forKey: "DRIVE_OAUTH_CLIENT_ID")
        ud.setValue(banChuan.driveClientSecret, forKey: "DRIVE_OAUTH_CLIENT_SECRET")
        ud.setValue(banChuan.driveRefreshToken, forKey: "DRIVE_OAUTH_REFRESH_TOKEN")
        ud.setValue(banChuan.driveFolderId, forKey: "DRIVE_OAUTH_FOLDER_ID")

        ThuMucDuLieu.dungChung.ghi(banChuan, vao: ThuMucDuLieu.dungChung.tepCaiDat)
        TienIchLich.capNhatTatCaThongBaoLich()
        TienIchLich.capNhatTatCaThongBaoThucDon()
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
        if let idx = ds.firstIndex(where: { /usr/bin/bash.id == bang.id }) {
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

    static func docNgayThucDon(_ chuoi: String) -> Date? {
        let raw = chuoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        // Kiểm tra nếu là số serial ngày của Excel (VD: 46334 -> 08/11/2026)
        if let serialDouble = Double(raw), serialDouble >= 35000 && serialDouble <= 70000 {
            let soNgay = Int(serialDouble.rounded(.down))
            var comp = DateComponents()
            comp.year = 1899
            comp.month = 12
            comp.day = 30
            if let mocExcel = lich.date(from: comp),
               let ngay = lich.date(byAdding: .day, value: soNgay, to: mocExcel) {
                return ngay
            }
        }

        let cacDinhDang = ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy", "yyyy-MM-dd", "dd/MM/yy", "d/M/yy"]
        let df = DateFormatter()
        df.calendar = lich
        df.locale = Locale(identifier: "vi_VN")

        for fmt in cacDinhDang {
            df.dateFormat = fmt
            if let d = df.date(from: raw) {
                return d
            }
        }

        if let regex = try? NSRegularExpression(pattern: "\\b(\\d{1,2})[/-](\\d{1,2})[/-](\\d{2,4})\\b"),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let r0 = Range(match.range, in: raw) {
            let trichXuat = String(raw[r0])
            for fmt in ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy", "dd/MM/yy", "d/M/yy"] {
                df.dateFormat = fmt
                if let d = df.date(from: trichXuat) {
                    return d
                }
            }
        }
        return nil
    }

    static func chuanHoaNgayThucDon(_ chuoi: String) -> (hienThi: String, khoa: String)? {
        guard let d = docNgayThucDon(chuoi) else { return nil }
        return (dinhDangNgayViet.string(from: d), dinhDangKhoaNgay.string(from: d))
    }

    static func thuVietNam(_ ngay: Date) -> String {
        let wd = lich.component(.weekday, from: ngay)
        switch wd {
        case 1: return "Chủ Nhật"
        case 2: return "Thứ Hai"
        case 3: return "Thứ Ba"
        case 4: return "Thứ Tư"
        case 5: return "Thứ Năm"
        case 6: return "Thứ Sáu"
        case 7: return "Thứ Bảy"
        default: return ""
        }
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
        let id = "LICH_\(dinhDangKhoaNgay.string(from: ngay))"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
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
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: noiDung, trigger: trigger))
    }

    static func capNhatTatCaThongBaoLich() {
        let trungTam = UNUserNotificationCenter.current()
        trungTam.getPendingNotificationRequests { ds in
            let cacIdLich = ds.map(\.identifier).filter { /usr/bin/bash.hasPrefix("LICH_") }
            if !cacIdLich.isEmpty {
                trungTam.removePendingNotificationRequests(withIdentifiers: cacIdLich)
            }
            let cd = KhoDuLieu.dungChung.caiDat
            guard cd.batThongBao else { return }
            let tatCa = KhoDuLieu.dungChung.ghiChuLich
            for (khoa, gc) in tatCa where !gc.noteLines.isEmpty {
                guard let ngay = dinhDangKhoaNgay.date(from: khoa) else { continue }
                let loaiCa = gc.type.isEmpty ? (tinhCaTuDong(cho: ngay) ?? "") : gc.type
                datThongBaoLich(ngay: ngay, dongGhiChu: gc.noteLines, loaiCa: loaiCa)
            }
        }
    }

    static func capNhatTatCaThongBaoThucDon(hoanThanh: ((Int) -> Void)? = nil) {
        let trungTam = UNUserNotificationCenter.current()
        let cd = KhoDuLieu.dungChung.caiDat
        let danhSach = KhoDuLieu.dungChung.duLieuThucDon.danhSachNgay

        trungTam.getPendingNotificationRequests { dsHienTai in
            let cacIdThucDon = dsHienTai.map(\.identifier).filter { /usr/bin/bash.hasPrefix("THUCDON_") }
            if !cacIdThucDon.isEmpty {
                trungTam.removePendingNotificationRequests(withIdentifiers: cacIdThucDon)
            }

            guard cd.batThongBaoThucDon, !danhSach.isEmpty else {
                DispatchQueue.main.async { hoanThanh?(0) }
                return
            }

            let tpGioNgay = lich.dateComponents([.hour, .minute], from: cd.gioThongBaoThucDonNgay)
            let tpGioDem = lich.dateComponents([.hour, .minute], from: cd.gioThongBaoThucDonDem)
            let bayGio = Date()

            var cacYeuCauSapToi: [(thoiDiem: Date, req: UNNotificationRequest)] = []

            for muc in danhSach {
                guard let ngay = docNgayThucDon(muc.ngayVaoCa) ?? docNgayISO(muc.khoaNgay) else { continue }
                let laDem = muc.laCaDem
                let gio = laDem ? (tpGioDem.hour ?? 17) : (tpGioNgay.hour ?? 6)
                let phut = laDem ? (tpGioDem.minute ?? 30) : (tpGioNgay.minute ?? 30)

                guard let thoiDiem = lich.date(bySettingHour: gio, minute: phut, second: 0, of: ngay),
                      thoiDiem > bayGio else { continue }

                let noiDung = UNMutableNotificationContent()
                let tenCa = laDem ? "Ca Đêm 🌙" : "Ca Ngày ☀️"
                noiDung.title = "🍱 Thực đơn \(tenCa) (\(muc.ngayVaoCa))"
                noiDung.body = muc.tomTatThongBao
                noiDung.sound = .default

                let tpTrigger = lich.dateComponents([.year, .month, .day, .hour, .minute], from: thoiDiem)
                let trigger = UNCalendarNotificationTrigger(dateMatching: tpTrigger, repeats: false)
                let khoa = muc.khoaNgay.isEmpty ? dinhDangKhoaNgay.string(from: ngay) : muc.khoaNgay
                let id = "THUCDON_\(khoa)_\(muc.caChuan)"
                let req = UNNotificationRequest(identifier: id, content: noiDung, trigger: trigger)
                cacYeuCauSapToi.append((thoiDiem, req))
            }

            cacYeuCauSapToi.sort { /usr/bin/bash.thoiDiem < $1.thoiDiem }
            let gioiHan = Array(cacYeuCauSapToi.prefix(45))
            for item in gioiHan {
                trungTam.add(item.req)
            }
            DispatchQueue.main.async {
                hoanThanh?(gioiHan.count)
            }
        }
    }

    static func guiThongBaoThuThucDon(muc: MucThucDonNgay?) {
        xinQuyenThongBao()
        let noiDung = UNMutableNotificationContent()
        if let muc {
            let tenCa = muc.laCaDem ? "Ca Đêm 🌙" : "Ca Ngày ☀️"
            noiDung.title = "🍱 Thực đơn \(tenCa) (\(muc.ngayVaoCa))"
            noiDung.body = muc.tomTatThongBao
        } else {
            noiDung.title = "🍱 Thông báo Thực đơn"
            noiDung.body = "Thông báo thực đơn đã hoạt động! Bạn sẽ nhận được thực đơn đúng giờ cài đặt."
        }
        noiDung.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let req = UNNotificationRequest(identifier: "THUCDON_TEST_\(UUID().uuidString)", content: noiDung, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
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
