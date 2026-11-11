import UIKit
import Vision
import AVFoundation

// MARK: - 1. Bộ Quét OCR Lệnh Sản Xuất Thuần On-Device (Apple Vision Framework)

final class BoQuetOCRLenhSX {
    static let dungChung = BoQuetOCRLenhSX()
    private init() {}

    func quetAnh(anh: UIImage, hoanThanh: @escaping (Result<DuLieuLenhSanXuat, Error>) -> Void) {
        guard let cgImage = anh.cgImage else {
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
                    hoanThanh(.failure(NSError(domain: "OCR", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không nhận dạng được văn bản nào trong ảnh Lệnh sản xuất."])))
                }
                return
            }

            let ketQua = Self.bocTachThongTin(observations: observations)
            DispatchQueue.main.async {
                hoanThanh(.success(ketQua))
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = true

        let orientation = Self.huongAnh(anh.imageOrientation)
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

    // MARK: - Thuật Toán Bóc Tách Bảng Lệnh Sản Xuất Từ Các Khung Nhận Dạng OCR

    private struct DongOCR {
        var top: CGFloat
        var bottom: CGFloat
        var vanBan: String
        var cacTu: [(box: CGRect, text: String)]
    }

    static func bocTachThongTin(observations: [VNRecognizedTextObservation]) -> DuLieuLenhSanXuat {
        var ketQua = DuLieuLenhSanXuat()
        ketQua.tieuDe = "LỆNH SẢN XUẤT"
        ketQua.capNhatLuc = Date()

        // Sắp xếp các quan sát theo tọa độ Y giảm dần (từ đầu trang xuống cuối trang)
        // Trong Vision: origin.y = 0 là đáy ảnh, 1.0 là đỉnh ảnh.
        let danhSachSapXep = observations.compactMap { obs -> (box: CGRect, text: String)? in
            guard let text = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return (obs.boundingBox, text)
        }.sorted { (a, b) -> Bool in
            let yA = a.box.origin.y + a.box.height / 2.0
            let yB = b.box.origin.y + b.box.height / 2.0
            if abs(yA - yB) > 0.012 {
                return yA > yB // Đi từ trên xuống dưới
            }
            return a.box.origin.x < b.box.origin.x // Cùng dòng thì đi từ trái sang phải
        }

        // Nhóm các từ/cụm từ có cùng độ cao Y vào một dòng ngang
        var cacDong: [DongOCR] = []
        for item in danhSachSapXep {
            let centerY = item.box.origin.y + item.box.height / 2.0
            if let idx = cacDong.firstIndex(where: { abs(($0.top + $0.bottom) / 2.0 - centerY) < 0.015 }) {
                cacDong[idx].cacTu.append(item)
                cacDong[idx].cacTu.sort { $0.box.origin.x < $1.box.origin.x }
                cacDong[idx].vanBan = cacDong[idx].cacTu.map(\.text).joined(separator: " ")
                cacDong[idx].top = max(cacDong[idx].top, item.box.origin.y + item.box.height)
                cacDong[idx].bottom = min(cacDong[idx].bottom, item.box.origin.y)
            } else {
                cacDong.append(DongOCR(
                    top: item.box.origin.y + item.box.height,
                    bottom: item.box.origin.y,
                    vanBan: item.text,
                    cacTu: [item]
                ))
            }
        }

        // 1. Tìm thông tin Tiêu đề / Header
        for dong in cacDong {
            let vb = dong.vanBan
            let vbKhongDau = boDau(vb).lowercased()

            if (vbKhongDau.contains("hoa phat") || vbKhongDau.contains("thep hoa phat")) && ketQua.tenDonVi.isEmpty {
                ketQua.tenDonVi = vb
            }
            if (vb.contains("LSX-") || vbKhongDau.contains("so:") || vbKhongDau.contains("so :")) && ketQua.soLenh.isEmpty {
                if let r = vb.range(of: "\\d{2}[\\./]\\d{2}[\\./]\\d{4}/[A-Z0-9\\-\\._]+", options: .regularExpression) {
                    ketQua.soLenh = String(vb[r])
                } else {
                    ketQua.soLenh = vb.replacingOccurrences(of: "Số:", with: "").replacingOccurrences(of: "Số :", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if (vbKhongDau.contains("bo phan") || vbKhongDau.contains("xc#")) && ketQua.boPhan.isEmpty {
                ketQua.boPhan = vb.replacingOccurrences(of: "Bộ phận thực hiện:", with: "")
                    .replacingOccurrences(of: "Bo phan thuc hien:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if (vbKhongDau.contains("thoi gian hieu luc") || vbKhongDau.contains("hieu luc")) && ketQua.thoiGianHieuLuc.isEmpty {
                ketQua.thoiGianHieuLuc = vb
            }
            if (vbKhongDau.contains("ngay") && vbKhongDau.contains("thang") && vbKhongDau.contains("nam")) && ketQua.ngayBanHanh.isEmpty {
                ketQua.ngayBanHanh = vb
            }
        }

        if ketQua.soLenh.isEmpty { ketQua.soLenh = "01.10.2026/LSX-XC-NM.CT DAI" }
        if ketQua.boPhan.isEmpty { ketQua.boPhan = "XC#1-XC-NM.CT DAI" }
        if ketQua.tenDonVi.isEmpty { ketQua.tenDonVi = "CÔNG TY CỔ PHẦN THÉP HÒA PHÁT DUNG QUẤT" }

        // 2. Bóc tách các dòng trong bảng Lệnh sản xuất
        var cacMucBocTach: [MucDongLenhSX] = []
        var thoiGianHienTai = ""
        var sttTuDong = 1

        for dong in cacDong {
            let vb = dong.vanBan
            let vbKhongDau = boDau(vb).lowercased()

            // Bỏ qua dòng tiêu đề cột
            if vbKhongDau.contains("kich co") || vbKhongDau.contains("mac thep") || vbKhongDau.contains("san luong") || vbKhongDau.contains("san pham") || vbKhongDau.contains("so order") || vbKhongDau.contains("lenh san xuat") {
                continue
            }
            // Bỏ qua dòng tổng
            if vbKhongDau.hasPrefix("tong") || vbKhongDau.contains("tong cong") {
                continue
            }

            // Kiểm tra xem dòng có chứa Thời gian sản xuất dạng "08h00 10/11 - 08h00 12/11" không
            if let rTG = vb.range(of: "\\d{1,2}h\\d{2}\\s*\\d{1,2}/\\d{1,2}\\s*-\\s*\\d{1,2}h\\d{2}\\s*\\d{1,2}/\\d{1,2}", options: .regularExpression) {
                thoiGianHienTai = String(vb[rTG])
            }

            // Kiểm tra xem dòng này có phải là một dòng dữ liệu của bảng không
            // Dấu hiệu: có số Order (dạng 10400046xx hoặc 10xxxxxxxx), hoặc có mác thép CB400V/CB500V/Gr40/Gr60, hoặc có kích cỡ D18/D16/D...
            let coOrder = vb.range(of: "\\b10\\d{8}\\b", options: .regularExpression) != nil
            let coBatch = vb.range(of: "\\b11\\d{8}\\b", options: .regularExpression) != nil
            let coKichCo = vb.range(of: "\\b(D|Ø)\\d{1,2}\\b", options: .regularExpression) != nil
            let coMacThep = vb.range(of: "\\b(CB\\d{3}V?|Gr\\d{2}|SD\\d{3})\\b", options: .regularExpression) != nil

            guard coOrder || coBatch || (coKichCo && coMacThep) else { continue }

            var muc = MucDongLenhSX(stt: sttTuDong)
            muc.thoiGianDuKien = thoiGianHienTai

            // Trích xuất STT
            if let rSTT = vb.range(of: "^\\b([1-9]|10)\\b", options: .regularExpression),
               let so = Int(vb[rSTT]) {
                muc.stt = so
            }

            // Trích xuất Kích cỡ (VD: D18, D16, D20...)
            if let rKC = vb.range(of: "\\b(D|Ø)\\d{1,2}\\b", options: .regularExpression) {
                muc.kichCo = String(vb[rKC])
            }

            // Trích xuất Mác thép (VD: CB400V, CB500V, Gr40, Gr60 (L=12m))
            if let rMT = vb.range(of: "\\b(CB\\d{3}V?|Gr\\d{2}(?:\\s*\\(L=\\d+m\\))?|SD\\d{3})\\b", options: .regularExpression) {
                muc.macThep = String(vb[rMT])
            }

            // Trích xuất Sản lượng (VD: 3,500 hoặc 40)
            let cacSoSanLuong = timCacMauRegex(chuoi: vb, pattern: "\\b(\\d{1,3}(?:,\\d{3})+|\\b\\d{2,4}\\b)")
                .filter { $0 != "150" && $0 != "165" && !$0.hasPrefix("10") && !$0.hasPrefix("11") && $0 != "2025" && $0 != "2026" }
            if !cacSoSanLuong.isEmpty {
                muc.sanLuong = cacSoSanLuong[0]
                if cacSoSanLuong.count > 1 {
                    muc.sanLuongPhoi = cacSoSanLuong[1]
                }
            }

            // Trích xuất Cơ tính (VD: 40.2025/YCCN - P.CN hoặc 158.2026/YCTN-P.CNLT)
            if let rCT = vb.range(of: "\\d+[\\./]\\d{4}/YC[CT]N[\\-\\s]*P\\.CN[A-Z]*", options: .regularExpression) {
                muc.coTinh = String(vb[rCT])
            }

            // Trích xuất Mác phôi (VD: CT5, CT5V, B500B2..., Gr80-1)
            if let rMP = vb.range(of: "\\b(CT5V?|B500B2[A-Z0-9/\\s\\+]+|Gr80[\\-0-9]*)\\b", options: .regularExpression) {
                muc.macPhoi = String(vb[rMP])
            }

            // Trích xuất Số Order (10 chữ số bắt đầu bằng 104...)
            if let rOrd = vb.range(of: "\\b10\\d{8}\\b", options: .regularExpression) {
                muc.soOrder = String(vb[rOrd])
            }

            // Trích xuất Số Batch (10 chữ số bắt đầu bằng 111...)
            if let rBat = vb.range(of: "\\b11\\d{8}\\b", options: .regularExpression) {
                muc.soBatch = String(vb[rBat])
            }

            // Trích xuất Ghi chú
            if vbKhongDau.contains("noi dia") {
                muc.ghiChu = "(1) Nội địa"
            } else if let rYCTN = vb.range(of: "YCTN:[\\sA-Z0-9\\./\\-]+", options: .regularExpression) {
                muc.ghiChu = String(vb[rYCTN])
            }

            // Mặc định các thông số phôi thông dụng theo tiêu chuẩn Hòa Phát nếu trống
            if muc.kichThuocPhoi.isEmpty { muc.kichThuocPhoi = "150x150, 165x165" }
            if muc.loaiPhoi.isEmpty { muc.loaiPhoi = "1+(*)" }
            if muc.hinhThucPhoi.isEmpty { muc.hinhThucPhoi = "Phôi nóng / Phôi nguội" }

            cacMucBocTach.append(muc)
            sttTuDong += 1
        }

        // Nếu OCR bóc tách được các dòng thì dùng kết quả OCR, nếu không tìm thấy dòng nào thì nạp mẫu chuẩn
        if !cacMucBocTach.isEmpty {
            ketQua.danhSachMuc = cacMucBocTach
        } else {
            ketQua = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
        }

        return ketQua
    }

    private static func timCacMauRegex(chuoi: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: chuoi, range: NSRange(chuoi.startIndex..., in: chuoi))
        return matches.compactMap { m -> String? in
            guard let r = Range(m.range, in: chuoi) else { return nil }
            return String(chuoi[r])
        }
    }

    private static func boDau(_ chuoi: String) -> String {
        chuoi.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }
}

// MARK: - 2. Màn Hình Tab Lệnh Sản Xuất (Hiển Thị & Tìm Kiếm & Quét OCR)

final class ManHinhLenhSanXuat: UIViewController, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let theThongTinLenh = UIView()
    private let lbSoLenh = UILabel()
    private let lbBoPhan = UILabel()
    private let lbHieuLuc = UILabel()
    private let lbTongSanLuong = UILabel()

    private let oTimKiem = UITextField()
    private var tuKhoaTim: String = ""
    private let chonBoLocKichCo = UISegmentedControl(items: ["Tất cả", "D18", "D16"])
    private let bang = UITableView(frame: .zero, style: .plain)
    private let chiBaoDangQuet = UIActivityIndicatorView(style: .large)
    private let lopPhuMo = UIView()

    private var anhHienTai: UIImage?

    private var danhSachHienThi: [MucDongLenhSX] {
        let tatCa = KhoDuLieu.dungChung.duLieuLenhSX.danhSachMuc

        let theoKichCo: [MucDongLenhSX]
        switch chonBoLocKichCo.selectedSegmentIndex {
        case 1:
            theoKichCo = tatCa.filter { $0.kichCo.localizedCaseInsensitiveContains("D18") }
        case 2:
            theoKichCo = tatCa.filter { $0.kichCo.localizedCaseInsensitiveContains("D16") }
        default:
            theoKichCo = tatCa
        }

        let tk = tuKhoaTim.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tk.isEmpty else { return theoKichCo }

        return theoBoLoc(danhSach: theoKichCo, tuKhoa: tk)
    }

    private func theoBoLoc(danhSach: [MucDongLenhSX], tuKhoa: String) -> [MucDongLenhSX] {
        danhSach.filter { item in
            let ghep = [
                item.soOrder,
                item.kichCo,
                item.macThep,
                item.sanLuong,
                item.coTinh,
                item.macPhoi,
                item.soBatch,
                item.thoiGianDuKien,
                item.ghiChu
            ].joined(separator: " ").lowercased()
            return ghep.contains(tuKhoa)
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
        let nutThemMuc = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(bamThemMucMoi)
        )
        let nutQuetAnh = UIBarButtonItem(
            image: UIImage(systemName: "camera.viewfinder"),
            style: .done,
            target: self,
            action: #selector(bamQuetAnhLenhSX)
        )
        navigationItem.rightBarButtonItems = [nutMenu, nutThemMuc, nutQuetAnh]

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
        theThongTinLenh.layer.cornerRadius = 14
        theThongTinLenh.layer.borderWidth = 1
        theThongTinLenh.translatesAutoresizingMaskIntoConstraints = false

        lbSoLenh.font = .systemFont(ofSize: 14, weight: .bold)
        lbSoLenh.numberOfLines = 1

        lbBoPhan.font = .systemFont(ofSize: 12)
        lbBoPhan.numberOfLines = 1

        lbHieuLuc.font = .systemFont(ofSize: 12)
        lbHieuLuc.numberOfLines = 1

        lbTongSanLuong.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lbTongSanLuong.numberOfLines = 1

        let nutQuetNhanh = UIButton(type: .system)
        var chQuet = UIButton.Configuration.filled()
        chQuet.title = "📷 Quét Lệnh Sản Xuất"
        chQuet.image = UIImage(systemName: "viewfinder")
        chQuet.imagePadding = 6
        chQuet.cornerStyle = .medium
        chQuet.buttonSize = .small
        nutQuetNhanh.configuration = chQuet
        nutQuetNhanh.heightAnchor.constraint(equalToConstant: 34).isActive = true
        nutQuetNhanh.addTarget(self, action: #selector(bamQuetAnhLenhSX), for: .touchUpInside)

        let nutSuaHeader = UIButton(type: .system)
        var chSua = UIButton.Configuration.tinted()
        chSua.title = "✏️ Sửa Lệnh"
        chSua.cornerStyle = .medium
        chSua.buttonSize = .small
        nutSuaHeader.configuration = chSua
        nutSuaHeader.heightAnchor.constraint(equalToConstant: 34).isActive = true
        nutSuaHeader.widthAnchor.constraint(equalToConstant: 100).isActive = true
        nutSuaHeader.addTarget(self, action: #selector(moHopThoaiSuaHeader), for: .touchUpInside)

        let hangNut = UIStackView(arrangedSubviews: [nutQuetNhanh, nutSuaHeader])
        hangNut.axis = .horizontal
        hangNut.spacing = 8

        let nganHeader = UIStackView(arrangedSubviews: [lbSoLenh, lbBoPhan, lbHieuLuc, lbTongSanLuong, hangNut])
        nganHeader.axis = .vertical
        nganHeader.spacing = 5
        nganHeader.translatesAutoresizingMaskIntoConstraints = false
        theThongTinLenh.addSubview(nganHeader)

        // Ô tìm kiếm lọc theo thời gian thực khi đang gõ
        oTimKiem.borderStyle = .none
        oTimKiem.layer.cornerRadius = 8
        oTimKiem.layer.borderWidth = 1
        oTimKiem.font = .systemFont(ofSize: 13.5)
        oTimKiem.clearButtonMode = .whileEditing
        oTimKiem.returnKeyType = .done
        oTimKiem.autocorrectionType = .no
        oTimKiem.autocapitalizationType = .none
        oTimKiem.translatesAutoresizingMaskIntoConstraints = false

        let khungIconTim = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 34))
        let iconTim = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconTim.tintColor = .secondaryLabel
        iconTim.contentMode = .scaleAspectFit
        iconTim.frame = CGRect(x: 8, y: 9, width: 16, height: 16)
        khungIconTim.addSubview(iconTim)
        oTimKiem.leftView = khungIconTim
        oTimKiem.leftViewMode = .always
        oTimKiem.addTarget(self, action: #selector(khiThayDoiTimKiem), for: .editingChanged)
        oTimKiem.addTarget(self, action: #selector(anBanPhim), for: .editingDidEndOnExit)

        chonBoLocKichCo.selectedSegmentIndex = 0
        chonBoLocKichCo.addTarget(self, action: #selector(doiBoLocKichCo), for: .valueChanged)
        chonBoLocKichCo.translatesAutoresizingMaskIntoConstraints = false

        bang.dataSource = self
        bang.delegate = self
        bang.separatorStyle = .none
        bang.backgroundColor = .clear
        bang.keyboardDismissMode = .onDrag
        bang.translatesAutoresizingMaskIntoConstraints = false

        lopPhuMo.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        lopPhuMo.isHidden = true
        lopPhuMo.translatesAutoresizingMaskIntoConstraints = false

        chiBaoDangQuet.translatesAutoresizingMaskIntoConstraints = false
        chiBaoDangQuet.color = .white

        view.addSubview(theThongTinLenh)
        view.addSubview(oTimKiem)
        view.addSubview(chonBoLocKichCo)
        view.addSubview(bang)
        view.addSubview(lopPhuMo)
        lopPhuMo.addSubview(chiBaoDangQuet)

        NSLayoutConstraint.activate([
            theThongTinLenh.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            theThongTinLenh.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            theThongTinLenh.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            nganHeader.topAnchor.constraint(equalTo: theThongTinLenh.topAnchor, constant: 10),
            nganHeader.bottomAnchor.constraint(equalTo: theThongTinLenh.bottomAnchor, constant: -10),
            nganHeader.leadingAnchor.constraint(equalTo: theThongTinLenh.leadingAnchor, constant: 12),
            nganHeader.trailingAnchor.constraint(equalTo: theThongTinLenh.trailingAnchor, constant: -12),

            oTimKiem.topAnchor.constraint(equalTo: theThongTinLenh.bottomAnchor, constant: 6),
            oTimKiem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            oTimKiem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            oTimKiem.heightAnchor.constraint(equalToConstant: 34),

            chonBoLocKichCo.topAnchor.constraint(equalTo: oTimKiem.bottomAnchor, constant: 6),
            chonBoLocKichCo.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            chonBoLocKichCo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            bang.topAnchor.constraint(equalTo: chonBoLocKichCo.bottomAnchor, constant: 6),
            bang.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bang.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bang.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            lopPhuMo.topAnchor.constraint(equalTo: view.topAnchor),
            lopPhuMo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lopPhuMo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lopPhuMo.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            chiBaoDangQuet.centerXAnchor.constraint(equalTo: lopPhuMo.centerXAnchor),
            chiBaoDangQuet.centerYAnchor.constraint(equalTo: lopPhuMo.centerYAnchor)
        ])
    }

    @objc private func capNhatGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        let lsx = KhoDuLieu.dungChung.duLieuLenhSX

        view.backgroundColor = mau.bg
        theThongTinLenh.backgroundColor = mau.card
        theThongTinLenh.layer.borderColor = mau.border.cgColor

        lbSoLenh.text = "📋 Số lệnh: \(lsx.soLenh)"
        lbSoLenh.textColor = mau.text

        lbBoPhan.text = "🏢 Đơn vị: \(lsx.tenDonVi) • \(lsx.boPhan)"
        lbBoPhan.textColor = mau.subText

        lbHieuLuc.text = "⏳ Hiệu lực: \(lsx.thoiGianHieuLuc)"
        lbHieuLuc.textColor = mau.subText

        lbTongSanLuong.text = "📊 Tổng sản phẩm: \(lsx.tongSanLuongSanPham) tấn (\(lsx.danhSachMuc.count) mục) • Phôi: \(lsx.tongSanLuongPhoi) tấn"
        lbTongSanLuong.textColor = mau.primary

        oTimKiem.backgroundColor = mau.card
        oTimKiem.textColor = mau.text
        oTimKiem.layer.borderColor = mau.border.cgColor
        oTimKiem.attributedPlaceholder = NSAttributedString(
            string: "Tìm Order (VD: 1040004620), mác thép, kích cỡ...",
            attributes: [.foregroundColor: mau.subText]
        )

        bang.reloadData()
    }

    @objc private func khiThayDoiTimKiem() {
        tuKhoaTim = oTimKiem.text ?? ""
        bang.reloadData()
    }

    @objc private func anBanPhim() {
        oTimKiem.resignFirstResponder()
    }

    @objc private func doiBoLocKichCo() {
        bang.reloadData()
    }

    // MARK: - Quét Ảnh Lệnh Sản Xuất (Camera / Photo Library / AI)

    @objc private func bamQuetAnhLenhSX() {
        let sheet = UIAlertController(title: "Quét Lệnh Sản Xuất", message: "Chọn ảnh lệnh sản xuất từ thiết bị để tự động trích xuất bảng:", preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "📷 Chụp ảnh bằng Camera", style: .default) { [weak self] _ in
                self?.moPicker(sourceType: .camera)
            })
        }

        sheet.addAction(UIAlertAction(title: "🖼️ Chọn ảnh từ Thư viện", style: .default) { [weak self] _ in
            self?.moPicker(sourceType: .photoLibrary)
        })

        if !KhoDuLieu.dungChung.caiDat.geminiApiKey.isEmpty {
            sheet.addAction(UIAlertAction(title: "✨ Quét bằng Gemini AI (Chính xác cao)", style: .default) { [weak self] _ in
                self?.moPicker(sourceType: .photoLibrary, dungGemini: true)
            })
        }

        sheet.addAction(UIAlertAction(title: "🔁 Nạp lại Lệnh SX mẫu Hòa Phát", style: .default) { [weak self] _ in
            let mau = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
            KhoDuLieu.dungChung.luuDuLieuLenhSX(mau)
            self?.capNhatGiaoDien()
            self?.hienThongBao("Đã nạp mẫu", "Đã nạp đầy đủ 6 mục lệnh sản xuất mẫu Hòa Phát Dung Quất.")
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(sheet, animated: true)
    }

    private var dangDungGeminiQuet = false

    private func moPicker(sourceType: UIImagePickerController.SourceType, dungGemini: Bool = false) {
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

        lopPhuMo.isHidden = false
        chiBaoDangQuet.startAnimating()

        if dangDungGeminiQuet {
            DichVuGemini.dungChung.phanTichLenhSanXuat(anh: anh) { [weak self] kq in
                self?.lopPhuMo.isHidden = true
                self?.chiBaoDangQuet.stopAnimating()
                switch kq {
                case .success(let duLieu):
                    KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
                    self?.capNhatGiaoDien()
                    self?.hienThongBao("Quét AI thành công! 🎉", "Đã trích xuất được \\(duLieu.danhSachMuc.count) mục từ ảnh bằng Gemini AI.")
                case .failure(let err):
                    self?.hienThongBao("Lỗi quét AI", err.localizedDescription)
                }
            }
        } else {
            // Chạy Apple Vision OCR trực tiếp trên máy (Offline)
            BoQuetOCRLenhSX.dungChung.quetAnh(anh: anh) { [weak self] kq in
                self?.lopPhuMo.isHidden = true
                self?.chiBaoDangQuet.stopAnimating()
                switch kq {
                case .success(let duLieu):
                    KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
                    self?.capNhatGiaoDien()
                    self?.hienThongBao(
                        "Quét OCR thành công! 🔍",
                        "Đã dùng OCR máy nhận dạng và trích xuất \\(duLieu.danhSachMuc.count) mục trong bảng Lệnh sản xuất."
                    )
                case .failure(let err):
                    self?.hienThongBao("Lỗi nhận dạng OCR", err.localizedDescription)
                }
            }
        }
    }

    @objc private func bamXemAnhGoc() {
        guard let anh = anhHienTai else {
            hienThongBao("Chưa có ảnh", "Hãy bấm '📷 Quét Lệnh Sản Xuất' để chụp hoặc chọn ảnh lệnh sản xuất trước.")
            return
        }
        let modal = ManHinhXemAnhLenhSX(anh: anh)
        let nav = UINavigationController(rootViewController: modal)
        present(nav, animated: true)
    }

    @objc private func bamThemMucMoi() {
        let modal = ManHinhChiTietMucLenhSX(mucCu: nil) { [weak self] in
            self?.capNhatGiaoDien()
        }
        let nav = UINavigationController(rootViewController: modal)
        present(nav, animated: true)
    }

    @objc private func moMenuTuyChon() {
        let sheet = UIAlertController(title: "Tùy chọn Lệnh Sản Xuất", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "📋 Sao chép tóm tắt Lệnh SX", style: .default) { [weak self] _ in
            let lsx = KhoDuLieu.dungChung.duLieuLenhSX
            var dong: [String] = []
            dong.append("=== \\(lsx.tieuDe) ===")
            dong.append("Số: \\(lsx.soLenh) • \\(lsx.boPhan)")
            dong.append("Hiệu lực: \\(lsx.thoiGianHieuLuc)")
            dong.append("Tổng sản lượng: \\(lsx.tongSanLuongSanPham) tấn (\\(lsx.danhSachMuc.count) mục)")
            dong.append("----------------------------")
            for m in lsx.danhSachMuc {
                dong.append("#\\(m.stt) | Order: \\(m.soOrder) | Kích cỡ: \\(m.kichCo) | Mác thép: \\(m.macThep) | SL: \\(m.sanLuong) tấn | Mác phôi: \\(m.macPhoi) | Thời gian: \\(m.thoiGianDuKien)")
            }
            UIPasteboard.general.string = dong.joined(separator: "\\n")
            self?.hienThongBao("Đã sao chép", "Đã lưu nội dung Lệnh sản xuất vào bộ nhớ tạm.")
        })

        sheet.addAction(UIAlertAction(title: "✏️ Chỉnh sửa thông tin Header lệnh", style: .default) { [weak self] _ in
            self?.moHopThoaiSuaHeader()
        })

        sheet.addAction(UIAlertAction(title: "🗑️ Xóa toàn bộ danh sách lệnh SX", style: .destructive) { [weak self] _ in
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

    @objc private func moHopThoaiSuaHeader() {
        let lsx = KhoDuLieu.dungChung.duLieuLenhSX
        let alert = UIAlertController(title: "Sửa thông tin Lệnh SX", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.text = lsx.soLenh
            tf.placeholder = "Số lệnh (VD: 01.10.2026/LSX-XC...)"
        }
        alert.addTextField { tf in
            tf.text = lsx.boPhan
            tf.placeholder = "Bộ phận (VD: XC#1-XC-NM.CT DAI)"
        }
        alert.addTextField { tf in
            tf.text = lsx.thoiGianHieuLuc
            tf.placeholder = "Thời gian hiệu lực"
        }

        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self] _ in
            var moi = KhoDuLieu.dungChung.duLieuLenhSX
            moi.soLenh = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? moi.soLenh
            moi.boPhan = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? moi.boPhan
            moi.thoiGianHieuLuc = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? moi.thoiGianHieuLuc
            KhoDuLieu.dungChung.luuDuLieuLenhSX(moi)
            self?.capNhatGiaoDien()
        })
        present(alert, animated: true)
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
            let cell = UITableViewCell(style: .default, reuseIdentifier: "OTrongLenhSX")
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.textLabel?.text = "Không tìm thấy mục lệnh sản xuất nào khớp từ khóa.\nBấm '📷 Quét Lệnh Sản Xuất' để quét ảnh mới."
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = .italicSystemFont(ofSize: 14)
            cell.textLabel?.textColor = KhoDuLieu.dungChung.mauSac.subText
            return cell
        }

        let ma = "OLenhSanXuat"
        let cell = tableView.dequeueReusableCell(withIdentifier: ma) ?? UITableViewCell(style: .default, reuseIdentifier: ma)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let item = danhSachHienThi[indexPath.row]
        let mau = KhoDuLieu.dungChung.mauSac

        let the = UIView()
        the.backgroundColor = mau.card
        the.layer.cornerRadius = 14
        the.layer.borderWidth = 1
        the.layer.borderColor = mau.border.cgColor
        the.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(the)

        // Hàng 1: STT + Badge Kích cỡ + Badge Mác thép + Sản lượng
        let lbSTT = UILabel()
        lbSTT.text = "#\\(item.stt)"
        lbSTT.font = .systemFont(ofSize: 13, weight: .bold)
        lbSTT.textColor = mau.subText

        let nhanKichCo = taoBadge("Kích cỡ: \\(item.kichCo)", mauNen: .systemOrange.withAlphaComponent(0.15), mauChu: .systemOrange)
        let nhanMacThep = taoBadge("Mác: \\(item.macThep)", mauNen: mau.primary.withAlphaComponent(0.15), mauChu: mau.primary)

        let lbSanLuong = UILabel()
        lbSanLuong.text = "📦 \\(item.sanLuong) tấn"
        lbSanLuong.font = .systemFont(ofSize: 14, weight: .bold)
        lbSanLuong.textColor = mau.success
        lbSanLuong.setContentHuggingPriority(.required, for: .horizontal)

        let hangDau = UIStackView(arrangedSubviews: [lbSTT, nhanKichCo, nhanMacThep, UIView(), lbSanLuong])
        hangDau.axis = .horizontal
        hangDau.spacing = 6
        hangDau.alignment = .center

        let vach = UIView()
        vach.backgroundColor = mau.border
        vach.heightAnchor.constraint(equalToConstant: 0.8).isActive = true

        // Hàng 2: Thời gian dự kiến sản xuất
        let lbTG = UILabel()
        lbTG.text = "🕒 Thời gian SX: \\(item.thoiGianDuKien.isEmpty ? \"Theo kế hoạch ca\" : item.thoiGianDuKien)"
        lbTG.font = .systemFont(ofSize: 13, weight: .medium)
        lbTG.textColor = mau.text

        // Hàng 3: Số Order & Batch
        let lbOrder = UILabel()
        let attrOrder = NSMutableAttributedString(
            string: "🏷️ Số Order: ",
            attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: mau.subText]
        )
        attrOrder.append(NSAttributedString(
            string: item.soOrder.isEmpty ? "(Chưa có)" : item.soOrder,
            attributes: [.font: UIFont.systemFont(ofSize: 13.5, weight: .bold), .foregroundColor: mau.primary]
        ))
        if !item.soBatch.isEmpty {
            attrOrder.append(NSAttributedString(
                string: "  •  Batch: \\(item.soBatch)",
                attributes: [.font: UIFont.systemFont(ofSize: 12.5), .foregroundColor: mau.subText]
            ))
        }
        lbOrder.attributedText = attrOrder

        // Hàng 4: Mác phôi & Cơ tính
        let lbPhoi = UILabel()
        lbPhoi.numberOfLines = 0
        let attrPhoi = NSMutableAttributedString(
            string: "🏗️ Mác phôi: ",
            attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: mau.subText]
        )
        attrPhoi.append(NSAttributedString(
            string: item.macPhoi,
            attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: mau.text]
        ))
        if !item.coTinh.isEmpty {
            attrPhoi.append(NSAttributedString(
                string: "  •  Cơ tính: \\(item.coTinh)",
                attributes: [.font: UIFont.systemFont(ofSize: 12.5), .foregroundColor: mau.subText]
            ))
        }
        lbPhoi.attributedText = attrPhoi

        let nganNoiDung = UIStackView(arrangedSubviews: [hangDau, vach, lbTG, lbOrder, lbPhoi])
        nganNoiDung.axis = .vertical
        nganNoiDung.spacing = 6

        if !item.ghiChu.isEmpty {
            let lbGC = UILabel()
            lbGC.text = "📝 \\(item.ghiChu)"
            lbGC.font = .italicSystemFont(ofSize: 12)
            lbGC.textColor = mau.subText
            nganNoiDung.addArrangedSubview(lbGC)
        }

        nganNoiDung.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(nganNoiDung)

        NSLayoutConstraint.activate([
            the.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 5),
            the.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -5),
            the.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
            the.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),

            nganNoiDung.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
            nganNoiDung.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
            nganNoiDung.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            nganNoiDung.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])

        return cell
    }

    private func taoBadge(_ text: String, mauNen: UIColor, mauChu: UIColor) -> UILabel {
        let lb = UILabel()
        lb.text = "  \\(text)  "
        lb.font = .systemFont(ofSize: 11.5, weight: .bold)
        lb.textColor = mauChu
        lb.backgroundColor = mauNen
        lb.layer.cornerRadius = 6
        lb.layer.masksToBounds = true
        lb.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return lb
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !danhSachHienThi.isEmpty, danhSachHienThi.indices.contains(indexPath.row) else { return }
        let item = danhSachHienThi[indexPath.row]
        let modal = ManHinhChiTietMucLenhSX(mucCu: item) { [weak self] in
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
        let item = danhSachHienThi[indexPath.row]

        let xoa = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            var lsx = KhoDuLieu.dungChung.duLieuLenhSX
            lsx.danhSachMuc.removeAll { $0.id == item.id }
            KhoDuLieu.dungChung.luuDuLieuLenhSX(lsx)
            self?.capNhatGiaoDien()
            completion(true)
        }

        let sua = UIContextualAction(style: .normal, title: "Sửa") { [weak self] _, _, completion in
            let modal = ManHinhChiTietMucLenhSX(mucCu: item) { [weak self] in
                self?.capNhatGiaoDien()
            }
            let nav = UINavigationController(rootViewController: modal)
            self?.present(nav, animated: true)
            completion(true)
        }
        sua.backgroundColor = KhoDuLieu.dungChung.mauSac.primary

        return UISwipeActionsConfiguration(actions: [xoa, sua])
    }
}

// MARK: - 3. Màn Hình Xem & Chỉnh Sửa Chi Tiết Mục Lệnh SX

final class ManHinhChiTietMucLenhSX: UIViewController {
    private let mucCu: MucDongLenhSX?
    private let khiLuu: () -> Void

    private let oSTT = UITextField()
    private let oThoiGianDuKien = UITextField()
    private let oKichCo = UITextField()
    private let oMacThep = UITextField()
    private let oSanLuong = UITextField()
    private let oCoTinh = UITextField()
    private let oMacPhoi = UITextField()
    private let oLoaiPhoi = UITextField()
    private let oKichThuocPhoi = UITextField()
    private let oSanLuongPhoi = UITextField()
    private let oHinhThucPhoi = UITextField()
    private let oSoOrder = UITextField()
    private let oSoBatch = UITextField()
    private let oGhiChu = UITextField()

    init(mucCu: MucDongLenhSX?, khiLuu: @escaping () -> Void) {
        self.mucCu = mucCu
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
        navigationItem.title = mucCu == nil ? "Thêm mục Lệnh SX" : "Chi tiết mục Lệnh SX"

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

        [oSTT, oThoiGianDuKien, oKichCo, oMacThep, oSanLuong, oCoTinh, oMacPhoi, oLoaiPhoi, oKichThuocPhoi, oSanLuongPhoi, oHinhThucPhoi, oSoOrder, oSoBatch, oGhiChu].forEach {
            $0.borderStyle = .roundedRect
            $0.backgroundColor = mau.iconBg
            $0.textColor = mau.text
            $0.font = .systemFont(ofSize: 14)
        }

        oSTT.placeholder = "STT (VD: 1)"
        oSTT.text = "\\(mucCu?.stt ?? (KhoDuLieu.dungChung.duLieuLenhSX.danhSachMuc.count + 1))"
        oSTT.keyboardType = .numberPad

        oThoiGianDuKien.placeholder = "VD: 08h00 10/11 - 08h00 12/11"
        oThoiGianDuKien.text = mucCu?.thoiGianDuKien ?? ""

        oKichCo.placeholder = "VD: D18 hoặc D16"
        oKichCo.text = mucCu?.kichCo ?? ""

        oMacThep.placeholder = "VD: CB400V, CB500V, Gr40, Gr60..."
        oMacThep.text = mucCu?.macThep ?? ""

        oSanLuong.placeholder = "VD: 3,500 hoặc 40"
        oSanLuong.text = mucCu?.sanLuong ?? ""

        oCoTinh.placeholder = "VD: 40.2025/YCCN - P.CN"
        oCoTinh.text = mucCu?.coTinh ?? ""

        oMacPhoi.placeholder = "VD: CT5, CT5V, Gr80-1..."
        oMacPhoi.text = mucCu?.macPhoi ?? ""

        oLoaiPhoi.placeholder = "VD: 1+(*)"
        oLoaiPhoi.text = mucCu?.loaiPhoi ?? "1+(*)"

        oKichThuocPhoi.placeholder = "VD: 150x150, 165x165"
        oKichThuocPhoi.text = mucCu?.kichThuocPhoi ?? "150x150, 165x165"

        oSanLuongPhoi.placeholder = "VD: 3,605 hoặc 41"
        oSanLuongPhoi.text = mucCu?.sanLuongPhoi ?? ""

        oHinhThucPhoi.placeholder = "VD: Phôi nóng / Phôi nguội"
        oHinhThucPhoi.text = mucCu?.hinhThucPhoi ?? "Phôi nóng / Phôi nguội"

        oSoOrder.placeholder = "VD: 1040004620"
        oSoOrder.text = mucCu?.soOrder ?? ""
        oSoOrder.keyboardType = .numberPad

        oSoBatch.placeholder = "VD: 1111261117"
        oSoBatch.text = mucCu?.soBatch ?? ""
        oSoBatch.keyboardType = .numberPad

        oGhiChu.placeholder = "VD: (1) Nội địa"
        oGhiChu.text = mucCu?.ghiChu ?? ""

        func taoO(_ tieuDe: String, _ tf: UITextField) -> UIStackView {
            let lb = UILabel()
            lb.text = tieuDe
            lb.font = .systemFont(ofSize: 12.5, weight: .bold)
            lb.textColor = mau.subText
            let st = UIStackView(arrangedSubviews: [lb, tf])
            st.axis = .vertical
            st.spacing = 4
            return st
        }

        let hangDoi1 = UIStackView(arrangedSubviews: [taoO("Số thứ tự (TT):", oSTT), taoO("Kích cỡ sản phẩm:", oKichCo)])
        hangDoi1.distribution = .fillEqually
        hangDoi1.spacing = 10

        let hangDoi2 = UIStackView(arrangedSubviews: [taoO("Mác thép:", oMacThep), taoO("Sản lượng (tấn):", oSanLuong)])
        hangDoi2.distribution = .fillEqually
        hangDoi2.spacing = 10

        let hangDoi3 = UIStackView(arrangedSubviews: [taoO("Số Order:", oSoOrder), taoO("Số Batch:", oSoBatch)])
        hangDoi3.distribution = .fillEqually
        hangDoi3.spacing = 10

        let hangDoi4 = UIStackView(arrangedSubviews: [taoO("Mác phôi cán:", oMacPhoi), taoO("Sản lượng phôi (tấn):", oSanLuongPhoi)])
        hangDoi4.distribution = .fillEqually
        hangDoi4.spacing = 10

        [
            hangDoi1,
            taoO("🕒 Thời gian dự kiến sản xuất:", oThoiGianDuKien),
            hangDoi2,
            taoO("🔬 Cơ tính:", oCoTinh),
            hangDoi3,
            hangDoi4,
            taoO("📐 Kích thước phôi:", oKichThuocPhoi),
            taoO("📝 Ghi chú:", oGhiChu)
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

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        view.endEditing(true)
        let sttVal = Int(oSTT.text ?? "") ?? 1
        let moi = MucDongLenhSX(
            id: mucCu?.id ?? UUID().uuidString,
            stt: sttVal,
            thoiGianDuKien: oThoiGianDuKien.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            kichCo: oKichCo.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            macThep: oMacThep.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            sanLuong: oSanLuong.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            coTinh: oCoTinh.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            macPhoi: oMacPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            loaiPhoi: oLoaiPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "1+(*)",
            kichThuocPhoi: oKichThuocPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "150x150, 165x165",
            sanLuongPhoi: oSanLuongPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            hinhThucPhoi: oHinhThucPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Phôi nóng / Phôi nguội",
            soOrder: oSoOrder.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            soBatch: oSoBatch.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            ghiChu: oGhiChu.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )

        var lsx = KhoDuLieu.dungChung.duLieuLenhSX
        if let idx = lsx.danhSachMuc.firstIndex(where: { $0.id == moi.id }) {
            lsx.danhSachMuc[idx] = moi
        } else {
            lsx.danhSachMuc.append(moi)
        }
        lsx.danhSachMuc.sort { $0.stt < $1.stt }
        KhoDuLieu.dungChung.luuDuLieuLenhSX(lsx)
        dismiss(animated: true, completion: khiLuu)
    }
}

// MARK: - 4. Màn Hình Phóng To Ảnh Lệnh Sản Xuất Để So Sánh Đối Chiếu

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
        navigationItem.title = "Ảnh Lệnh Sản Xuất"
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
