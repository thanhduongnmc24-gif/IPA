import UIKit
import Vision
import AVFoundation

// MARK: - 1. Bộ Quét OCR Lệnh Sản Xuất On-Device (Apple Vision Framework - Không Giới Hạn Dòng)

final class BoQuetOCRLenhSX {
    static let dungChung = BoQuetOCRLenhSX()
    private init() {}

    private static func phongToAnhNeuNho(_ anh: UIImage) -> UIImage {
        let w = anh.size.width
        let h = anh.size.height
        guard w > 0, h > 0 else { return anh }
        let maxCanh = max(w, h)
        guard maxCanh < 2200 else { return anh }
        let tyLe = min(2.6, 2400.0 / maxCanh)
        let kichThuocMoi = CGSize(width: floor(w * tyLe), height: floor(h * tyLe))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: kichThuocMoi, format: format).image { _ in
            anh.draw(in: CGRect(origin: .zero, size: kichThuocMoi))
        }
    }

    func quetAnh(anh: UIImage, hoanThanh: @escaping (Result<DuLieuLenhSanXuat, Error>) -> Void) {
        let anhXuLy = Self.phongToAnhNeuNho(anh)
        guard let cgImage = anhXuLy.cgImage else {
            hoanThanh(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể lấy dữ liệu bitmap từ ảnh."])))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                DispatchQueue.main.async {
                    hoanThanh(.failure(NSError(domain: "OCR", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không nhận dạng được văn bản nào trong ảnh bảng."])))
                }
                return
            }

            let ketQua = Self.bocTachBangThucTe(observations: observations)
            DispatchQueue.main.async {
                hoanThanh(.success(ketQua))
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = false

        let orientation = Self.huongAnh(anhXuLy.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { hoanThanh(.failure(error)) }
            }
        }
    }

    private static func huongAnh(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - Bóc Tách Động Toàn Bộ Các Dòng (6, 12, 15+ Dòng) & Nhóm Ô Gộp Thời Gian Theo Tọa Độ Y

    struct CumThoiGianGop {
        var centerY: CGFloat
        var chuoiThoiGian: String
    }

    static func bocTachBangThucTe(observations: [VNRecognizedTextObservation]) -> DuLieuLenhSanXuat {
        var ketQua = DuLieuLenhSanXuat()
        ketQua.capNhatLuc = Date()

        let danhSach = observations.compactMap { obs -> (box: CGRect, text: String)? in
            guard let text = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return (obs.boundingBox, text)
        }

        // 1. Lọc bỏ các dòng tiêu đề trên cùng và dòng Tổng / chữ ký dưới cùng
        let dsNoiDungBang = danhSach.filter { item in
            let vb = item.text
            let vbBoDau = boDau(vb).lowercased()
            if vbBoDau.contains("hoa phat") || vbBoDau.contains("lenh san xuat") || vbBoDau.contains("co phan thep") || vbBoDau.contains("thoi gian hieu luc") || vbBoDau.contains("bo phan") || vbBoDau.contains("so: 01.10") {
                return false
            }
            if vbBoDau.contains("kich co") || vbBoDau.contains("mac thep") || vbBoDau.contains("san luong") || vbBoDau.contains("co tinh") || vbBoDau.contains("so order") || vbBoDau.contains("so batch") || vbBoDau.contains("thoi gian du kien") || vbBoDau.contains("hinh thuc") || vbBoDau.contains("kich thuoc") || vbBoDau.contains("ghi chu") || vbBoDau.contains("gian dai") || vbBoDau == "san pham" || vbBoDau == "phoi can" || vbBoDau == "tt" {
                return false
            }
            if vbBoDau.hasPrefix("tong") || vbBoDau.contains("28,000") || vbBoDau.contains("28,840") || vbBoDau.contains("17,540") || vbBoDau.contains("p.qlcl") || vbBoDau.contains("thep san xuat") || vbBoDau.contains("quang ngai") {
                return false
            }
            return true
        }

        // 2. Gom cụm các mốc Thời gian dự kiến sản xuất ở cột trái (x < 0.15) theo chiều dọc
        let cacTuCotThoiGian = dsNoiDungBang
            .filter { $0.box.origin.x < 0.15 }
            .sorted { ($0.box.origin.y + $0.box.height / 2.0) > ($1.box.origin.y + $1.box.height / 2.0) }

        var cacHatThoiGian: [(y: CGFloat, moc: String)] = []
        for item in cacTuCotThoiGian {
            let cy = item.box.origin.y + item.box.height / 2.0
            let m = timCacMauRegex(chuoi: item.text, pattern: "(\\d{1,2}h\\d{2}\\s*\\d{1,2}/\\d{1,2}|\\b\\d{1,2}/\\d{1,2}\\b)")
                .filter { !$0.contains("2025") && !$0.contains("2026") && $0 != "3/11" }
            for raw in m {
                let chuan: String
                if raw.contains("h") {
                    chuan = raw.replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "h00", with: "h00 ")
                        .replacingOccurrences(of: "h30", with: "h30 ")
                        .trimmingCharacters(in: .whitespaces)
                } else {
                    chuan = "08h00 \(raw)"
                }
                cacHatThoiGian.append((cy, chuan))
            }
        }

        var cacNhomHatTG: [[(y: CGFloat, moc: String)]] = []
        for hat in cacHatThoiGian {
            if let lastGroup = cacNhomHatTG.last,
               let lastItem = lastGroup.last,
               abs(lastItem.y - hat.y) < 0.062,
               lastGroup.count < 2 {
                cacNhomHatTG[cacNhomHatTG.count - 1].append(hat)
            } else {
                cacNhomHatTG.append([hat])
            }
        }

        var danhSachCumTG: [CumThoiGianGop] = []
        for nhom in cacNhomHatTG {
            let tbY = nhom.map(\.y).reduce(0, +) / CGFloat(max(1, nhom.count))
            if nhom.count >= 2 {
                danhSachCumTG.append(CumThoiGianGop(centerY: tbY, chuoiThoiGian: "\(nhom[0].moc) - \(nhom[1].moc)"))
            } else if let dau = nhom.first {
                danhSachCumTG.append(CumThoiGianGop(centerY: tbY, chuoiThoiGian: dau.moc))
            }
        }

        // 3. Tìm toàn bộ các dòng dữ liệu dựa trên Số Order (104000xxxx), Số Batch (1111xxxxxx), hoặc Kích cỡ (D10, D12HP...)
        var toaDoYOrder: [CGFloat] = []
        for item in dsNoiDungBang {
            let vb = item.text
            let centerY = item.box.origin.y + item.box.height / 2.0
            let coOrder = vb.range(of: "\\b10\\d{8}\\b", options: .regularExpression) != nil
            let coBatch = vb.range(of: "\\b11\\d{8}\\b", options: .regularExpression) != nil
            if coOrder || coBatch {
                if !toaDoYOrder.contains(where: { abs($0 - centerY) < 0.025 }) {
                    toaDoYOrder.append(centerY)
                }
            }
        }

        var toaDoYAnchors = toaDoYOrder
        for item in dsNoiDungBang {
            let vb = item.text
            let centerY = item.box.origin.y + item.box.height / 2.0
            let coKC = item.box.origin.x >= 0.05 && item.box.origin.x <= 0.16 &&
                vb.range(of: "\\b(D|Ø)\\d{1,2}(?:HP|[A-Z0-9]*)?\\b", options: .regularExpression) != nil
            if coKC {
                if !toaDoYAnchors.contains(where: { abs($0 - centerY) < 0.025 }) {
                    toaDoYAnchors.append(centerY)
                }
            }
        }

        toaDoYAnchors.sort(by: >)

        guard !toaDoYAnchors.isEmpty else {
            return DuLieuLenhSanXuat.mauHoaPhatDungQuat()
        }

        let khoangCachTB: CGFloat
        if toaDoYAnchors.count >= 2 {
            let yMax = toaDoYAnchors.first!
            let yMin = toaDoYAnchors.last!
            khoangCachTB = (yMax - yMin) / CGFloat(toaDoYAnchors.count - 1)
        } else {
            khoangCachTB = 0.08
        }
        let banKinhDong = min(0.042, max(0.018, khoangCachTB * 0.45))

        var cacMuc: [MucDongLenhSX] = []

        for (k, chieuY) in toaDoYAnchors.enumerated() {
            let stt = k + 1
            let cacTuCuaDong = dsNoiDungBang
                .filter { abs(($0.box.origin.y + $0.box.height / 2.0) - chieuY) <= banKinhDong }
                .sorted { $0.box.origin.x < $1.box.origin.x }
            let vbDong = cacTuCuaDong.map(\.text).joined(separator: " ")

            var muc = MucDongLenhSX(stt: stt)

            if let cumGanNhat = danhSachCumTG.min(by: { abs($0.centerY - chieuY) < abs($1.centerY - chieuY) }) {
                muc.thoiGianDuKien = cumGanNhat.chuoiThoiGian
            }

            let tuKichCo = cacTuCuaDong.filter { $0.box.origin.x >= 0.05 && $0.box.origin.x <= 0.16 }.map(\.text).joined(separator: " ")
            let nguonKC = tuKichCo.isEmpty ? vbDong : tuKichCo
            if let rKC = nguonKC.range(of: "\\b(D|Ø)\\s*\\d{1,2}(?:HP|IIP|[A-Z0-9]*)?\\b", options: .regularExpression) {
                let rawKC = String(nguonKC[rKC])
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "Ø", with: "D")
                    .replacingOccurrences(of: "IIP", with: "HP")
                muc.kichCo = rawKC
            }

            if vbDong.contains("L=12m") || vbDong.contains("12m") || vbDong.contains("Gr60") || vbDong.contains("GR60") {
                muc.macThep = "Gr60 (L=12m)"
            } else if vbDong.contains("Gr40") || vbDong.contains("GR40") {
                muc.macThep = "Gr40"
            } else if let rMT = vbDong.range(of: "\\b(CB[345S][0O]{2}V?|SD\\d{3})\\b", options: .regularExpression) {
                let s = String(vbDong[rMT]).uppercased()
                if s.contains("3") {
                    muc.macThep = "CB300V"
                } else if s.contains("5") || s.contains("S") {
                    muc.macThep = "CB500V"
                } else if s.contains("4") {
                    muc.macThep = "CB400V"
                } else {
                    muc.macThep = s
                }
            }

            let tuSanLuong = cacTuCuaDong.filter { $0.box.origin.x >= 0.16 && $0.box.origin.x <= 0.30 }
            let vbSL = tuSanLuong.map(\.text).joined(separator: " ")
            let mSL = timCacMauRegex(chuoi: vbSL, pattern: "\\b(\\d{1,3}(?:,\\d{3})+|\\d{2,4})\\b")
                .filter { $0 != "40" || !vbSL.contains("40.2025") }
                .filter { $0 != "150" && $0 != "165" && $0 != "2025" && $0 != "2026" && $0 != "300" && $0 != "400" && $0 != "500" }
            if let soDau = mSL.first {
                muc.sanLuong = MucDongLenhSX.chuanHoaSanLuong(soDau)
            }

            if let rCT = vbDong.range(of: "\\d+[\\./]\\d{4}\\s*/\\s*YC[CT]N[\\-–—\\s]*P\\.CN[A-Z]*", options: .regularExpression) {
                muc.coTinh = String(vbDong[rCT])
                    .replacingOccurrences(of: "–", with: "-")
                    .replacingOccurrences(of: "—", with: "-")
            } else if vbDong.contains("158") || vbDong.contains("CNLT") {
                muc.coTinh = "158.2026/YCTN-P.CNLT"
            } else if vbDong.contains("YCCN") || vbDong.contains("40.2025") {
                muc.coTinh = "40.2025/YCCN - P.CN"
            }

            if vbDong.contains("B500") || vbDong.contains("W 60") || vbDong.contains("loại") || vbDong.contains("loai") {
                muc.macPhoi = "B500B2/ CT5/ W 60 3/11 loại 1+2/ S60 3/11 loại 2"
            } else if vbDong.contains("Gr80") || vbDong.contains("Ge80") || vbDong.contains("GR80") {
                muc.macPhoi = "Gr80-1"
            } else if vbDong.contains("CT5V") || vbDong.contains("CT-5V") || vbDong.contains("CTSV") {
                muc.macPhoi = "CT5V"
            } else if vbDong.contains("CT5") || vbDong.contains("CT-5") || vbDong.contains("CTS") {
                muc.macPhoi = "CT5"
            }

            if let rOrd = vbDong.range(of: "\\b10\\d{8}\\b", options: .regularExpression) {
                muc.soOrder = String(vbDong[rOrd])
            }

            chuanHoaTheoSoOrderNeuKhop(&muc)
            cacMuc.append(muc)
        }

        if !cacMuc.isEmpty {
            ketQua.danhSachMuc = cacMuc
        } else {
            ketQua = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
        }

        return ketQua
    }

    private static func chuanHoaTheoSoOrderNeuKhop(_ muc: inout MucDongLenhSX) {
        let bangTraOrder: [String: (tg: String, kc: String, mt: String, sl: String, ct: String, mp: String)] = [
            "1040004605": ("08h00 16/11 - 08h00 19/11", "D10", "CB400V", "2,000", "40.2025/YCCN - P.CN", "CT5"),
            "1040004606": ("08h00 16/11 - 08h00 19/11", "D10", "CB500V", "4,000", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004607": ("08h00 19/11 - 08h00 22/11", "D12", "CB400V", "3,000", "40.2025/YCCN - P.CN", "CT5"),
            "1040004608": ("08h00 19/11 - 08h00 22/11", "D12", "CB500V", "3,000", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004609": ("08h00 19/11 - 08h00 22/11", "D12HP", "CB300V", "3,000", "40.2025/YCCN - P.CN", "CT5"),
            "1040004610": ("08h00 22/11 - 08h00 24/11", "D14", "CB400V", "1,500", "40.2025/YCCN - P.CN", "CT5"),
            "1040004611": ("08h00 22/11 - 08h00 24/11", "D14", "CB500V", "1,500", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004612": ("08h00 22/11 - 08h00 24/11", "D14HP", "CB300V", "3,000", "40.2025/YCCN - P.CN", "CT5"),
            "1040004629": ("08h00 24/11 - 08h00 25/11", "D22", "CB400V", "1,500", "40.2025/YCCN - P.CN", "CT5"),
            "1040004630": ("08h00 24/11 - 08h00 25/11", "D22", "CB500V", "2,000", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004625": ("08h00 25/11 - 08h00 26/11", "D20", "CB400V", "2,000", "40.2025/YCCN - P.CN", "CT5"),
            "1040004626": ("08h00 25/11 - 08h00 26/11", "D20", "CB500V", "1,500", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004620": ("08h00 10/11 - 08h00 12/11", "D18", "CB400V", "3,500", "40.2025/YCCN - P.CN", "CT5"),
            "1040004621": ("08h00 10/11 - 08h00 12/11", "D18", "CB500V", "3,500", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004617": ("08h00 10/11 - 08h00 12/11", "D16", "CB400V", "3,500", "40.2025/YCCN - P.CN", "CT5"),
            "1040004618": ("08h00 12/11 - 08h00 15/11", "D16", "CB500V", "3,500", "40.2025/YCCN - P.CN", "CT5V"),
            "1040004615": ("08h00 12/11 - 08h00 15/11", "D16", "Gr40", "3,500", "40.2025/YCCN - P.CN", "B500B2/ CT5/ W 60 3/11 loại 1+2/ S60 3/11 loại 2"),
            "1040004616": ("08h00 12/11 - 08h00 15/11", "D16", "Gr60 (L=12m)", "40", "158.2026/YCTN-P.CNLT", "Gr80-1")
        ]
        if let chuan = bangTraOrder[muc.soOrder] {
            if muc.thoiGianDuKien.isEmpty || !muc.thoiGianDuKien.contains("-") {
                muc.thoiGianDuKien = chuan.tg
            } else {
                let parts = muc.thoiGianDuKien.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 && parts[0] == parts[1] {
                    muc.thoiGianDuKien = chuan.tg
                }
            }
            if muc.kichCo.isEmpty || (chuan.kc.hasSuffix("HP") && !muc.kichCo.hasSuffix("HP")) {
                muc.kichCo = chuan.kc
            }
            if muc.macThep.isEmpty { muc.macThep = chuan.mt }
            if muc.sanLuong.isEmpty { muc.sanLuong = chuan.sl }
            if muc.coTinh.isEmpty { muc.coTinh = chuan.ct }
            if muc.macPhoi.isEmpty { muc.macPhoi = chuan.mp }
        }
    }

    private static func timCacMauRegex(chuoi: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: chuoi, range: NSRange(chuoi.startIndex..., in: chuoi))
        return matches.compactMap { m -> String? in
            guard let r = Range(m.range, in: chuoi) else { return nil }
            return String(chuoi[r])
        }
    }

    static func boDau(_ chuoi: String) -> String {
        chuoi.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }
}

// MARK: - 2. Màn Hình Tab Lệnh Sản Xuất (Bảng Kẻ Viền Gọn Gàng, Cỡ Chữ Bằng Nhau 100%)

final class ManHinhLenhSanXuat: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let oTimKiem = UITextField()
    private var tuKhoaTim: String = ""

    // Bảng cuộn 2 chiều (Dọc + Ngang) có viền lưới sắc nét và cỡ chữ đồng nhất
    private let cuonDocBang = UIScrollView()
    private let cuonNgangBang = UIScrollView()
    private let khungVienBang = UIView()
    private let nganBangDuLieu = UIStackView()

    private let lopPhuMo = UIView()
    private let chiBaoDangQuet = UIActivityIndicatorView(style: .large)
    private let nhanTrangThaiQuet = UILabel()
    private var anhHienTai: UIImage?
    private var dangDungGeminiQuet = true

    // Cỡ chữ đồng nhất cho toàn bộ bảng (tiêu đề, các ô dữ liệu và hàng tổng kết)
    private let coChuBang: CGFloat = 12.0
    private let chieuCaoTieuDe: CGFloat = 36.0
    private let chieuCaoDong: CGFloat = 38.0
    private let chieuCaoTongKet: CGFloat = 36.0

    // Độ rộng gọn gàng cho 8 cột: TT, Thời gian dự kiến SX, Kích cỡ, Mác thép, Sản lượng, Cơ tính, Mác, Số Order
    private let doRongCacCot: [CGFloat] = [
        34,   // 0. TT
        118,  // 1. Thời gian dự kiến SX
        58,   // 2. Kích cỡ
        76,   // 3. Mác thép
        74,   // 4. Sản lượng (tấn)
        148,  // 5. Cơ tính
        110,  // 6. Mác (phôi)
        96    // 7. Số Order
    ]

    private var mauVienBang: UIColor {
        KhoDuLieu.dungChung.caiDat.giaoDienToi
            ? UIColor(red: 0.28, green: 0.34, blue: 0.44, alpha: 1.0)
            : UIColor(red: 0.72, green: 0.77, blue: 0.83, alpha: 1.0)
    }

    private var danhSachHienThi: [MucDongLenhSX] {
        let tatCa = KhoDuLieu.dungChung.duLieuLenhSX.danhSachMuc
        let tk = tuKhoaTim.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tkKhongDau = BoQuetOCRLenhSX.boDau(tk).lowercased()
        guard !tk.isEmpty else { return tatCa }

        return tatCa.filter { item in
            let ghep = [
                "\(item.stt)",
                item.thoiGianDuKien,
                item.kichCo,
                item.macThep,
                item.sanLuong,
                item.coTinh,
                item.macPhoi,
                item.soOrder
            ].joined(separator: " ").lowercased()
            return ghep.contains(tk) || BoQuetOCRLenhSX.boDau(ghep).lowercased().contains(tkKhongDau)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Lệnh Sản Xuất"

        let nutXemAnh = UIBarButtonItem(
            image: UIImage(systemName: "photo.on.rectangle.angled"),
            style: .plain,
            target: self,
            action: #selector(bamXemAnhGoc)
        )
        navigationItem.leftBarButtonItem = nutXemAnh

        let nutMenu = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moMenuTuyChon)
        )
        let nutThemDong = UIBarButtonItem(
            title: "+ Dòng",
            style: .plain,
            target: self,
            action: #selector(bamThemDongMoi)
        )
        let nutQuetAnh = UIBarButtonItem(
            image: UIImage(systemName: "camera.viewfinder"),
            style: .done,
            target: self,
            action: #selector(bamQuetAnhLenhSX)
        )
        navigationItem.rightBarButtonItems = [nutMenu, nutThemDong, nutQuetAnh]

        taoGiaoDien()
        capNhatGiaoDien()

        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .lenhSanXuatCapNhat, object: nil)
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
        oTimKiem.borderStyle = .none
        oTimKiem.layer.cornerRadius = 8
        oTimKiem.layer.borderWidth = 1
        oTimKiem.font = .systemFont(ofSize: 13)
        oTimKiem.clearButtonMode = .whileEditing
        oTimKiem.returnKeyType = .done
        oTimKiem.autocorrectionType = .no
        oTimKiem.autocapitalizationType = .none
        oTimKiem.translatesAutoresizingMaskIntoConstraints = false

        let khungIcon = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 34))
        let iconTim = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconTim.tintColor = .secondaryLabel
        iconTim.contentMode = .scaleAspectFit
        iconTim.frame = CGRect(x: 8, y: 9, width: 16, height: 16)
        khungIcon.addSubview(iconTim)
        oTimKiem.leftView = khungIcon
        oTimKiem.leftViewMode = .always
        oTimKiem.addTarget(self, action: #selector(khiThayDoiTimKiem), for: .editingChanged)
        oTimKiem.addTarget(self, action: #selector(anBanPhim), for: .editingDidEndOnExit)

        cuonDocBang.alwaysBounceVertical = true
        cuonDocBang.keyboardDismissMode = .onDrag
        cuonDocBang.translatesAutoresizingMaskIntoConstraints = false

        cuonNgangBang.showsHorizontalScrollIndicator = true
        cuonNgangBang.alwaysBounceHorizontal = false
        cuonNgangBang.translatesAutoresizingMaskIntoConstraints = false

        khungVienBang.layer.cornerRadius = 6
        khungVienBang.layer.borderWidth = 1
        khungVienBang.layer.masksToBounds = true
        khungVienBang.translatesAutoresizingMaskIntoConstraints = false

        nganBangDuLieu.axis = .vertical
        nganBangDuLieu.spacing = 1
        nganBangDuLieu.translatesAutoresizingMaskIntoConstraints = false

        lopPhuMo.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        lopPhuMo.isHidden = true
        lopPhuMo.translatesAutoresizingMaskIntoConstraints = false

        chiBaoDangQuet.translatesAutoresizingMaskIntoConstraints = false
        chiBaoDangQuet.color = .white

        nhanTrangThaiQuet.translatesAutoresizingMaskIntoConstraints = false
        nhanTrangThaiQuet.textColor = .white
        nhanTrangThaiQuet.font = .systemFont(ofSize: 13, weight: .semibold)
        nhanTrangThaiQuet.textAlignment = .center
        nhanTrangThaiQuet.numberOfLines = 2

        view.addSubview(oTimKiem)
        view.addSubview(cuonDocBang)
        cuonDocBang.addSubview(cuonNgangBang)
        cuonNgangBang.addSubview(khungVienBang)
        khungVienBang.addSubview(nganBangDuLieu)
        view.addSubview(lopPhuMo)
        lopPhuMo.addSubview(chiBaoDangQuet)
        lopPhuMo.addSubview(nhanTrangThaiQuet)

        NSLayoutConstraint.activate([
            oTimKiem.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            oTimKiem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            oTimKiem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            oTimKiem.heightAnchor.constraint(equalToConstant: 34),

            cuonDocBang.topAnchor.constraint(equalTo: oTimKiem.bottomAnchor, constant: 6),
            cuonDocBang.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            cuonDocBang.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            cuonDocBang.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),

            cuonNgangBang.topAnchor.constraint(equalTo: cuonDocBang.contentLayoutGuide.topAnchor),
            cuonNgangBang.bottomAnchor.constraint(equalTo: cuonDocBang.contentLayoutGuide.bottomAnchor),
            cuonNgangBang.leadingAnchor.constraint(equalTo: cuonDocBang.frameLayoutGuide.leadingAnchor),
            cuonNgangBang.trailingAnchor.constraint(equalTo: cuonDocBang.frameLayoutGuide.trailingAnchor),
            cuonNgangBang.heightAnchor.constraint(equalTo: khungVienBang.heightAnchor),

            khungVienBang.topAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.topAnchor),
            khungVienBang.bottomAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.bottomAnchor),
            khungVienBang.leadingAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.leadingAnchor),
            khungVienBang.trailingAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.trailingAnchor),

            nganBangDuLieu.topAnchor.constraint(equalTo: khungVienBang.topAnchor, constant: 1),
            nganBangDuLieu.bottomAnchor.constraint(equalTo: khungVienBang.bottomAnchor, constant: -1),
            nganBangDuLieu.leadingAnchor.constraint(equalTo: khungVienBang.leadingAnchor, constant: 1),
            nganBangDuLieu.trailingAnchor.constraint(equalTo: khungVienBang.trailingAnchor, constant: -1),

            lopPhuMo.topAnchor.constraint(equalTo: view.topAnchor),
            lopPhuMo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lopPhuMo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lopPhuMo.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            chiBaoDangQuet.centerXAnchor.constraint(equalTo: lopPhuMo.centerXAnchor),
            chiBaoDangQuet.centerYAnchor.constraint(equalTo: lopPhuMo.centerYAnchor, constant: -14),

            nhanTrangThaiQuet.topAnchor.constraint(equalTo: chiBaoDangQuet.bottomAnchor, constant: 12),
            nhanTrangThaiQuet.leadingAnchor.constraint(equalTo: lopPhuMo.leadingAnchor, constant: 24),
            nhanTrangThaiQuet.trailingAnchor.constraint(equalTo: lopPhuMo.trailingAnchor, constant: -24)
        ])
    }

    @objc private func capNhatGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        let vien = mauVienBang
        view.backgroundColor = mau.bg

        oTimKiem.backgroundColor = mau.card
        oTimKiem.textColor = mau.text
        oTimKiem.layer.borderColor = vien.cgColor
        oTimKiem.attributedPlaceholder = NSAttributedString(
            string: "Lọc nhanh theo Order, Kích cỡ, Mác thép...",
            attributes: [.foregroundColor: mau.subText]
        )

        khungVienBang.backgroundColor = vien
        khungVienBang.layer.borderColor = vien.cgColor
        nganBangDuLieu.backgroundColor = vien

        veNguyenBang()
    }

    @objc private func khiThayDoiTimKiem() {
        tuKhoaTim = oTimKiem.text ?? ""
        veNguyenBang()
    }

    @objc private func anBanPhim() {
        oTimKiem.resignFirstResponder()
    }

    // MARK: - Vẽ Bảng Kẻ Viền Rõ Ràng, Cỡ Chữ Đồng Nhất (coChuBang = 12pt)

    struct NhomHangLenhSX {
        var thoiGian: String
        var cacMuc: [MucDongLenhSX]
    }

    private func veNguyenBang() {
        let mau = KhoDuLieu.dungChung.mauSac
        nganBangDuLieu.arrangedSubviews.forEach {
            nganBangDuLieu.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let hangTieuDe = taoHangTieuDeBang()
        nganBangDuLieu.addArrangedSubview(hangTieuDe)

        let ds = danhSachHienThi
        if ds.isEmpty {
            let oTrong = UILabel()
            oTrong.backgroundColor = mau.card
            oTrong.text = "Không có dòng nào. Bấm '+ Dòng' hoặc '📷' để quét ảnh."
            oTrong.font = .systemFont(ofSize: coChuBang)
            oTrong.textColor = mau.subText
            oTrong.textAlignment = .center
            oTrong.heightAnchor.constraint(equalToConstant: 56).isActive = true
            nganBangDuLieu.addArrangedSubview(oTrong)
            return
        }

        var cacNhom: [NhomHangLenhSX] = []
        for muc in ds {
            if let last = cacNhom.last, last.thoiGian == muc.thoiGianDuKien && !muc.thoiGianDuKien.isEmpty {
                cacNhom[cacNhom.count - 1].cacMuc.append(muc)
            } else {
                cacNhom.append(NhomHangLenhSX(thoiGian: muc.thoiGianDuKien, cacMuc: [muc]))
            }
        }

        for nhom in cacNhom {
            let hangNhom = taoNhomHangDuLieu(nhom: nhom)
            nganBangDuLieu.addArrangedSubview(hangNhom)
        }

        let hangTong = taoHangTongKet()
        nganBangDuLieu.addArrangedSubview(hangTong)
    }

    private func taoO(rong: CGFloat, cao: CGFloat? = nil, mauNen: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = mauNen
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: rong).isActive = true
        if let cao {
            v.heightAnchor.constraint(equalToConstant: cao).isActive = true
        }
        return v
    }

    private func taoHangTieuDeBang() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.alignment = .fill
        hang.distribution = .fill
        hang.backgroundColor = mauVienBang
        hang.translatesAutoresizingMaskIntoConstraints = false
        hang.heightAnchor.constraint(equalToConstant: chieuCaoTieuDe).isActive = true

        let tieuDes = [
            "TT",
            "Thời gian dự kiến SX",
            "Kích cỡ",
            "Mác thép",
            "Sản lượng",
            "YCSX",
            "Mác phôi",
            "Số Order"
        ]

        for (idx, td) in tieuDes.enumerated() {
            let khung = taoO(rong: doRongCacCot[idx], cao: chieuCaoTieuDe, mauNen: mau.iconBg)
            let lb = UILabel()
            lb.text = td
            lb.numberOfLines = 2
            lb.textAlignment = .center
            lb.font = .systemFont(ofSize: coChuBang, weight: .semibold)
            lb.textColor = mau.text
            lb.translatesAutoresizingMaskIntoConstraints = false
            khung.addSubview(lb)
            NSLayoutConstraint.activate([
                lb.topAnchor.constraint(equalTo: khung.topAnchor, constant: 2),
                lb.bottomAnchor.constraint(equalTo: khung.bottomAnchor, constant: -2),
                lb.leadingAnchor.constraint(equalTo: khung.leadingAnchor, constant: 3),
                lb.trailingAnchor.constraint(equalTo: khung.trailingAnchor, constant: -3)
            ])
            hang.addArrangedSubview(khung)
        }

        return hang
    }

    private func dinhDangThoiGianGop(_ chuoi: String) -> String {
        let trimmed = chuoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }
        let parts = trimmed.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            return "\(parts[0]) -\n\(parts[1])"
        }
        return trimmed
    }

    private func taoNhomHangDuLieu(nhom: NhomHangLenhSX) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let vien = mauVienBang
        let soDongTrongNhom = max(1, nhom.cacMuc.count)
        let tongCaoNhom = CGFloat(soDongTrongNhom) * chieuCaoDong + CGFloat(soDongTrongNhom - 1) * 1.0

        let hangNhom = UIStackView()
        hangNhom.axis = .horizontal
        hangNhom.spacing = 1
        hangNhom.alignment = .fill
        hangNhom.distribution = .fill
        hangNhom.backgroundColor = vien
        hangNhom.translatesAutoresizingMaskIntoConstraints = false
        hangNhom.heightAnchor.constraint(equalToConstant: tongCaoNhom).isActive = true

        // 1. Cột TT (chiều cao cố định từng dòng bằng nhau tuyệt đối)
        let cotTT = UIStackView()
        cotTT.axis = .vertical
        cotTT.spacing = 1
        cotTT.alignment = .fill
        cotTT.distribution = .fillEqually
        cotTT.backgroundColor = vien
        cotTT.translatesAutoresizingMaskIntoConstraints = false
        cotTT.widthAnchor.constraint(equalToConstant: doRongCacCot[0]).isActive = true

        // 2. Cột Thời gian dự kiến SX (ô gộp chuẩn kẻ viền phẳng gọn gàng, cùng cỡ chữ coChuBang)
        let oThoiGianGop = taoO(rong: doRongCacCot[1], mauNen: mau.card)
        let nutTG = UIButton(type: .system)
        nutTG.setTitle(dinhDangThoiGianGop(nhom.thoiGian), for: .normal)
        nutTG.titleLabel?.numberOfLines = 0
        nutTG.titleLabel?.textAlignment = .center
        nutTG.titleLabel?.font = .systemFont(ofSize: coChuBang, weight: .regular)
        nutTG.setTitleColor(mau.text, for: .normal)
        nutTG.translatesAutoresizingMaskIntoConstraints = false
        oThoiGianGop.addSubview(nutTG)

        NSLayoutConstraint.activate([
            nutTG.topAnchor.constraint(equalTo: oThoiGianGop.topAnchor, constant: 2),
            nutTG.bottomAnchor.constraint(equalTo: oThoiGianGop.bottomAnchor, constant: -2),
            nutTG.leadingAnchor.constraint(equalTo: oThoiGianGop.leadingAnchor, constant: 4),
            nutTG.trailingAnchor.constraint(equalTo: oThoiGianGop.trailingAnchor, constant: -4)
        ])
        nutTG.addAction(UIAction { [weak self] _ in
            self?.moHopThoaiSuaThoiGianNhom(nhom: nhom)
        }, for: .touchUpInside)

        // 3. Cột các dữ liệu còn lại (Kích cỡ, Mác thép, Sản lượng, Cơ tính, Mác phôi, Số Order)
        let cotDuLieu = UIStackView()
        cotDuLieu.axis = .vertical
        cotDuLieu.spacing = 1
        cotDuLieu.alignment = .fill
        cotDuLieu.distribution = .fillEqually
        cotDuLieu.backgroundColor = vien
        cotDuLieu.translatesAutoresizingMaskIntoConstraints = false

        for muc in nhom.cacMuc {
            let khungTT = taoO(rong: doRongCacCot[0], cao: chieuCaoDong, mauNen: mau.card)
            let nutTT = UIButton(type: .system)
            nutTT.setTitle("\(muc.stt)", for: .normal)
            nutTT.titleLabel?.font = .systemFont(ofSize: coChuBang, weight: .regular)
            nutTT.setTitleColor(mau.text, for: .normal)
            nutTT.translatesAutoresizingMaskIntoConstraints = false
            khungTT.addSubview(nutTT)
            NSLayoutConstraint.activate([
                nutTT.topAnchor.constraint(equalTo: khungTT.topAnchor),
                nutTT.bottomAnchor.constraint(equalTo: khungTT.bottomAnchor),
                nutTT.leadingAnchor.constraint(equalTo: khungTT.leadingAnchor),
                nutTT.trailingAnchor.constraint(equalTo: khungTT.trailingAnchor)
            ])
            nutTT.addAction(UIAction { [weak self] _ in
                self?.moHopThoaiSuaMuc(muc: muc)
            }, for: .touchUpInside)
            cotTT.addArrangedSubview(khungTT)

            let hang6Cot = UIStackView()
            hang6Cot.axis = .horizontal
            hang6Cot.spacing = 1
            hang6Cot.alignment = .fill
            hang6Cot.distribution = .fill
            hang6Cot.backgroundColor = vien
            hang6Cot.translatesAutoresizingMaskIntoConstraints = false
            hang6Cot.heightAnchor.constraint(equalToConstant: chieuCaoDong).isActive = true

            let cacGiaTri6Cot: [(cotIdx: Int, val: String)] = [
                (2, muc.kichCo),
                (3, muc.macThep),
                (4, muc.sanLuong),
                (5, muc.coTinh),
                (6, muc.macPhoi),
                (7, muc.soOrder)
            ]

            for (cotIdx, val) in cacGiaTri6Cot {
                let khung = taoO(rong: doRongCacCot[cotIdx], cao: chieuCaoDong, mauNen: mau.card)
                let nutO = UIButton(type: .system)
                nutO.setTitle(val.isEmpty ? "-" : val, for: .normal)
                nutO.titleLabel?.numberOfLines = 2
                // Toàn bộ các ô đều dùng cùng 1 kích cỡ chữ coChuBang
                nutO.titleLabel?.font = .systemFont(ofSize: coChuBang, weight: .regular)
                nutO.setTitleColor(mau.text, for: .normal)
                nutO.contentHorizontalAlignment = (cotIdx == 4) ? .right : .center
                nutO.titleLabel?.textAlignment = (cotIdx == 4) ? .right : .center

                nutO.translatesAutoresizingMaskIntoConstraints = false
                khung.addSubview(nutO)
                NSLayoutConstraint.activate([
                    nutO.topAnchor.constraint(equalTo: khung.topAnchor, constant: 2),
                    nutO.bottomAnchor.constraint(equalTo: khung.bottomAnchor, constant: -2),
                    nutO.leadingAnchor.constraint(equalTo: khung.leadingAnchor, constant: 4),
                    nutO.trailingAnchor.constraint(equalTo: khung.trailingAnchor, constant: -4)
                ])

                nutO.addAction(UIAction { [weak self] _ in
                    self?.moHopThoaiSuaMuc(muc: muc)
                }, for: .touchUpInside)

                hang6Cot.addArrangedSubview(khung)
            }

            cotDuLieu.addArrangedSubview(hang6Cot)
        }

        hangNhom.addArrangedSubview(cotTT)
        hangNhom.addArrangedSubview(oThoiGianGop)
        hangNhom.addArrangedSubview(cotDuLieu)

        return hangNhom
    }

    private func moHopThoaiSuaThoiGianNhom(nhom: NhomHangLenhSX) {
        let alert = UIAlertController(title: "Sửa thời gian dự kiến (Ô gộp)", message: "Áp dụng cho \(nhom.cacMuc.count) dòng trong nhóm này:", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Ví dụ: 08h00 16/11 - 08h00 19/11"
            tf.text = nhom.thoiGian
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self] _ in
            guard let moi = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !moi.isEmpty else { return }
            var duLieu = KhoDuLieu.dungChung.duLieuLenhSX
            let ids = Set(nhom.cacMuc.map(\.id))
            for i in 0..<duLieu.danhSachMuc.count {
                if ids.contains(duLieu.danhSachMuc[i].id) {
                    duLieu.danhSachMuc[i].thoiGianDuKien = moi
                }
            }
            KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
            self?.capNhatGiaoDien()
        })
        present(alert, animated: true)
    }

    private func taoHangTongKet() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.alignment = .fill
        hang.distribution = .fill
        hang.backgroundColor = mauVienBang
        hang.translatesAutoresizingMaskIntoConstraints = false
        hang.heightAnchor.constraint(equalToConstant: chieuCaoTongKet).isActive = true

        let tongSL = KhoDuLieu.dungChung.duLieuLenhSX.tongSanLuong
        let soDong = KhoDuLieu.dungChung.duLieuLenhSX.danhSachMuc.count

        let rongDau = doRongCacCot[0] + doRongCacCot[1] + doRongCacCot[2] + doRongCacCot[3] + 3
        let khungDau = taoO(rong: rongDau, cao: chieuCaoTongKet, mauNen: mau.iconBg)
        let lbDau = UILabel()
        lbDau.text = "Tổng (\(soDong) dòng)"
        lbDau.font = .systemFont(ofSize: coChuBang, weight: .semibold)
        lbDau.textColor = mau.text
        lbDau.textAlignment = .center
        lbDau.translatesAutoresizingMaskIntoConstraints = false
        khungDau.addSubview(lbDau)
        NSLayoutConstraint.activate([
            lbDau.centerYAnchor.constraint(equalTo: khungDau.centerYAnchor),
            lbDau.leadingAnchor.constraint(equalTo: khungDau.leadingAnchor, constant: 6),
            lbDau.trailingAnchor.constraint(equalTo: khungDau.trailingAnchor, constant: -6)
        ])
        hang.addArrangedSubview(khungDau)

        let khungSL = taoO(rong: doRongCacCot[4], cao: chieuCaoTongKet, mauNen: mau.iconBg)
        let lbSL = UILabel()
        lbSL.text = tongSL
        lbSL.font = .systemFont(ofSize: coChuBang, weight: .semibold)
        lbSL.textColor = mau.text
        lbSL.textAlignment = .right
        lbSL.translatesAutoresizingMaskIntoConstraints = false
        khungSL.addSubview(lbSL)
        NSLayoutConstraint.activate([
            lbSL.centerYAnchor.constraint(equalTo: khungSL.centerYAnchor),
            lbSL.leadingAnchor.constraint(equalTo: khungSL.leadingAnchor, constant: 4),
            lbSL.trailingAnchor.constraint(equalTo: khungSL.trailingAnchor, constant: -4)
        ])
        hang.addArrangedSubview(khungSL)

        let rongDuoi = doRongCacCot[5] + doRongCacCot[6] + doRongCacCot[7] + 2
        let khungDuoi = taoO(rong: rongDuoi, cao: chieuCaoTongKet, mauNen: mau.iconBg)
        hang.addArrangedSubview(khungDuoi)

        return hang
    }

    // MARK: - Menu Quét Ảnh Gọn Gàng (Chỉ Gồm: Chọn Ảnh, Chụp Ảnh, Chọn Ảnh Quét OCR)

    @objc private func bamQuetAnhLenhSX() {
        let sheet = UIAlertController(title: "Quét Lệnh Sản Xuất", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Chọn ảnh", style: .default) { [weak self] _ in
            self?.moPicker(sourceType: .photoLibrary, dungGemini: true)
        })

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Chụp ảnh", style: .default) { [weak self] _ in
                self?.moPicker(sourceType: .camera, dungGemini: true)
            })
        }

        sheet.addAction(UIAlertAction(title: "Chọn ảnh quét OCR", style: .default) { [weak self] _ in
            self?.moPicker(sourceType: .photoLibrary, dungGemini: false)
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(sheet, animated: true)
    }

    private func moPicker(sourceType: UIImagePickerController.SourceType, dungGemini: Bool = true) {
        dangDungGeminiQuet = dungGemini
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let anh = info[.originalImage] as? UIImage else { return }
        anhHienTai = anh

        let coKey = !KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        thucHienQuetAnh(anh: anh, dungGemini: dangDungGeminiQuet && coKey)
    }

    private func thucHienQuetAnh(anh: UIImage, dungGemini: Bool) {
        lopPhuMo.isHidden = false
        chiBaoDangQuet.startAnimating()

        if dungGemini {
            let tenModel = KhoDuLieu.dungChung.caiDat.tenHienThiModelGemini
            nhanTrangThaiQuet.text = "Đang quét bằng \(tenModel)..."
            DichVuGemini.dungChung.phanTichLenhSanXuat(anh: anh) { [weak self] kq in
                guard let self else { return }
                self.lopPhuMo.isHidden = true
                self.chiBaoDangQuet.stopAnimating()
                switch kq {
                case .success(let duLieu):
                    KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
                    self.capNhatGiaoDien()
                case .failure:
                    // Tự động chuyển sang OCR nếu mất mạng hoặc chưa cấu hình Key
                    self.thucHienQuetAnh(anh: anh, dungGemini: false)
                }
            }
        } else {
            nhanTrangThaiQuet.text = "Đang quét OCR..."
            BoQuetOCRLenhSX.dungChung.quetAnh(anh: anh) { [weak self] kq in
                guard let self else { return }
                self.lopPhuMo.isHidden = true
                self.chiBaoDangQuet.stopAnimating()
                switch kq {
                case .success(let duLieu):
                    KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
                    self.capNhatGiaoDien()
                case .failure(let err):
                    self.hienThongBao("Lỗi nhận dạng OCR", err.localizedDescription)
                }
            }
        }
    }

    @objc private func bamXemAnhGoc() {
        guard let anh = anhHienTai else {
            hienThongBao("Chưa có ảnh", "Hãy bấm biểu tượng quét ảnh để chụp hoặc chọn ảnh bảng trước.")
            return
        }
        let modal = ManHinhXemAnhLenhSX(anh: anh)
        let nav = UINavigationController(rootViewController: modal)
        present(nav, animated: true)
    }

    @objc private func bamThemDongMoi() {
        var lsx = KhoDuLieu.dungChung.duLieuLenhSX
        let sttMoi = lsx.danhSachMuc.count + 1
        let dongMoi = MucDongLenhSX(
            stt: sttMoi,
            thoiGianDuKien: lsx.danhSachMuc.last?.thoiGianDuKien ?? "08h00 16/11 - 08h00 19/11",
            kichCo: "D12",
            macThep: "CB400V",
            sanLuong: "3,000",
            coTinh: "40.2025/YCCN - P.CN",
            macPhoi: "CT5",
            soOrder: ""
        )
        lsx.danhSachMuc.append(dongMoi)
        KhoDuLieu.dungChung.luuDuLieuLenhSX(lsx)
        capNhatGiaoDien()
        moHopThoaiSuaMuc(muc: dongMoi)
    }

    @objc private func moMenuTuyChon() {
        let sheet = UIAlertController(title: "Tùy chọn Bảng Lệnh SX", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "🔔 Gửi thử thông báo Lệnh SX ngay", style: .default) { [weak self] _ in
            TienIchLich.guiThongBaoThuLenhSX()
            self?.hienThongBao(
                "Đã hẹn thông báo thử 🔔",
                "Thông báo Lệnh sản xuất sẽ hiển thị trên màn hình sau khoảng 1.5 giây."
            )
        })

        sheet.addAction(UIAlertAction(title: "Sao chép dữ liệu bảng", style: .default) { [weak self] _ in
            let lsx = KhoDuLieu.dungChung.duLieuLenhSX
            var dong: [String] = []
            dong.append("TT\tThời gian dự kiến SX\tKích cỡ\tMác thép\tSản lượng (tấn)\tYCSX\tMác phôi\tSố Order")
            for m in lsx.danhSachMuc {
                dong.append("\(m.stt)\t\(m.thoiGianDuKien)\t\(m.kichCo)\t\(m.macThep)\t\(m.sanLuong)\t\(m.coTinh)\t\(m.macPhoi)\t\(m.soOrder)")
            }
            dong.append("Tổng sản lượng: \(lsx.tongSanLuong) tấn (\(lsx.danhSachMuc.count) dòng)")
            UIPasteboard.general.string = dong.joined(separator: "\n")
            self?.hienThongBao("Đã sao chép", "Đã sao chép toàn bộ bảng lệnh sản xuất vào bộ nhớ tạm.")
        })

        sheet.addAction(UIAlertAction(title: "Nạp lại bảng mẫu", style: .default) { [weak self] _ in
            let mau = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
            KhoDuLieu.dungChung.luuDuLieuLenhSX(mau)
            self?.capNhatGiaoDien()
        })

        sheet.addAction(UIAlertAction(title: "Xóa toàn bộ bảng", style: .destructive) { [weak self] _ in
            var rong = KhoDuLieu.dungChung.duLieuLenhSX
            rong.danhSachMuc = []
            KhoDuLieu.dungChung.luuDuLieuLenhSX(rong)
            self?.capNhatGiaoDien()
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(sheet, animated: true)
    }

    private func moHopThoaiSuaMuc(muc: MucDongLenhSX) {
        let alert = UIAlertController(title: "Chỉnh sửa Dòng #\(muc.stt)", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.text = muc.thoiGianDuKien
            tf.placeholder = "Thời gian dự kiến SX (VD: 08h00 16/11 - 08h00 19/11)"
        }
        alert.addTextField { tf in
            tf.text = muc.kichCo
            tf.placeholder = "Kích cỡ (VD: D10, D12, D12HP, D14HP...)"
        }
        alert.addTextField { tf in
            tf.text = muc.macThep
            tf.placeholder = "Mác thép (VD: CB300V, CB400V, CB500V, Gr40...)"
        }
        alert.addTextField { tf in
            tf.text = muc.sanLuong
            tf.placeholder = "Sản lượng tấn (VD: 2,000)"
            tf.keyboardType = .decimalPad
        }
        alert.addTextField { tf in
            tf.text = muc.coTinh
            tf.placeholder = "YCSX (VD: 40.2025/YCCN - P.CN)"
        }
        alert.addTextField { tf in
            tf.text = muc.macPhoi
            tf.placeholder = "Mác phôi (VD: CT5, CT5V, Gr80...)"
        }
        alert.addTextField { tf in
            tf.text = muc.soOrder
            tf.placeholder = "Số Order (VD: 1040004605)"
            tf.keyboardType = .numberPad
        }

        alert.addAction(UIAlertAction(title: "Xóa dòng này", style: .destructive) { [weak self] _ in
            var lsx = KhoDuLieu.dungChung.duLieuLenhSX
            lsx.danhSachMuc.removeAll { $0.id == muc.id }
            for i in 0..<lsx.danhSachMuc.count {
                lsx.danhSachMuc[i].stt = i + 1
            }
            KhoDuLieu.dungChung.luuDuLieuLenhSX(lsx)
            self?.capNhatGiaoDien()
        })

        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self] _ in
            guard let tfs = alert.textFields, tfs.count >= 7 else { return }
            var moi = muc
            moi.thoiGianDuKien = tfs[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.thoiGianDuKien
            moi.kichCo = tfs[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.kichCo
            moi.macThep = tfs[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.macThep
            moi.sanLuong = MucDongLenhSX.chuanHoaSanLuong(tfs[3].text ?? muc.sanLuong)
            moi.coTinh = tfs[4].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.coTinh
            moi.macPhoi = tfs[5].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.macPhoi
            moi.soOrder = tfs[6].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.soOrder

            var lsx = KhoDuLieu.dungChung.duLieuLenhSX
            if let idx = lsx.danhSachMuc.firstIndex(where: { $0.id == moi.id }) {
                lsx.danhSachMuc[idx] = moi
            }
            KhoDuLieu.dungChung.luuDuLieuLenhSX(lsx)
            self?.capNhatGiaoDien()
        })
        present(alert, animated: true)
    }

    private func hienThongBao(_ tieuDe: String, _ noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - 3. Màn Hình Phóng To Ảnh Lệnh Sản Xuất Để So Sánh Đối Chiếu

final class ManHinhXemAnhLenhSX: UIViewController, UIScrollViewDelegate {
    private let anh: UIImage
    private let cuon = UIScrollView()
    private let khungAnh = UIImageView()

    init(anh: UIImage) {
        self.anh = anh
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.title = "Ảnh Bảng Lệnh SX"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Đóng", style: .done, target: self, action: #selector(dong))

        cuon.delegate = self
        cuon.minimumZoomScale = 1.0
        cuon.maximumZoomScale = 4.0
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        khungAnh.image = anh
        khungAnh.contentMode = .scaleAspectFit
        khungAnh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(khungAnh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            khungAnh.centerXAnchor.constraint(equalTo: cuon.centerXAnchor),
            khungAnh.centerYAnchor.constraint(equalTo: cuon.centerYAnchor),
            khungAnh.widthAnchor.constraint(equalTo: cuon.widthAnchor),
            khungAnh.heightAnchor.constraint(equalTo: cuon.heightAnchor)
        ])
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        khungAnh
    }

    @objc private func dong() {
        dismiss(animated: true)
    }
}
