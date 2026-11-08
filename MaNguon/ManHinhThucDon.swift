import UIKit
import UniformTypeIdentifiers
import Compression
import PDFKit

// MARK: - 1. Bộ Giải Nén ZIP & Đọc File Excel (.xlsx) / CSV / TSV / TXT Thuần Swift

enum LoiDocThucDon: LocalizedError {
    case khongDocDuocDuLieu
    case dinhDangKhongHopLe(String)
    case khongTimThayDongThucDon

    var errorDescription: String? {
        switch self {
        case .khongDocDuocDuLieu:
            return "Không thể đọc dữ liệu từ file đã chọn. Hãy kiểm tra quyền truy cập file."
        case .dinhDangKhongHopLe(let chiTiet):
            return "Định dạng file không hợp lệ: \(chiTiet)"
        case .khongTimThayDongThucDon:
            return "Không tìm thấy dữ liệu thực đơn hợp lệ trong file (cần có cột Ngày vào ca, Ca, các món ăn...)."
        }
    }
}

final class BoDocTapTinThucDon {

    static func docTuURL(_ url: URL, locTheoChuKyCaiDat: Bool = false) throws -> DuLieuThucDon {
        let coQuyen = url.startAccessingSecurityScopedResource()
        defer {
            if coQuyen { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw LoiDocThucDon.khongDocDuocDuLieu
        }

        let tenTep = url.lastPathComponent
        let duoi = url.pathExtension.lowercased()

        // Kiểm tra chữ ký ZIP (PK\x03\x04) cho file .xlsx
        let laZip = data.count >= 4 &&
            data[data.startIndex] == 0x50 &&
            data[data.startIndex + 1] == 0x4B &&
            data[data.startIndex + 2] == 0x03 &&
            data[data.startIndex + 3] == 0x04

        if laZip || duoi == "xlsx" {
            return try docTuDataXLSX(data, tenTep: tenTep, locTheoChuKyCaiDat: locTheoChuKyCaiDat)
        } else if duoi == "pdf", let pdf = PDFDocument(data: data) {
            var vanBan = ""
            for i in 0..<pdf.pageCount {
                if let trang = pdf.page(at: i)?.string {
                    vanBan += trang + "\n"
                }
            }
            return try docTuChuoiCSV(vanBan, tenTep: tenTep, locTheoChuKyCaiDat: locTheoChuKyCaiDat)
        } else {
            // Thử đọc dạng JSON nếu người dùng nhập file backup .json
            if let td = ThuMucDuLieu.dungChung.giaiMaDuLieu(DuLieuThucDon.self, tu: data),
               !td.danhSachNgay.isEmpty {
                return td
            }
            let chuoi = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .windowsCP1252)
                ?? String(decoding: data, as: UTF8.self)
            return try docTuChuoiCSV(chuoi, tenTep: tenTep, locTheoChuKyCaiDat: locTheoChuKyCaiDat)
        }
    }

    // MARK: - Đọc XLSX (ZIP + XML)

    private static func docTuDataXLSX(_ data: Data, tenTep: String, locTheoChuKyCaiDat: Bool) throws -> DuLieuThucDon {
        let cacTepZip = giaiNenZip(data)
        guard !cacTepZip.isEmpty else {
            throw LoiDocThucDon.dinhDangKhongHopLe("Không thể giải nén cấu trúc Excel (.xlsx).")
        }

        // 1. Đọc bảng chuỗi dùng chung (xl/sharedStrings.xml)
        var sharedStrings: [String] = []
        if let sstData = cacTepZip["xl/sharedStrings.xml"] {
            sharedStrings = BoPhanTichSharedStrings().phanTich(data: sstData)
        }

        // 2. Đọc danh sách tên sheet từ xl/workbook.xml và đường dẫn từ xl/_rels/workbook.xml.rels
        let danhSachSheet = BoPhanTichWorkbook().phanTich(
            workbookData: cacTepZip["xl/workbook.xml"],
            relsData: cacTepZip["xl/_rels/workbook.xml.rels"],
            tatCaKhoa: Array(cacTepZip.keys)
        )

        var cacBangTheoSheet: [(tenSheet: String, bang: [[String]])] = []
        for thongTin in danhSachSheet {
            if let xmlData = cacTepZip[thongTin.duongDan] {
                let bang = BoPhanTichWorksheet(sharedStrings: sharedStrings).phanTich(data: xmlData)
                if !bang.isEmpty {
                    cacBangTheoSheet.append((thongTin.ten, bang))
                }
            }
        }

        if cacBangTheoSheet.isEmpty {
            // Fallback quét mọi xl/worksheets/sheet*.xml
            let cacKhoaSheet = cacTepZip.keys.filter { $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml") }.sorted()
            for (idx, khoa) in cacKhoaSheet.enumerated() {
                if let xmlData = cacTepZip[khoa] {
                    let bang = BoPhanTichWorksheet(sharedStrings: sharedStrings).phanTich(data: xmlData)
                    if !bang.isEmpty {
                        cacBangTheoSheet.append(("Sheet \(idx + 1)", bang))
                    }
                }
            }
        }

        guard !cacBangTheoSheet.isEmpty else {
            throw LoiDocThucDon.khongTimThayDongThucDon
        }

        return try trichXuatDuLieuThucDon(tu: cacBangTheoSheet, tenTep: tenTep, locTheoChuKyCaiDat: locTheoChuKyCaiDat)
    }

    // MARK: - Đọc CSV / TSV / Văn bản

    private static func docTuChuoiCSV(_ chuoi: String, tenTep: String, locTheoChuKyCaiDat: Bool) throws -> DuLieuThucDon {
        let bang = phanTichCSV(chuoi)
        guard !bang.isEmpty else {
            throw LoiDocThucDon.khongTimThayDongThucDon
        }
        return try trichXuatDuLieuThucDon(tu: [(" Thực đơn", bang)], tenTep: tenTep, locTheoChuKyCaiDat: locTheoChuKyCaiDat)
    }

    // MARK: - Trích xuất & Lọc Thực Đơn từ các Bảng

    static func trichXuatDuLieuThucDon(
        tu cacSheet: [(tenSheet: String, bang: [[String]])],
        tenTep: String,
        locTheoChuKyCaiDat: Bool
    ) throws -> DuLieuThucDon {
        var danhSachNgay: [MucThucDonNgay] = []
        var quyTacLoc: [QuyTacThucDon] = []
        var tenSheetChinh = cacSheet.first?.tenSheet.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Thực đơn"

        for (tenSheet, bang) in cacSheet {
            let tenSheetThuong = boDau(tenSheet).lowercased()

            // Kiểm tra xem sheet này có phải là sheet "Quy tắc lọc" riêng biệt không
            if tenSheetThuong.contains("quy tac") || (bang.first?.count == 2 && boDau(bang.first?.first ?? "").lowercased().contains("noi dung")) {
                for dong in bang.dropFirst() {
                    let c0 = dong.indices.contains(0) ? dong[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    let c1 = dong.indices.contains(1) ? dong[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    if !c0.isEmpty && !c1.isEmpty {
                        quyTacLoc.append(QuyTacThucDon(noiDung: c0, quyTac: c1))
                    }
                }
                continue
            }

            // Tìm dòng tiêu đề trong bảng thực đơn
            var chiSoTieuDe = 0
            var anhXaCot = AnhXaCotThucDon()
            for (idx, dong) in bang.prefix(10).enumerated() {
                let ghep = boDau(dong.joined(separator: " ")).lowercased()
                if ghep.contains("ngay vao ca") || (ghep.contains("ngay") && (ghep.contains("trua") || ghep.contains("chieu") || ghep.contains("an dem") || ghep.contains("cai thien"))) {
                    chiSoTieuDe = idx
                    anhXaCot = AnhXaCotThucDon(dongTieuDe: dong)
                    tenSheetChinh = tenSheet.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }

            var dangDocQuyTacCuoiBang = false
            for idx in (chiSoTieuDe + 1)..<bang.count {
                let dong = bang[idx]
                let c0 = dong.indices.contains(0) ? dong[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let c1 = dong.indices.contains(1) ? dong[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""

                if boDau(c0).lowercased() == "noi dung" && boDau(c1).lowercased().contains("quy tac") {
                    dangDocQuyTacCuoiBang = true
                    continue
                }

                if dangDocQuyTacCuoiBang {
                    if !c0.isEmpty && !c1.isEmpty {
                        quyTacLoc.append(QuyTacThucDon(noiDung: c0, quyTac: c1))
                    }
                    continue
                }

                let chuoiNgay = layGiaTri(dong, anhXaCot.ngayVaoCa)
                guard !chuoiNgay.isEmpty else { continue }

                // Kiểm tra xem cột đầu có phải là một ngày hợp lệ không
                guard let ngayChuan = TienIchLich.chuanHoaNgayThucDon(chuoiNgay) else {
                    // Nếu dòng có đúng 2 cột thông tin ở cuối bảng (như Chu kỳ kíp A, Ca ngày, Ca đêm, Nguồn)
                    let cacO = dong.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    if cacO.count == 2 && !c0.isEmpty && !c1.isEmpty {
                        quyTacLoc.append(QuyTacThucDon(noiDung: c0, quyTac: c1))
                    }
                    continue
                }

                let caGoc = layGiaTri(dong, anhXaCot.ca)
                let truaCT = layGiaTri(dong, anhXaCot.truaCaiThien)
                let truaMC = layGiaTri(dong, anhXaCot.truaMonChinh)
                let truaM2 = layGiaTri(dong, anhXaCot.truaMonThuHai)
                let chieu = layGiaTri(dong, anhXaCot.chieuToi)
                let dem = layGiaTri(dong, anhXaCot.anDem)
                let sang = layGiaTri(dong, anhXaCot.sangHomSau)
                let ghiChu = layGiaTri(dong, anhXaCot.ghiChu)

                let tatCaRong = [truaCT, truaMC, truaM2, chieu, dem, sang, ghiChu].allSatisfy { $0.isEmpty }
                if tatCaRong && caGoc.isEmpty { continue }

                // Chuẩn hóa tên Ca ("Ngày" / "Đêm")
                let caHienThi: String
                let caKhongDau = boDau(caGoc).lowercased()
                if caKhongDau.contains("dem") || caKhongDau.contains("toi") {
                    caHienThi = "Đêm"
                } else if caKhongDau.contains("ngay") || caKhongDau.contains("sang") {
                    caHienThi = "Ngày"
                } else if caKhongDau.contains("nghi") {
                    caHienThi = "Nghỉ"
                } else if (!dem.isEmpty || !sang.isEmpty) && truaCT.isEmpty && truaMC.isEmpty && chieu.isEmpty {
                    caHienThi = "Đêm"
                } else {
                    caHienThi = caGoc.isEmpty ? "Ngày" : caGoc
                }

                let muc = MucThucDonNgay(
                    ngayVaoCa: ngayChuan.hienThi,
                    khoaNgay: ngayChuan.khoa,
                    ca: caHienThi,
                    truaCaiThien: truaCT,
                    truaMonChinh: truaMC,
                    truaMonThuHai: truaM2,
                    chieuToi: chieu,
                    anDem: dem,
                    sangHomSau: sang,
                    ghiChu: ghiChu
                )
                danhSachNgay.append(muc)
            }
        }

        guard !danhSachNgay.isEmpty else {
            throw LoiDocThucDon.khongTimThayDongThucDon
        }

        if locTheoChuKyCaiDat {
            danhSachNgay = apDungLocTheoChuKyCa(danhSachNgay)
        }

        return DuLieuThucDon(
            tenTepNguon: tenTep,
            tenSheetChinh: tenSheetChinh,
            capNhatLuc: Date(),
            danhSachNgay: danhSachNgay,
            quyTacLoc: quyTacLoc
        )
    }

    /// Áp dụng quy tắc lọc theo Chu kỳ ca làm việc trong Cài đặt (Ca ngày lấy Trưa + Chiều/Tối; Ca đêm lấy Ăn đêm + Sáng hôm sau; Ngày nghỉ bỏ qua)
    static func apDungLocTheoChuKyCa(_ danhSachGoc: [MucThucDonNgay]) -> [MucThucDonNgay] {
        var ketQua: [MucThucDonNgay] = []
        for (idx, muc) in danhSachGoc.enumerated() {
            guard let ngay = TienIchLich.docNgayThucDon(muc.ngayVaoCa) else {
                ketQua.append(muc)
                continue
            }
            let caTuDong = TienIchLich.tinhCaTuDong(cho: ngay) ?? muc.caChuan
            if caTuDong == "nghi" {
                continue
            } else if caTuDong == "ngay" {
                var banSao = muc
                banSao.ca = "Ngày"
                // Nếu dòng gốc có cả món ăn đêm lẫn món trưa, chỉ giữ bữa trưa + chiều/tối cho Ca Ngày
                if !banSao.truaCaiThien.isEmpty || !banSao.truaMonChinh.isEmpty || !banSao.chieuToi.isEmpty {
                    banSao.anDem = ""
                    banSao.sangHomSau = ""
                }
                ketQua.append(banSao)
            } else if caTuDong == "dem" {
                var banSao = muc
                banSao.ca = "Đêm"
                if !banSao.anDem.isEmpty || !banSao.sangHomSau.isEmpty {
                    banSao.truaCaiThien = ""
                    banSao.truaMonChinh = ""
                    banSao.truaMonThuHai = ""
                    banSao.chieuToi = ""
                }
                // Nếu sáng hôm sau đang trống và dòng kế tiếp có thông tin sáng, giữ nguyên hoặc bổ sung
                if banSao.sangHomSau.isEmpty && idx + 1 < danhSachGoc.count {
                    let keTiep = danhSachGoc[idx + 1]
                    if !keTiep.sangHomSau.isEmpty {
                        banSao.sangHomSau = keTiep.sangHomSau
                    }
                }
                ketQua.append(banSao)
            } else {
                ketQua.append(muc)
            }
        }
        return ketQua.isEmpty ? danhSachGoc : ketQua
    }

    private static func layGiaTri(_ dong: [String], _ chiSo: Int?) -> String {
        guard let idx = chiSo, idx >= 0, idx < dong.count else { return "" }
        return dong[idx].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func boDau(_ chuoi: String) -> String {
        chuoi.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }

    // MARK: - Bộ Ánh Xạ Cột Linh Hoạt

    private struct AnhXaCotThucDon {
        var ngayVaoCa: Int? = 0
        var ca: Int? = 1
        var truaCaiThien: Int? = 2
        var truaMonChinh: Int? = 3
        var truaMonThuHai: Int? = 4
        var chieuToi: Int? = 5
        var anDem: Int? = 6
        var sangHomSau: Int? = 7
        var ghiChu: Int? = 8

        init() {}

        init(dongTieuDe: [String]) {
            var timThay = false
            var tNgay: Int?
            var tCa: Int?
            var tCaiThien: Int?
            var tMonChinh: Int?
            var tMon2: Int?
            var tChieu: Int?
            var tDem: Int?
            var tSang: Int?
            var tGhiChu: Int?

            for (idx, tenGoc) in dongTieuDe.enumerated() {
                let ten = BoDocTapTinThucDon.boDau(tenGoc).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !ten.isEmpty else { continue }

                if ten.contains("ngay") && tNgay == nil {
                    tNgay = idx
                    timThay = true
                } else if (ten == "ca" || ten.hasPrefix("ca ") || ten.contains("kip")) && !ten.contains("ca ngay") && !ten.contains("ca dem") && tCa == nil {
                    tCa = idx
                    timThay = true
                } else if (ten.contains("cai thien") || (ten.contains("trua") && tCaiThien == nil && !ten.contains("chinh") && !ten.contains("thu 2"))) && tCaiThien == nil {
                    tCaiThien = idx
                    timThay = true
                } else if ten.contains("mon chinh") || (ten.contains("chinh") && tMonChinh == nil) {
                    tMonChinh = idx
                    timThay = true
                } else if ten.contains("thu 2") || ten.contains("mon phu") || ten.contains("thu hai") {
                    tMon2 = idx
                    timThay = true
                } else if ten.contains("chieu") || ten.contains("toi") {
                    tChieu = idx
                    timThay = true
                } else if ten.contains("an dem") || (ten.contains("dem") && tDem == nil) {
                    tDem = idx
                    timThay = true
                } else if ten.contains("sang hom sau") || ten.contains("an sang") || ten.contains("sang") {
                    tSang = idx
                    timThay = true
                } else if ten.contains("ghi chu") || ten.contains("luu y") {
                    tGhiChu = idx
                    timThay = true
                }
            }

            if timThay {
                self.ngayVaoCa = tNgay ?? 0
                self.ca = tCa ?? 1
                self.truaCaiThien = tCaiThien ?? 2
                self.truaMonChinh = tMonChinh ?? 3
                self.truaMonThuHai = tMon2 ?? 4
                self.chieuToi = tChieu ?? 5
                self.anDem = tDem ?? 6
                self.sangHomSau = tSang ?? 7
                self.ghiChu = tGhiChu ?? 8
            }
        }
    }

    // MARK: - Phân tích CSV Chuẩn RFC-4180

    private static func phanTichCSV(_ noiDung: String) -> [[String]] {
        let chuanHoa = noiDung.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let dongDau = chuanHoa.components(separatedBy: "\n").first ?? ""
        let dauPhay: Character
        if dongDau.components(separatedBy: "\t").count >= 4 {
            dauPhay = "\t"
        } else if dongDau.components(separatedBy: ",").count < 3 && dongDau.components(separatedBy: ";").count >= 4 {
            dauPhay = ";"
        } else {
            dauPhay = ","
        }

        var ketQua: [[String]] = []
        var dongHienTai: [String] = []
        var oHienTai = ""
        var trongNgoacKep = false
        let kyTu = Array(chuanHoa)
        var i = 0

        while i < kyTu.count {
            let c = kyTu[i]
            if trongNgoacKep {
                if c == "\"" {
                    if i + 1 < kyTu.count && kyTu[i + 1] == "\"" {
                        oHienTai.append("\"")
                        i += 2
                        continue
                    } else {
                        trongNgoacKep = false
                    }
                } else {
                    oHienTai.append(c)
                }
            } else {
                if c == "\"" {
                    trongNgoacKep = true
                } else if c == dauPhay {
                    dongHienTai.append(oHienTai)
                    oHienTai = ""
                } else if c == "\n" {
                    dongHienTai.append(oHienTai)
                    if !dongHienTai.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        ketQua.append(dongHienTai)
                    }
                    dongHienTai = []
                    oHienTai = ""
                } else {
                    oHienTai.append(c)
                }
            }
            i += 1
        }

        if !oHienTai.isEmpty || !dongHienTai.isEmpty {
            dongHienTai.append(oHienTai)
            if !dongHienTai.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                ketQua.append(dongHienTai)
            }
        }
        return ketQua
    }

    // MARK: - Giải nén ZIP thuần Swift (Dùng Compression Framework của iOS)

    private static func docUInt16(_ data: Data, tai viTri: Int) -> UInt16 {
        guard viTri >= 0, viTri + 2 <= data.count else { return 0 }
        let b0 = UInt16(data[data.startIndex + viTri])
        let b1 = UInt16(data[data.startIndex + viTri + 1])
        return b0 | (b1 << 8)
    }

    private static func docUInt32(_ data: Data, tai viTri: Int) -> UInt32 {
        guard viTri >= 0, viTri + 4 <= data.count else { return 0 }
        let b0 = UInt32(data[data.startIndex + viTri])
        let b1 = UInt32(data[data.startIndex + viTri + 1])
        let b2 = UInt32(data[data.startIndex + viTri + 2])
        let b3 = UInt32(data[data.startIndex + viTri + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    private static func giaiNenDeflate(_ duLieuNen: Data, kichThuocGoc: Int) -> Data? {
        guard !duLieuNen.isEmpty else { return Data() }
        let dungLuong = max(kichThuocGoc + 1024, duLieuNen.count * 6, 65536)
        let boDemDich = UnsafeMutablePointer<UInt8>.allocate(capacity: dungLuong)
        defer { boDemDich.deallocate() }

        let soByteGiaiNen = duLieuNen.withUnsafeBytes { ptrNguon -> Int in
            guard let base = ptrNguon.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                boDemDich,
                dungLuong,
                base,
                duLieuNen.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        guard soByteGiaiNen > 0 else { return nil }
        return Data(bytes: boDemDich, count: soByteGiaiNen)
    }

    private static func giaiNenZip(_ data: Data) -> [String: Data] {
        var ketQua: [String: Data] = [:]
        guard data.count >= 22 else { return ketQua }

        // 1. Tìm End of Central Directory (0x06054b50) từ cuối file
        var viTriEOCD: Int?
        let gioiHanTim = max(0, data.count - 65558)
        for pos in stride(from: data.count - 22, through: gioiHanTim, by: -1) {
            if docUInt32(data, tai: pos) == 0x06054b50 {
                viTriEOCD = pos
                break
            }
        }

        if let eocd = viTriEOCD {
            let soMuc = Int(docUInt16(data, tai: eocd + 10))
            let cdOffset = Int(docUInt32(data, tai: eocd + 16))
            var pos = cdOffset

            for _ in 0..<soMuc {
                guard pos + 46 <= data.count, docUInt32(data, tai: pos) == 0x02014b50 else { break }
                let phuongThuc = docUInt16(data, tai: pos + 10)
                let kichThuocNen = Int(docUInt32(data, tai: pos + 20))
                let kichThuocGoc = Int(docUInt32(data, tai: pos + 24))
                let doDaiTen = Int(docUInt16(data, tai: pos + 28))
                let doDaiExtra = Int(docUInt16(data, tai: pos + 30))
                let doDaiComment = Int(docUInt16(data, tai: pos + 32))
                let localOffset = Int(docUInt32(data, tai: pos + 42))

                let tenBatDau = pos + 46
                let tenKetThuc = tenBatDau + doDaiTen
                guard tenKetThuc <= data.count else { break }
                let tenTep = String(data: data.subdata(in: tenBatDau..<tenKetThuc), encoding: .utf8) ?? ""

                if localOffset + 30 <= data.count, docUInt32(data, tai: localOffset) == 0x04034b50 {
                    let localTenLen = Int(docUInt16(data, tai: localOffset + 26))
                    let localExtraLen = Int(docUInt16(data, tai: localOffset + 28))
                    let batDauDuLieu = localOffset + 30 + localTenLen + localExtraLen
                    let ketThucDuLieu = batDauDuLieu + kichThuocNen

                    if ketThucDuLieu <= data.count && !tenTep.isEmpty {
                        let duLieuNen = data.subdata(in: batDauDuLieu..<ketThucDuLieu)
                        if phuongThuc == 0 {
                            ketQua[tenTep] = duLieuNen
                        } else if phuongThuc == 8, let giaiNen = giaiNenDeflate(duLieuNen, kichThuocGoc: kichThuocGoc) {
                            ketQua[tenTep] = giaiNen
                        }
                    }
                }
                pos = tenKetThuc + doDaiExtra + doDaiComment
            }
        }

        // 2. Fallback quét tuần tự Local File Header nếu không tìm thấy EOCD
        if ketQua.isEmpty {
            var pos = 0
            while pos + 30 <= data.count {
                guard docUInt32(data, tai: pos) == 0x04034b50 else { break }
                let phuongThuc = docUInt16(data, tai: pos + 8)
                let kichThuocNen = Int(docUInt32(data, tai: pos + 18))
                let kichThuocGoc = Int(docUInt32(data, tai: pos + 22))
                let doDaiTen = Int(docUInt16(data, tai: pos + 26))
                let doDaiExtra = Int(docUInt16(data, tai: pos + 28))

                let tenBatDau = pos + 30
                let tenKetThuc = tenBatDau + doDaiTen
                let batDauDuLieu = tenKetThuc + doDaiExtra
                let ketThucDuLieu = batDauDuLieu + kichThuocNen
                guard ketThucDuLieu <= data.count else { break }

                let tenTep = String(data: data.subdata(in: tenBatDau..<tenKetThuc), encoding: .utf8) ?? ""
                let duLieuNen = data.subdata(in: batDauDuLieu..<ketThucDuLieu)
                if phuongThuc == 0 {
                    ketQua[tenTep] = duLieuNen
                } else if phuongThuc == 8, let giaiNen = giaiNenDeflate(duLieuNen, kichThuocGoc: kichThuocGoc) {
                    ketQua[tenTep] = giaiNen
                }
                pos = ketThucDuLieu
            }
        }
        return ketQua
    }
}

// MARK: - 2. Các Bộ Phân Tích XML Cho File XLSX

private final class BoPhanTichSharedStrings: NSObject, XMLParserDelegate {
    private var danhSach: [String] = []
    private var chuoiHienTai = ""
    private var dangTrongSI = false
    private var dangTrongT = false
    private var dangTrongRPh = false

    func phanTich(data: Data) -> [String] {
        danhSach = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return danhSach
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let ten = elementName.components(separatedBy: ":").last ?? elementName
        if ten == "si" {
            dangTrongSI = true
            chuoiHienTai = ""
        } else if ten == "rPh" {
            dangTrongRPh = true
        } else if ten == "t" && dangTrongSI && !dangTrongRPh {
            dangTrongT = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if dangTrongT {
            chuoiHienTai += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let ten = elementName.components(separatedBy: ":").last ?? elementName
        if ten == "t" {
            dangTrongT = false
        } else if ten == "rPh" {
            dangTrongRPh = false
        } else if ten == "si" {
            dangTrongSI = false
            danhSach.append(chuoiHienTai)
        }
    }
}

private final class BoPhanTichWorkbook: NSObject, XMLParserDelegate {
    private var cacSheet: [(ten: String, rId: String)] = []
    private var anhXaRels: [String: String] = [:]
    private var dangDocRels = false

    func phanTich(workbookData: Data?, relsData: Data?, tatCaKhoa: [String]) -> [(ten: String, duongDan: String)] {
        if let relsData {
            dangDocRels = true
            let pRels = XMLParser(data: relsData)
            pRels.delegate = self
            pRels.parse()
        }
        if let workbookData {
            dangDocRels = false
            let pWb = XMLParser(data: workbookData)
            pWb.delegate = self
            pWb.parse()
        }

        var ketQua: [(ten: String, duongDan: String)] = []
        for (idx, sh) in cacSheet.enumerated() {
            if let target = anhXaRels[sh.rId] {
                let chuan = target.hasPrefix("xl/") ? target : (target.hasPrefix("/") ? String(target.dropFirst()) : "xl/\(target)")
                if tatCaKhoa.contains(chuan) {
                    ketQua.append((sh.ten, chuan))
                    continue
                }
            }
            let macDinh = "xl/worksheets/sheet\(idx + 1).xml"
            if tatCaKhoa.contains(macDinh) {
                ketQua.append((sh.ten, macDinh))
            }
        }
        return ketQua
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let ten = elementName.components(separatedBy: ":").last ?? elementName
        if dangDocRels {
            if ten == "Relationship",
               let id = attributeDict["Id"],
               let target = attributeDict["Target"] {
                anhXaRels[id] = target
            }
        } else {
            if ten == "sheet",
               let name = attributeDict["name"] {
                let rId = attributeDict["r:id"] ?? attributeDict["id"] ?? ""
                cacSheet.append((name, rId))
            }
        }
    }
}

private final class BoPhanTichWorksheet: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var bang: [[String]] = []
    private var dongHienTai: [Int: String] = [:]
    private var cotToiDaTrongDong: Int = -1
    private var chiSoCotHienTai: Int = 0
    private var loaiOHienTai: String = ""
    private var giaTriHienTai: String = ""
    private var dangDocGiaTri = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func phanTich(data: Data) -> [[String]] {
        bang = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return bang
    }

    private func chiSoCotTuThamChieu(_ ref: String) -> Int? {
        var ketQua = 0
        var coChuCai = false
        for ch in ref.uppercased() {
            if ch >= "A" && ch <= "Z" {
                coChuCai = true
                let val = Int(ch.asciiValue! - Character("A").asciiValue! + 1)
                ketQua = ketQua * 26 + val
            } else {
                break
            }
        }
        return coChuCai ? (ketQua - 1) : nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let ten = elementName.components(separatedBy: ":").last ?? elementName
        if ten == "row" {
            dongHienTai = [:]
            cotToiDaTrongDong = -1
            chiSoCotHienTai = 0
        } else if ten == "c" {
            if let ref = attributeDict["r"], let idx = chiSoCotTuThamChieu(ref) {
                chiSoCotHienTai = idx
            }
            loaiOHienTai = attributeDict["t"] ?? ""
            giaTriHienTai = ""
        } else if ten == "v" || ten == "t" {
            dangDocGiaTri = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if dangDocGiaTri {
            giaTriHienTai += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let ten = elementName.components(separatedBy: ":").last ?? elementName
        if ten == "v" || ten == "t" {
            dangDocGiaTri = false
        } else if ten == "c" {
            let chuoiKetQua: String
            if loaiOHienTai == "s", let idx = Int(giaTriHienTai.trimmingCharacters(in: .whitespacesAndNewlines)),
               idx >= 0 && idx < sharedStrings.count {
                chuoiKetQua = sharedStrings[idx]
            } else {
                chuoiKetQua = giaTriHienTai
            }
            dongHienTai[chiSoCotHienTai] = chuoiKetQua
            if chiSoCotHienTai > cotToiDaTrongDong {
                cotToiDaTrongDong = chiSoCotHienTai
            }
            chiSoCotHienTai += 1
        } else if ten == "row" {
            if cotToiDaTrongDong >= 0 {
                var mangDong: [String] = []
                for c in 0...min(cotToiDaTrongDong, 25) {
                    mangDong.append(dongHienTai[c] ?? "")
                }
                if !mangDong.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    bang.append(mangDong)
                }
            }
        }
    }
}

// MARK: - 3. Màn Hình Thực Đơn Chính (Tab Thực Đơn)

final class ManHinhThucDon: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIDocumentPickerDelegate {
    private let theThongTinTep = UIView()
    private let nhanTenTep = UILabel()
    private let nhanTrangThaiThongBao = UILabel()
    private let nutChonTep = UIButton(type: .system)
    private let thanhTimKiem = UISearchBar()
    private let chonBoLoc = UISegmentedControl(items: ["Tất cả", "Sắp tới", "Ca Ngày ☀️", "Ca Đêm 🌙"])
    private let bang = UITableView(frame: .zero, style: .plain)

    private var tuKhoaTim: String = ""

    private var danhSachHienThi: [MucThucDonNgay] {
        let tatCa = KhoDuLieu.dungChung.duLieuThucDon.danhSachNgay
        let homNayKhoa = TienIchLich.dinhDangKhoaNgay.string(from: Date())

        let theoBoLoc = tatCa.filter { muc in
            switch chonBoLoc.selectedSegmentIndex {
            case 1: // Sắp tới (từ hôm nay trở đi)
                return muc.khoaNgay.isEmpty || muc.khoaNgay >= homNayKhoa
            case 2: // Ca Ngày
                return muc.laCaNgay
            case 3: // Ca Đêm
                return muc.laCaDem
            default:
                return true
            }
        }

        let tk = BoDocTapTinThucDon.boDau(tuKhoaTim).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tk.isEmpty else { return theoBoLoc }

        return theoBoLoc.filter { muc in
            let ghep = [
                muc.ngayVaoCa,
                muc.ca,
                muc.truaCaiThien,
                muc.truaMonChinh,
                muc.truaMonThuHai,
                muc.chieuToi,
                muc.anDem,
                muc.sangHomSau,
                muc.ghiChu
            ].joined(separator: " ")
            return BoDocTapTinThucDon.boDau(ghep).lowercased().contains(tk)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Thực Đơn"

        let nutThuThongBao = UIBarButtonItem(
            image: UIImage(systemName: "bell.badge.fill"),
            style: .plain,
            target: self,
            action: #selector(bamThuThongBao)
        )
        navigationItem.leftBarButtonItem = nutThuThongBao

        let nutMenu = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moMenuTuyChon)
        )
        let nutThem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(bamThemNgayThucDon)
        )
        let nutNhapFile = UIBarButtonItem(
            image: UIImage(systemName: "folder.badge.plus"),
            style: .done,
            target: self,
            action: #selector(bamChonTepThucDon)
        )
        navigationItem.rightBarButtonItems = [nutMenu, nutThem, nutNhapFile]

        taoGiaoDien()
        capNhatGiaoDien()

        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .thucDonCapNhat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .duLieuDongBoXong, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capNhatGiaoDien()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func taoGiaoDien() {
        theThongTinTep.layer.cornerRadius = 12
        theThongTinTep.layer.borderWidth = 1
        theThongTinTep.translatesAutoresizingMaskIntoConstraints = false

        nhanTenTep.font = .systemFont(ofSize: 13, weight: .semibold)
        nhanTenTep.numberOfLines = 2

        nhanTrangThaiThongBao.font = .systemFont(ofSize: 11.5, weight: .medium)
        nhanTrangThaiThongBao.numberOfLines = 2

        var chChon = UIButton.Configuration.filled()
        chChon.title = "📂 Nhập file Thực đơn (.xlsx / .csv)"
        chChon.cornerStyle = .medium
        chChon.buttonSize = .small
        nutChonTep.configuration = chChon
        nutChonTep.heightAnchor.constraint(equalToConstant: 34).isActive = true
        nutChonTep.addTarget(self, action: #selector(bamChonTepThucDon), for: .touchUpInside)

        let nutQuyTac = UIButton(type: .system)
        var chQT = UIButton.Configuration.tinted()
        chQT.title = "📋 Quy tắc"
        chQT.cornerStyle = .medium
        chQT.buttonSize = .small
        nutQuyTac.configuration = chQT
        nutQuyTac.heightAnchor.constraint(equalToConstant: 34).isActive = true
        nutQuyTac.widthAnchor.constraint(equalToConstant: 96).isActive = true
        nutQuyTac.addTarget(self, action: #selector(hienQuyTacLoc), for: .touchUpInside)

        let hangNutTep = UIStackView(arrangedSubviews: [nutChonTep, nutQuyTac])
        hangNutTep.axis = .horizontal
        hangNutTep.spacing = 8

        let nganTep = UIStackView(arrangedSubviews: [nhanTenTep, nhanTrangThaiThongBao, hangNutTep])
        nganTep.axis = .vertical
        nganTep.spacing = 6
        nganTep.translatesAutoresizingMaskIntoConstraints = false
        theThongTinTep.addSubview(nganTep)

        thanhTimKiem.placeholder = "Tìm ngày (VD: 14/11) hoặc tên món ăn..."
        thanhTimKiem.delegate = self
        thanhTimKiem.searchBarStyle = .minimal
        thanhTimKiem.translatesAutoresizingMaskIntoConstraints = false

        chonBoLoc.selectedSegmentIndex = 0
        chonBoLoc.addTarget(self, action: #selector(doiBoLoc), for: .valueChanged)
        chonBoLoc.translatesAutoresizingMaskIntoConstraints = false

        bang.dataSource = self
        bang.delegate = self
        bang.separatorStyle = .none
        bang.backgroundColor = .clear
        bang.keyboardDismissMode = .onDrag
        bang.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(theThongTinTep)
        view.addSubview(thanhTimKiem)
        view.addSubview(chonBoLoc)
        view.addSubview(bang)

        NSLayoutConstraint.activate([
            theThongTinTep.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            theThongTinTep.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            theThongTinTep.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            nganTep.topAnchor.constraint(equalTo: theThongTinTep.topAnchor, constant: 10),
            nganTep.bottomAnchor.constraint(equalTo: theThongTinTep.bottomAnchor, constant: -10),
            nganTep.leadingAnchor.constraint(equalTo: theThongTinTep.leadingAnchor, constant: 12),
            nganTep.trailingAnchor.constraint(equalTo: theThongTinTep.trailingAnchor, constant: -12),

            thanhTimKiem.topAnchor.constraint(equalTo: theThongTinTep.bottomAnchor, constant: 2),
            thanhTimKiem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            thanhTimKiem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            thanhTimKiem.heightAnchor.constraint(equalToConstant: 42),

            chonBoLoc.topAnchor.constraint(equalTo: thanhTimKiem.bottomAnchor, constant: 2),
            chonBoLoc.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            chonBoLoc.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            bang.topAnchor.constraint(equalTo: chonBoLoc.bottomAnchor, constant: 6),
            bang.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bang.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bang.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func capNhatGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        let cd = KhoDuLieu.dungChung.caiDat
        let td = KhoDuLieu.dungChung.duLieuThucDon

        view.backgroundColor = mau.bg
        theThongTinTep.backgroundColor = mau.card
        theThongTinTep.layer.borderColor = mau.border.cgColor

        let tenFile = td.tenTepNguon.isEmpty ? "Chưa chọn file" : td.tenTepNguon
        let tenSheet = td.tenSheetChinh.isEmpty ? "" : " (\(td.tenSheetChinh))"
        nhanTenTep.text = "📄 File: \(tenFile)\(tenSheet) • \(td.danhSachNgay.count) ngày"
        nhanTenTep.textColor = mau.text

        let gioNgayStr = TienIchLich.dinhDangGioPhut.string(from: cd.gioThongBaoThucDonNgay)
        let gioDemStr = TienIchLich.dinhDangGioPhut.string(from: cd.gioThongBaoThucDonDem)
        if cd.batThongBaoThucDon {
            nhanTrangThaiThongBao.text = "🔔 Thông báo thực đơn: Đang BẬT (☀️ Ca Ngày \(gioNgayStr) • 🌙 Ca Đêm \(gioDemStr))"
            nhanTrangThaiThongBao.textColor = mau.success
        } else {
            nhanTrangThaiThongBao.text = "🔕 Thông báo thực đơn: Đang TẮT (Bật & chỉnh giờ trong tab Cài đặt)"
            nhanTrangThaiThongBao.textColor = mau.subText
        }

        bang.reloadData()
    }

    @objc private func doiBoLoc() {
        bang.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        tuKhoaTim = searchText
        bang.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Chọn File Thực Đơn Tên Bất Kỳ

    @objc private func bamChonTepThucDon() {
        let cacLoai: [UTType] = [
            .spreadsheet,
            .commaSeparatedText,
            .tabSeparatedText,
            .plainText,
            .pdf,
            .data,
            .item
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: cacLoai, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        let alert = UIAlertController(
            title: "Cách lọc file Thực đơn",
            message: "Bạn vừa chọn file:\n\"\(url.lastPathComponent)\"\n\nBạn muốn hiển thị nguyên danh sách các ngày trong file hay lọc theo chu kỳ ca làm việc ở Cài đặt?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Giữ nguyên theo file", style: .default) { [weak self] _ in
            self?.thucHienDocFile(url: url, locTheoChuKy: false)
        })

        alert.addAction(UIAlertAction(title: "Lọc theo Chu kỳ ca Cài đặt", style: .default) { [weak self] _ in
            self?.thucHienDocFile(url: url, locTheoChuKy: true)
        })

        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func thucHienDocFile(url: URL, locTheoChuKy: Bool) {
        do {
            let duLieuMoi = try BoDocTapTinThucDon.docTuURL(url, locTheoChuKyCaiDat: locTheoChuKy)
            KhoDuLieu.dungChung.luuDuLieuThucDon(duLieuMoi)
            capNhatGiaoDien()
            TienIchLich.capNhatTatCaThongBaoThucDon { [weak self] soLuongHen in
                self?.hienThongBao(
                    "Đã nhập Thực đơn! 🎉",
                    "Đã đọc thành công \(duLieuMoi.danhSachNgay.count) ngày thực đơn từ file \"\(duLieuMoi.tenTepNguon)\" và đặt lịch \(soLuongHen) thông báo sắp tới."
                )
            }
        } catch {
            hienThongBao("Không thể đọc file", error.localizedDescription)
        }
    }

    // MARK: - Các Tùy Chọn Phụ Trợ

    @objc private func moMenuTuyChon() {
        let sheet = UIAlertController(title: "Tùy chọn Thực đơn", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "📂 Chọn file Thực đơn khác (.xlsx, .csv)", style: .default) { [weak self] _ in
            self?.bamChonTepThucDon()
        })

        sheet.addAction(UIAlertAction(title: "🔄 Lọc danh sách hiện tại theo Chu kỳ ca Cài đặt", style: .default) { [weak self] _ in
            guard let self else { return }
            var td = KhoDuLieu.dungChung.duLieuThucDon
            td.danhSachNgay = BoDocTapTinThucDon.apDungLocTheoChuKyCa(td.danhSachNgay)
            KhoDuLieu.dungChung.luuDuLieuThucDon(td)
            self.capNhatGiaoDien()
            self.hienThongBao("Đã lọc theo chu kỳ ca", "Danh sách thực đơn đã được lọc khớp với chu kỳ ca làm việc của bạn và cập nhật lại thông báo.")
        })

        sheet.addAction(UIAlertAction(title: "📋 Xem Quy tắc lọc & Nguồn thực đơn", style: .default) { [weak self] _ in
            self?.hienQuyTacLoc()
        })

        sheet.addAction(UIAlertAction(title: "🔔 Gửi thử thông báo thực đơn ngay", style: .default) { [weak self] _ in
            self?.bamThuThongBao()
        })

        sheet.addAction(UIAlertAction(title: "🔁 Khôi phục thực đơn mẫu Kíp A Tháng 11/2026", style: .default) { [weak self] _ in
            let mau = DuLieuThucDon.duLieuMauThang11()
            KhoDuLieu.dungChung.luuDuLieuThucDon(mau)
            self?.capNhatGiaoDien()
            self?.hienThongBao("Đã khôi phục", "Đã nạp lại thực đơn mẫu Kíp A Tháng 11/2026 (16 ngày ca).")
        })

        sheet.addAction(UIAlertAction(title: "🗑️ Xóa toàn bộ danh sách thực đơn", style: .destructive) { [weak self] _ in
            let rong = DuLieuThucDon(tenTepNguon: "Trống", tenSheetChinh: "", danhSachNgay: [], quyTacLoc: [])
            KhoDuLieu.dungChung.luuDuLieuThucDon(rong)
            self?.capNhatGiaoDien()
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(sheet, animated: true)
    }

    @objc private func hienQuyTacLoc() {
        let qt = KhoDuLieu.dungChung.duLieuThucDon.quyTacLoc
        let noiDung: String
        if qt.isEmpty {
            noiDung = """
            • Ca ngày: Lấy bữa trưa (món cải thiện + món chính + món thứ 2) và bữa chiều/tối cùng ngày.
            • Ca đêm: Lấy món ăn đêm ngày vào ca và món ăn sáng của ngày kế tiếp.
            • Hỗ trợ nhập file .xlsx hoặc .csv có tên bất kỳ.
            """
        } else {
            noiDung = qt.map { "• \($0.noiDung): \($0.quyTac)" }.joined(separator: "\n\n")
        }
        hienThongBao("📋 Quy tắc lọc & Thông tin", noiDung)
    }

    @objc private func bamThuThongBao() {
        let homNayKhoa = TienIchLich.dinhDangKhoaNgay.string(from: Date())
        let ds = KhoDuLieu.dungChung.duLieuThucDon.danhSachNgay
        let mucSapToi = ds.first(where: { $0.khoaNgay >= homNayKhoa }) ?? ds.first
        TienIchLich.guiThongBaoThuThucDon(muc: mucSapToi)
        hienThongBao(
            "Đã hẹn thông báo thử 🔔",
            "Thông báo thực đơn sẽ hiển thị trên màn hình sau khoảng 1.5 giây (bạn có thể giữ nguyên hoặc vuốt thông báo ở đầu màn hình)."
        )
    }

    @objc private func bamThemNgayThucDon() {
        let modal = ManHinhChiTietThucDonNgay(muc: nil) { [weak self] in
            self?.capNhatGiaoDien()
        }
        let nav = UINavigationController(rootViewController: modal)
        present(nav, animated: true)
    }

    private func hienThongBao(_ tieuDe: String, _ noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource & Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(1, danhSachHienThi.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if danhSachHienThi.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "OTrongThucDon")
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.textLabel?.text = "Không có ngày thực đơn nào khớp bộ lọc.\nBấm nút '📂 Nhập file Thực đơn' để tải file mới."
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = .italicSystemFont(ofSize: 14)
            cell.textLabel?.textColor = KhoDuLieu.dungChung.mauSac.subText
            return cell
        }

        let ma = "OThucDonNgay"
        let cell = tableView.dequeueReusableCell(withIdentifier: ma) ?? UITableViewCell(style: .default, reuseIdentifier: ma)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let muc = danhSachHienThi[indexPath.row]
        let mau = KhoDuLieu.dungChung.mauSac
        let homNayKhoa = TienIchLich.dinhDangKhoaNgay.string(from: Date())
        let laHomNay = (!muc.khoaNgay.isEmpty && muc.khoaNgay == homNayKhoa)

        let the = UIView()
        if laHomNay {
            the.backgroundColor = KhoDuLieu.dungChung.caiDat.giaoDienToi
                ? UIColor(red: 0.99, green: 0.94, blue: 0.54, alpha: 0.14)
                : UIColor(red: 0.99, green: 0.98, blue: 0.82, alpha: 1)
            the.layer.borderColor = UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1).cgColor
            the.layer.borderWidth = 1.8
        } else {
            the.backgroundColor = mau.card
            the.layer.borderColor = mau.border.cgColor
            the.layer.borderWidth = 1
        }
        the.layer.cornerRadius = 14
        the.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(the)

        // Hàng đầu: Ngày + Thứ + Âm lịch + Huy hiệu Ca
        let lbNgay = UILabel()
        var chuoiThu = ""
        if let d = TienIchLich.docNgayThucDon(muc.ngayVaoCa) {
            let thu = TienIchLich.thuVietNam(d)
            let am = TienIchLich.thongTinAmLich(d).chuoi
            chuoiThu = " • \(thu) (ÂL \(am))"
        }
        lbNgay.text = "📅 \(muc.ngayVaoCa)\(chuoiThu)" + (laHomNay ? "  🌟 HÔM NAY" : "")
        lbNgay.font = .systemFont(ofSize: 14.5, weight: .bold)
        lbNgay.textColor = laHomNay ? UIColor(red: 0.85, green: 0.45, blue: 0.02, alpha: 1) : mau.text
        lbNgay.numberOfLines = 1
        lbNgay.adjustsFontSizeToFitWidth = true
        lbNgay.minimumScaleFactor = 0.8

        let nhanCa = UILabel()
        let laDem = muc.laCaDem
        nhanCa.text = laDem ? "  🌙 Ca Đêm  " : "  ☀️ Ca Ngày  "
        nhanCa.font = .systemFont(ofSize: 12, weight: .bold)
        let mauCa = laDem
            ? UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)
            : UIColor(red: 0.96, green: 0.55, blue: 0.04, alpha: 1)
        nhanCa.textColor = mauCa
        nhanCa.backgroundColor = mauCa.withAlphaComponent(0.14)
        nhanCa.layer.cornerRadius = 8
        nhanCa.layer.masksToBounds = true
        nhanCa.setContentHuggingPriority(.required, for: .horizontal)
        nhanCa.setContentCompressionResistancePriority(.required, for: .horizontal)
        nhanCa.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let hangTren = UIStackView(arrangedSubviews: [lbNgay, nhanCa])
        hangTren.axis = .horizontal
        hangTren.spacing = 8
        hangTren.alignment = .center

        let vach = UIView()
        vach.backgroundColor = mau.border
        vach.heightAnchor.constraint(equalToConstant: 0.8).isActive = true

        let nganMonAn = UIStackView()
        nganMonAn.axis = .vertical
        nganMonAn.spacing = 5

        func themDongMon(nhan: String, giaTri: String, mauNhan: UIColor) {
            let gt = giaTri.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !gt.isEmpty else { return }
            let lb = UILabel()
            lb.numberOfLines = 0
            let attr = NSMutableAttributedString(
                string: "\(nhan): ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13.5, weight: .semibold),
                    .foregroundColor: mauNhan
                ]
            )
            attr.append(NSAttributedString(
                string: gt,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13.5, weight: .regular),
                    .foregroundColor: mau.text
                ]
            ))
            lb.attributedText = attr
            nganMonAn.addArrangedSubview(lb)
        }

        themDongMon(nhan: "🍱 Trưa - Cải thiện", giaTri: muc.truaCaiThien, mauNhan: mau.primary)
        themDongMon(nhan: "🥩 Trưa - Món chính", giaTri: muc.truaMonChinh, mauNhan: mau.primary)
        themDongMon(nhan: "🥘 Trưa - Món thứ 2", giaTri: muc.truaMonThuHai, mauNhan: mau.primary)
        themDongMon(nhan: "🍲 Chiều/Tối (ca ngày)", giaTri: muc.chieuToi, mauNhan: UIColor(red: 0.90, green: 0.45, blue: 0.05, alpha: 1))
        themDongMon(nhan: "🍜 Ăn đêm (ca đêm)", giaTri: muc.anDem, mauNhan: UIColor(red: 0.42, green: 0.40, blue: 0.95, alpha: 1))
        themDongMon(nhan: "🥖 Sáng hôm sau", giaTri: muc.sangHomSau, mauNhan: mau.success)

        let gc = muc.ghiChu.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gc.isEmpty {
            let lbGC = UILabel()
            lbGC.numberOfLines = 0
            lbGC.font = .italicSystemFont(ofSize: 12)
            lbGC.textColor = mau.subText
            lbGC.text = "📝 Ghi chú: \(gc)"
            nganMonAn.addArrangedSubview(lbGC)
        }

        let nganChinh = UIStackView(arrangedSubviews: [hangTren, vach, nganMonAn])
        nganChinh.axis = .vertical
        nganChinh.spacing = 7
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            the.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 5),
            the.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -5),
            the.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
            the.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),

            nganChinh.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
            nganChinh.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
            nganChinh.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !danhSachHienThi.isEmpty, danhSachHienThi.indices.contains(indexPath.row) else { return }
        let muc = danhSachHienThi[indexPath.row]
        let modal = ManHinhChiTietThucDonNgay(muc: muc) { [weak self] in
            self?.capNhatGiaoDien()
        }
        let nav = UINavigationController(rootViewController: modal)
        present(nav, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard !danhSachHienThi.isEmpty, danhSachHienThi.indices.contains(indexPath.row) else { return nil }
        let muc = danhSachHienThi[indexPath.row]

        let xoa = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            var td = KhoDuLieu.dungChung.duLieuThucDon
            td.danhSachNgay.removeAll { $0.id == muc.id }
            KhoDuLieu.dungChung.luuDuLieuThucDon(td)
            self?.capNhatGiaoDien()
            completion(true)
        }

        let baoThu = UIContextualAction(style: .normal, title: "🔔 Báo thử") { _, _, completion in
            TienIchLich.guiThongBaoThuThucDon(muc: muc)
            completion(true)
        }
        baoThu.backgroundColor = KhoDuLieu.dungChung.mauSac.primary

        return UISwipeActionsConfiguration(actions: [xoa, baoThu])
    }
}

// MARK: - 4. Màn Hình Xem & Chỉnh Sửa Chi Tiết Thực Đơn 1 Ngày

final class ManHinhChiTietThucDonNgay: UIViewController {
    private let mucCu: MucThucDonNgay?
    private let khiLuu: () -> Void

    private let chonNgay = UIDatePicker()
    private let chonCa = UISegmentedControl(items: ["Ca Ngày ☀️", "Ca Đêm 🌙"])
    private let oTruaCaiThien = UITextField()
    private let oTruaMonChinh = UITextField()
    private let oTruaMonThuHai = UITextField()
    private let oChieuToi = UITextView()
    private let oAnDem = UITextField()
    private let oSangHomSau = UITextField()
    private let oGhiChu = UITextField()

    init(muc: MucThucDonNgay?, khiLuu: @escaping () -> Void) {
        self.mucCu = muc
        self.khiLuu = khiLuu
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.card
        navigationItem.title = mucCu == nil ? "Thêm ngày thực đơn" : "Chi tiết thực đơn"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(luu))

        let cuon = UIScrollView()
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        let ngan = UIStackView()
        ngan.axis = .vertical
        ngan.spacing = 10
        ngan.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(ngan)

        chonNgay.datePickerMode = .date
        chonNgay.preferredDatePickerStyle = .compact
        chonNgay.locale = Locale(identifier: "vi_VN")
        if let mucCu, let d = TienIchLich.docNgayThucDon(mucCu.ngayVaoCa) {
            chonNgay.date = d
        }

        let lbNgay = UILabel()
        lbNgay.text = "Ngày vào ca:"
        lbNgay.font = .systemFont(ofSize: 14, weight: .semibold)
        lbNgay.textColor = mau.text

        let hangNgay = UIStackView(arrangedSubviews: [lbNgay, chonNgay])
        hangNgay.distribution = .equalSpacing
        hangNgay.alignment = .center

        chonCa.selectedSegmentIndex = (mucCu?.laCaDem == true) ? 1 : 0

        [oTruaCaiThien, oTruaMonChinh, oTruaMonThuHai, oAnDem, oSangHomSau, oGhiChu].forEach {
            $0.borderStyle = .roundedRect
            $0.backgroundColor = mau.iconBg
            $0.textColor = mau.text
            $0.font = .systemFont(ofSize: 14)
        }

        oTruaCaiThien.placeholder = "VD: Bánh canh chả tôm / Sữa tươi Ba Vì"
        oTruaCaiThien.text = mucCu?.truaCaiThien ?? ""

        oTruaMonChinh.placeholder = "VD: Bò nấu lagu"
        oTruaMonChinh.text = mucCu?.truaMonChinh ?? ""

        oTruaMonThuHai.placeholder = "VD: Đậu khuôn chiên sốt cà"
        oTruaMonThuHai.text = mucCu?.truaMonThuHai ?? ""

        oChieuToi.backgroundColor = mau.iconBg
        oChieuToi.textColor = mau.text
        oChieuToi.font = .systemFont(ofSize: 14)
        oChieuToi.layer.cornerRadius = 8
        oChieuToi.layer.borderWidth = 1
        oChieuToi.layer.borderColor = mau.border.cgColor
        oChieuToi.text = mucCu?.chieuToi ?? ""
        oChieuToi.heightAnchor.constraint(equalToConstant: 68).isActive = true

        oAnDem.placeholder = "VD: Hủ tiếu giò heo / Sữa tươi Vinamilk"
        oAnDem.text = mucCu?.anDem ?? ""

        oSangHomSau.placeholder = "VD: 10/11: Bánh mì cà ri gà / Sữa tươi Ba Vì"
        oSangHomSau.text = mucCu?.sangHomSau ?? ""

        oGhiChu.placeholder = "Ghi chú thêm (nếu có)..."
        oGhiChu.text = mucCu?.ghiChu ?? ""

        func taoMuc(_ tieuDe: String, _ viewCon: UIView) -> UIStackView {
            let lb = UILabel()
            lb.text = tieuDe
            lb.font = .systemFont(ofSize: 12.5, weight: .bold)
            lb.textColor = mau.subText
            let st = UIStackView(arrangedSubviews: [lb, viewCon])
            st.axis = .vertical
            st.spacing = 4
            return st
        }

        let nutBaoThu = UIButton(type: .system)
        var chBao = UIButton.Configuration.tinted()
        chBao.title = "🔔 Gửi thử thông báo cho ngày này"
        nutBaoThu.configuration = chBao
        nutBaoThu.addTarget(self, action: #selector(baoThuNgayNay), for: .touchUpInside)

        [
            hangNgay,
            chonCa,
            taoMuc("🍱 Trưa - Cải thiện:", oTruaCaiThien),
            taoMuc("🥩 Trưa - Món chính:", oTruaMonChinh),
            taoMuc("🥘 Trưa - Món thứ 2:", oTruaMonThuHai),
            taoMuc("🍲 Chiều/Tối (ca ngày):", oChieuToi),
            taoMuc("🍜 Ăn đêm (ca đêm):", oAnDem),
            taoMuc("🥖 Sáng hôm sau:", oSangHomSau),
            taoMuc("📝 Ghi chú:", oGhiChu),
            nutBaoThu
        ].forEach { ngan.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            ngan.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 14),
            ngan.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -28),
            ngan.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            ngan.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    private func taoMucHienTai() -> MucThucDonNgay {
        let ngayStr = TienIchLich.dinhDangNgayViet.string(from: chonNgay.date)
        let khoaStr = TienIchLich.dinhDangKhoaNgay.string(from: chonNgay.date)
        let caStr = chonCa.selectedSegmentIndex == 1 ? "Đêm" : "Ngày"
        return MucThucDonNgay(
            id: mucCu?.id ?? UUID().uuidString,
            ngayVaoCa: ngayStr,
            khoaNgay: khoaStr,
            ca: caStr,
            truaCaiThien: oTruaCaiThien.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            truaMonChinh: oTruaMonChinh.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            truaMonThuHai: oTruaMonThuHai.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            chieuToi: oChieuToi.text.trimmingCharacters(in: .whitespacesAndNewlines),
            anDem: oAnDem.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            sangHomSau: oSangHomSau.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            ghiChu: oGhiChu.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    @objc private func baoThuNgayNay() {
        let muc = taoMucHienTai()
        TienIchLich.guiThongBaoThuThucDon(muc: muc)
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        view.endEditing(true)
        let moi = taoMucHienTai()
        var td = KhoDuLieu.dungChung.duLieuThucDon
        if let idx = td.danhSachNgay.firstIndex(where: { $0.id == moi.id }) {
            td.danhSachNgay[idx] = moi
        } else {
            td.danhSachNgay.append(moi)
        }
        KhoDuLieu.dungChung.luuDuLieuThucDon(td)
        dismiss(animated: true, completion: khiLuu)
    }
}
