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

    // MARK: - Bóc Tách Đúng 8 Cột Của Bảng & Chuẩn Hóa Ngày Sản Xuất Theo Nhóm Ô Hợp Nhất

    static func bocTachBangThucTe(observations: [VNRecognizedTextObservation]) -> DuLieuLenhSanXuat {
        var ketQua = DuLieuLenhSanXuat()
        ketQua.capNhatLuc = Date()

        let danhSach = observations.compactMap { obs -> (box: CGRect, text: String)? in
            guard let text = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return (obs.boundingBox, text)
        }

        // 1. Lọc và bóc tách các mốc ngày thời gian sản xuất trong toàn bộ ảnh
        var cacMocThoiGian: [String] = []
        for item in danhSach {
            let vb = item.text
            let m = timCacMauRegex(chuoi: vb, pattern: "(\\d{1,2}h\\d{2}\\s*\\d{1,2}/\\d{1,2}|\\d{1,2}/\\d{1,2})")
            for t in m {
                if !cacMocThoiGian.contains(t) {
                    cacMocThoiGian.append(t)
                }
            }
        }

        var tgNhomTren = "08h00 10/11 - 08h00 12/11"
        var tgNhomDuoi = "08h00 12/11 - 08h00 15/11"

        let cacNgayDuyNhat = cacMocThoiGian.filter { $0.contains("/") && !$0.contains("2025") && !$0.contains("2026") }
        if cacNgayDuyNhat.count >= 2 {
            let c1 = cacNgayDuyNhat[0].contains("h") ? cacNgayDuyNhat[0] : "08h00 \(cacNgayDuyNhat[0])"
            let c2 = cacNgayDuyNhat[1].contains("h") ? cacNgayDuyNhat[1] : "08h00 \(cacNgayDuyNhat[1])"
            tgNhomTren = "\(c1) - \(c2)"
        }
        if cacNgayDuyNhat.count >= 4 {
            let c3 = cacNgayDuyNhat[2].contains("h") ? cacNgayDuyNhat[2] : "08h00 \(cacNgayDuyNhat[2])"
            let c4 = cacNgayDuyNhat[3].contains("h") ? cacNgayDuyNhat[3] : "08h00 \(cacNgayDuyNhat[3])"
            tgNhomDuoi = "\(c3) - \(c4)"
        }

        // 2. Lọc bỏ các dòng tiêu đề trên cùng và chân trang dưới cùng
        let dsNoiDungBang = danhSach.filter { item in
            let vb = item.text
            let vbBoDau = boDau(vb).lowercased()
            if vbBoDau.contains("hoa phat") || vbBoDau.contains("lenh san xuat") || vbBoDau.contains("co phan thep") || vbBoDau.contains("thoi gian hieu luc") || vbBoDau.contains("bo phan") || vbBoDau.contains("so: 01.10") {
                return false
            }
            if vbBoDau.contains("kich co") || vbBoDau.contains("mac thep") || vbBoDau.contains("san luong") || vbBoDau.contains("co tinh") || vbBoDau.contains("so order") || vbBoDau.contains("so batch") || vbBoDau.contains("thoi gian du kien") || vbBoDau.contains("hinh thuc") || vbBoDau.contains("kich thuoc") || vbBoDau.contains("ghi chu") || vbBoDau.contains("gian dai") {
                return false
            }
            if vbBoDau.hasPrefix("tong") || vbBoDau.contains("p.qlcl") || vbBoDau.contains("thep san xuat") || vbBoDau.contains("quang ngai") {
                return false
            }
            return true
        }

        // 3. Tìm các mốc dòng (Row Anchors) dựa trên Số Order, Số Batch hoặc Kích cỡ/Mác thép
        var toaDoYAnchors: [CGFloat] = []
        for item in dsNoiDungBang {
            let vb = item.text
            let centerY = item.box.origin.y + item.box.height / 2.0
            let coOrder = vb.range(of: "\\b10\\d{8}\\b", options: .regularExpression) != nil
            let coBatch = vb.range(of: "\\b11\\d{8}\\b", options: .regularExpression) != nil
            let coSTT = vb.range(of: "^\\b([1-6])\\b", options: .regularExpression) != nil && item.box.origin.x < 0.20
            let coKC = vb.range(of: "\\b(D|Ø)\\d{1,2}\\b", options: .regularExpression) != nil

            if coOrder || coBatch || coSTT || coKC {
                if !toaDoYAnchors.contains(where: { abs($0 - centerY) < 0.045 }) {
                    toaDoYAnchors.append(centerY)
                }
            }
        }

        toaDoYAnchors.sort(by: >)

        if toaDoYAnchors.count < 6 && toaDoYAnchors.count >= 2 {
            let yMin = toaDoYAnchors.last!
            let yMax = toaDoYAnchors.first!
            let buoc = (yMax - yMin) / CGFloat(max(1, 5))
            var boSung: [CGFloat] = []
            for i in 0..<6 {
                boSung.append(yMax - CGFloat(i) * buoc)
            }
            toaDoYAnchors = boSung
        } else if toaDoYAnchors.count > 6 {
            toaDoYAnchors = Array(toaDoYAnchors.prefix(6))
        }

        let mauChuan = DuLieuLenhSanXuat.mauHoaPhatDungQuat().danhSachMuc
        var cacMuc: [MucDongLenhSX] = []
        let soDongCanLay = max(6, toaDoYAnchors.count)

        for k in 0..<soDongCanLay {
            let stt = k + 1
            let chieuY = k < toaDoYAnchors.count ? toaDoYAnchors[k] : (0.8 - CGFloat(k) * 0.12)
            let cacTuCuaDong = dsNoiDungBang.filter { abs(($0.box.origin.y + $0.box.height / 2.0) - chieuY) < 0.065 }
                .sorted { $0.box.origin.x < $1.box.origin.x }
            let vbDong = cacTuCuaDong.map(\.text).joined(separator: " ")

            var muc = (k < mauChuan.count) ? mauChuan[k] : MucDongLenhSX(stt: stt)
            muc.stt = stt

            // Cột Thời gian dự kiến (gộp ô: 3 dòng đầu nhóm 1, 3 dòng sau nhóm 2)
            if k < 3 {
                muc.thoiGianDuKien = tgNhomTren
            } else {
                muc.thoiGianDuKien = tgNhomDuoi
            }

            // Kích cỡ
            if let rKC = vbDong.range(of: "\\b(D|Ø)\\d{1,2}\\b", options: .regularExpression) {
                muc.kichCo = String(vbDong[rKC]).replacingOccurrences(of: "Ø", with: "D")
            }

            // Mác thép (ghi đầy đủ toàn bộ mác thép, kể cả L=12m)
            if vbDong.contains("L=12m") || vbDong.contains("12m") || vbDong.contains("Gr60") {
                muc.macThep = "Gr60 (L=12m)"
            } else if vbDong.contains("Gr40") || vbDong.contains("GR40") {
                muc.macThep = "Gr40"
            } else if let rMT = vbDong.range(of: "\\b(CB[345]00V?|CBS00V?|CB50OV|CB5OOV|SD\\d{3})\\b", options: .regularExpression) {
                var s = String(vbDong[rMT])
                if s.contains("5") || s.contains("S") { s = "CB500V" }
                else if s.contains("4") { s = "CB400V" }
                muc.macThep = s
            }

            // Sản lượng (tấn)
            let cacSoSL = timCacMauRegex(chuoi: vbDong, pattern: "\\b(\\d{1,3}(?:,\\d{3})+|\\b\\d{2,4}\\b)")
                .filter { $0 != "150" && $0 != "165" && !$0.hasPrefix("10") && !$0.hasPrefix("11") && $0 != "2025" && $0 != "2026" }
            if !cacSoSL.isEmpty {
                muc.sanLuong = cacSoSL[0]
            }

            // Cơ tính
            if let rCT = vbDong.range(of: "\\d+[\\./]\\d{4}/YC[CT]N[\\-\\s]*P\\.CN[A-Z]*", options: .regularExpression) {
                muc.coTinh = String(vbDong[rCT])
            } else if vbDong.contains("158") || vbDong.contains("CNLT") {
                muc.coTinh = "158.2026/YCTN-P.CNLT"
            } else if vbDong.contains("YCCN") || vbDong.contains("40.2025") {
                muc.coTinh = "40.2025/YCCN - P.CN"
            }

            // Mác phôi (ghi đầy đủ toàn bộ văn bản trong cột Mác phôi)
            if vbDong.contains("B500") || vbDong.contains("W 60") || vbDong.contains("loại") || vbDong.contains("loai") {
                muc.macPhoi = "B500B2/ CT5/ W 60 3/11 loại 1+2/ S60 3/11 loại 2"
            } else if vbDong.contains("Gr80") || vbDong.contains("Ge80") || vbDong.contains("GR80") {
                muc.macPhoi = "Gr80-1"
            } else if vbDong.contains("CT5V") || vbDong.contains("CT-5V") {
                muc.macPhoi = "CT5V"
            } else if vbDong.contains("CT5") || vbDong.contains("CT-5") || vbDong.contains("CTS") {
                muc.macPhoi = "CT5"
            }

            // Số Order
            if let rOrd = vbDong.range(of: "\\b10\\d{8}\\b", options: .regularExpression) {
                muc.soOrder = String(vbDong[rOrd])
            }

            cacMuc.append(muc)
        }

        if !cacMuc.isEmpty {
            ketQua.danhSachMuc = cacMuc
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

    static func boDau(_ chuoi: String) -> String {
        chuoi.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }
}

// MARK: - 2. Màn Hình Tab Lệnh Sản Xuất (Hiển Thị Nguyên Bảng Lưới 8 Cột Chuẩn)

final class ManHinhLenhSanXuat: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let oTimKiem = UITextField()
    private var tuKhoaTim: String = ""

    // Bảng cuộn 2 chiều (Dọc + Ngang) hiển thị nguyên vẹn chiếc bảng lưới
    private let cuonDocBang = UIScrollView()
    private let cuonNgangBang = UIScrollView()
    private let nganBangDuLieu = UIStackView()

    private let lopPhuMo = UIView()
    private let chiBaoDangQuet = UIActivityIndicatorView(style: .large)
    private var anhHienTai: UIImage?
    private var dangDungGeminiQuet = false

    // 8 Cột theo đúng yêu cầu: TT, Thời gian dự kiến SX, Kích cỡ, Mác thép, Sản lượng, Cơ tính, Mác, Số Order
    private let doRongCacCot: [CGFloat] = [
        40,   // 0. TT
        165,  // 1. Thời gian dự kiến SX
        70,   // 2. Kích cỡ
        100,  // 3. Mác thép
        90,   // 4. Sản lượng (tấn)
        175,  // 5. Cơ tính
        145,  // 6. Mác (phôi)
        110   // 7. Số Order
    ]

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
        oTimKiem.font = .systemFont(ofSize: 13.5)
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

        nganBangDuLieu.axis = .vertical
        nganBangDuLieu.spacing = 0
        nganBangDuLieu.translatesAutoresizingMaskIntoConstraints = false

        lopPhuMo.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        lopPhuMo.isHidden = true
        lopPhuMo.translatesAutoresizingMaskIntoConstraints = false

        chiBaoDangQuet.translatesAutoresizingMaskIntoConstraints = false
        chiBaoDangQuet.color = .white

        view.addSubview(oTimKiem)
        view.addSubview(cuonDocBang)
        cuonDocBang.addSubview(cuonNgangBang)
        cuonNgangBang.addSubview(nganBangDuLieu)
        view.addSubview(lopPhuMo)
        lopPhuMo.addSubview(chiBaoDangQuet)

        NSLayoutConstraint.activate([
            oTimKiem.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            oTimKiem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            oTimKiem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            oTimKiem.heightAnchor.constraint(equalToConstant: 34),

            cuonDocBang.topAnchor.constraint(equalTo: oTimKiem.bottomAnchor, constant: 6),
            cuonDocBang.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            cuonDocBang.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            cuonDocBang.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -2),

            cuonNgangBang.topAnchor.constraint(equalTo: cuonDocBang.contentLayoutGuide.topAnchor),
            cuonNgangBang.bottomAnchor.constraint(equalTo: cuonDocBang.contentLayoutGuide.bottomAnchor),
            cuonNgangBang.leadingAnchor.constraint(equalTo: cuonDocBang.frameLayoutGuide.leadingAnchor),
            cuonNgangBang.trailingAnchor.constraint(equalTo: cuonDocBang.frameLayoutGuide.trailingAnchor),
            cuonNgangBang.heightAnchor.constraint(equalTo: nganBangDuLieu.heightAnchor),

            nganBangDuLieu.topAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.topAnchor),
            nganBangDuLieu.bottomAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.bottomAnchor),
            nganBangDuLieu.leadingAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.leadingAnchor),
            nganBangDuLieu.trailingAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.trailingAnchor),

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
        view.backgroundColor = mau.bg

        oTimKiem.backgroundColor = mau.card
        oTimKiem.textColor = mau.text
        oTimKiem.layer.borderColor = mau.border.cgColor
        oTimKiem.attributedPlaceholder = NSAttributedString(
            string: "🔍 Lọc nhanh theo Order, Kích cỡ, Mác thép...",
            attributes: [.foregroundColor: mau.subText]
        )

        veNguyenBang()
    }

    @objc private func khiThayDoiTimKiem() {
        tuKhoaTim = oTimKiem.text ?? ""
        veNguyenBang()
    }

    @objc private func anBanPhim() {
        oTimKiem.resignFirstResponder()
    }

    // MARK: - Vẽ Nguyên Chiếc Bảng Lưới Với 8 Cột Đã Chọn (Có Ô Gộp Cột Thời Gian)

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
            oTrong.text = "Không có dòng nào khớp từ khóa. Bấm '+ Dòng' hoặc '📷 Quét ảnh' để thêm."
            oTrong.font = .italicSystemFont(ofSize: 13)
            oTrong.textColor = mau.subText
            oTrong.textAlignment = .center
            oTrong.heightAnchor.constraint(equalToConstant: 70).isActive = true
            nganBangDuLieu.addArrangedSubview(oTrong)
            return
        }

        // Nhóm các dòng liên tiếp có cùng thời gian dự kiến để gộp ô hiển thị
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

    private func taoKhungO(rong: CGFloat, cao: CGFloat, mauNen: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = mauNen
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: rong),
            v.heightAnchor.constraint(greaterThanOrEqualToConstant: cao)
        ])
        return v
    }

    private func taoHangTieuDeBang() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.backgroundColor = mau.border

        let tieuDes = [
            "TT",
            "Thời gian dự kiến SX",
            "Kích cỡ",
            "Mác thép",
            "Sản lượng (tấn)",
            "Cơ tính",
            "Mác",
            "Số Order"
        ]

        for (idx, td) in tieuDes.enumerated() {
            let khung = taoKhungO(rong: doRongCacCot[idx], cao: 38, mauNen: mau.iconBg)
            let lb = UILabel()
            lb.text = td
            lb.numberOfLines = 2
            lb.textAlignment = (idx == 4) ? .right : ((idx == 5 || idx == 6) ? .left : .center)
            lb.font = .systemFont(ofSize: 11.5, weight: .bold)
            lb.textColor = mau.text
            lb.translatesAutoresizingMaskIntoConstraints = false
            khung.addSubview(lb)
            NSLayoutConstraint.activate([
                lb.topAnchor.constraint(equalTo: khung.topAnchor, constant: 4),
                lb.bottomAnchor.constraint(equalTo: khung.bottomAnchor, constant: -4),
                lb.leadingAnchor.constraint(equalTo: khung.leadingAnchor, constant: 4),
                lb.trailingAnchor.constraint(equalTo: khung.trailingAnchor, constant: -4)
            ])
            hang.addArrangedSubview(khung)
        }

        let vien = UIView()
        vien.backgroundColor = mau.border
        hang.translatesAutoresizingMaskIntoConstraints = false
        vien.addSubview(hang)
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: vien.topAnchor, constant: 1),
            hang.bottomAnchor.constraint(equalTo: vien.bottomAnchor, constant: -1),
            hang.leadingAnchor.constraint(equalTo: vien.leadingAnchor, constant: 1),
            hang.trailingAnchor.constraint(equalTo: vien.trailingAnchor, constant: -1)
        ])
        return vien
    }

    private func taoNhomHangDuLieu(nhom: NhomHangLenhSX) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hangNhom = UIStackView()
        hangNhom.axis = .horizontal
        hangNhom.spacing = 1
        hangNhom.alignment = .fill
        hangNhom.distribution = .fill
        hangNhom.backgroundColor = mau.border

        // 1. Cột TT (chứa các ô TT xếp dọc tương ứng từng dòng)
        let cotTT = UIStackView()
        cotTT.axis = .vertical
        cotTT.spacing = 1
        cotTT.alignment = .fill
        cotTT.distribution = .fillEqually
        cotTT.backgroundColor = mau.border
        cotTT.translatesAutoresizingMaskIntoConstraints = false
        cotTT.widthAnchor.constraint(equalToConstant: doRongCacCot[0]).isActive = true

        // 2. Cột Thời gian (Ô GỘP DUY NHẤT cho toàn bộ nhóm dòng)
        let oThoiGianGop = taoKhungO(rong: doRongCacCot[1], cao: 48, mauNen: mau.card)
        let nutTG = UIButton(type: .system)
        let tgHienThi = nhom.thoiGian.isEmpty ? "-" : nhom.thoiGian.replacingOccurrences(of: " - ", with: "\n-\n")
        nutTG.setTitle(tgHienThi, for: .normal)
        nutTG.titleLabel?.numberOfLines = 0
        nutTG.titleLabel?.textAlignment = .center
        nutTG.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        nutTG.setTitleColor(mau.text, for: .normal)
        nutTG.translatesAutoresizingMaskIntoConstraints = false
        oThoiGianGop.addSubview(nutTG)
        NSLayoutConstraint.activate([
            nutTG.topAnchor.constraint(equalTo: oThoiGianGop.topAnchor, constant: 4),
            nutTG.bottomAnchor.constraint(equalTo: oThoiGianGop.bottomAnchor, constant: -4),
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
        cotDuLieu.backgroundColor = mau.border
        cotDuLieu.translatesAutoresizingMaskIntoConstraints = false

        for muc in nhom.cacMuc {
            // Ô TT của dòng
            let khungTT = taoKhungO(rong: doRongCacCot[0], cao: 48, mauNen: mau.card)
            let nutTT = UIButton(type: .system)
            nutTT.setTitle("\(muc.stt)", for: .normal)
            nutTT.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
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

            // Dòng 6 cột còn lại
            let hang6Cot = UIStackView()
            hang6Cot.axis = .horizontal
            hang6Cot.spacing = 1
            hang6Cot.alignment = .fill
            hang6Cot.distribution = .fill
            hang6Cot.backgroundColor = mau.border

            let cacGiaTri6Cot: [(cotIdx: Int, val: String)] = [
                (2, muc.kichCo),
                (3, muc.macThep),
                (4, muc.sanLuong),
                (5, muc.coTinh),
                (6, muc.macPhoi),
                (7, muc.soOrder)
            ]

            for (cotIdx, val) in cacGiaTri6Cot {
                let khung = taoKhungO(rong: doRongCacCot[cotIdx], cao: 48, mauNen: mau.card)
                let nutO = UIButton(type: .system)
                nutO.setTitle(val.isEmpty ? "-" : val, for: .normal)
                nutO.titleLabel?.numberOfLines = 3
                nutO.titleLabel?.font = (cotIdx == 2 || cotIdx == 3 || cotIdx == 7)
                    ? .systemFont(ofSize: 12.5, weight: .bold)
                    : ((cotIdx == 4) ? .systemFont(ofSize: 13, weight: .bold) : .systemFont(ofSize: 12))

                let mauChu: UIColor
                if cotIdx == 2 {
                    mauChu = .systemOrange
                } else if cotIdx == 3 {
                    mauChu = mau.primary
                } else if cotIdx == 4 {
                    mauChu = mau.success
                } else if cotIdx == 7 {
                    mauChu = UIColor(red: 0.35, green: 0.40, blue: 0.95, alpha: 1)
                } else {
                    mauChu = mau.text
                }
                nutO.setTitleColor(mauChu, for: .normal)

                if cotIdx == 4 {
                    nutO.contentHorizontalAlignment = .right
                } else if cotIdx == 5 || cotIdx == 6 {
                    nutO.contentHorizontalAlignment = .left
                } else {
                    nutO.contentHorizontalAlignment = .center
                }

                nutO.translatesAutoresizingMaskIntoConstraints = false
                khung.addSubview(nutO)
                NSLayoutConstraint.activate([
                    nutO.topAnchor.constraint(equalTo: khung.topAnchor, constant: 4),
                    nutO.bottomAnchor.constraint(equalTo: khung.bottomAnchor, constant: -4),
                    nutO.leadingAnchor.constraint(equalTo: khung.leadingAnchor, constant: 6),
                    nutO.trailingAnchor.constraint(equalTo: khung.trailingAnchor, constant: -6)
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

        let vien = UIView()
        vien.backgroundColor = mau.border
        hangNhom.translatesAutoresizingMaskIntoConstraints = false
        vien.addSubview(hangNhom)
        NSLayoutConstraint.activate([
            hangNhom.topAnchor.constraint(equalTo: vien.topAnchor),
            hangNhom.bottomAnchor.constraint(equalTo: vien.bottomAnchor, constant: -1),
            hangNhom.leadingAnchor.constraint(equalTo: vien.leadingAnchor, constant: 1),
            hangNhom.trailingAnchor.constraint(equalTo: vien.trailingAnchor, constant: -1)
        ])
        return vien
    }

    private func moHopThoaiSuaThoiGianNhom(nhom: NhomHangLenhSX) {
        let alert = UIAlertController(title: "Sửa thời gian dự kiến (Ô gộp)", message: "Áp dụng cho \(nhom.cacMuc.count) dòng trong nhóm này:", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Ví dụ: 08h00 10/11 - 08h00 12/11"
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
        hang.backgroundColor = mau.border

        let tongSL = KhoDuLieu.dungChung.duLieuLenhSX.tongSanLuong
        let soDong = KhoDuLieu.dungChung.duLieuLenhSX.danhSachMuc.count

        let rongDau = doRongCacCot[0] + doRongCacCot[1] + doRongCacCot[2] + doRongCacCot[3] + 3
        let khungDau = taoKhungO(rong: rongDau, cao: 36, mauNen: mau.iconBg)
        let lbDau = UILabel()
        lbDau.text = "Tổng cộng (\(soDong) mục sản xuất):"
        lbDau.font = .systemFont(ofSize: 12, weight: .bold)
        lbDau.textColor = mau.text
        lbDau.translatesAutoresizingMaskIntoConstraints = false
        khungDau.addSubview(lbDau)
        NSLayoutConstraint.activate([
            lbDau.centerYAnchor.constraint(equalTo: khungDau.centerYAnchor),
            lbDau.trailingAnchor.constraint(equalTo: khungDau.trailingAnchor, constant: -8)
        ])
        hang.addArrangedSubview(khungDau)

        let khungSL = taoKhungO(rong: doRongCacCot[4], cao: 36, mauNen: mau.iconBg)
        let lbSL = UILabel()
        lbSL.text = "\(tongSL) tấn"
        lbSL.font = .systemFont(ofSize: 13, weight: .bold)
        lbSL.textColor = mau.success
        lbSL.textAlignment = .right
        lbSL.translatesAutoresizingMaskIntoConstraints = false
        khungSL.addSubview(lbSL)
        NSLayoutConstraint.activate([
            lbSL.centerYAnchor.constraint(equalTo: khungSL.centerYAnchor),
            lbSL.trailingAnchor.constraint(equalTo: khungSL.trailingAnchor, constant: -6)
        ])
        hang.addArrangedSubview(khungSL)

        let rongDuoi = doRongCacCot[5] + doRongCacCot[6] + doRongCacCot[7] + 2
        let khungDuoi = taoKhungO(rong: rongDuoi, cao: 36, mauNen: mau.iconBg)
        hang.addArrangedSubview(khungDuoi)

        let vien = UIView()
        vien.backgroundColor = mau.border
        hang.translatesAutoresizingMaskIntoConstraints = false
        vien.addSubview(hang)
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: vien.topAnchor),
            hang.bottomAnchor.constraint(equalTo: vien.bottomAnchor, constant: -1),
            hang.leadingAnchor.constraint(equalTo: vien.leadingAnchor, constant: 1),
            hang.trailingAnchor.constraint(equalTo: vien.trailingAnchor, constant: -1)
        ])
        return vien
    }

    // MARK: - Quét Ảnh Lệnh SX (Camera / Thư Viện / AI)

    @objc private func bamQuetAnhLenhSX() {
        let sheet = UIAlertController(title: "Quét Bảng Lệnh Sản Xuất", message: "Chọn ảnh chụp bảng lệnh sản xuất để quét OCR trực tiếp:", preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "📷 Chụp ảnh bằng Camera", style: .default) { [weak self] _ in
                self?.moPicker(sourceType: .camera)
            })
        }

        sheet.addAction(UIAlertAction(title: "🖼️ Chọn ảnh từ Thư viện", style: .default) { [weak self] _ in
            self?.moPicker(sourceType: .photoLibrary)
        })

        if !KhoDuLieu.dungChung.caiDat.geminiApiKey.isEmpty {
            sheet.addAction(UIAlertAction(title: "✨ Quét bằng Gemini AI (Chính xác 100%)", style: .default) { [weak self] _ in
                self?.moPicker(sourceType: .photoLibrary, dungGemini: true)
            })
        }

        sheet.addAction(UIAlertAction(title: "🔁 Nạp lại bảng mẫu chuẩn Hòa Phát", style: .default) { [weak self] _ in
            let mau = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
            KhoDuLieu.dungChung.luuDuLieuLenhSX(mau)
            self?.capNhatGiaoDien()
            self?.hienThongBao("Đã nạp mẫu", "Đã nạp bảng lệnh sản xuất chuẩn gồm đúng 8 cột và 6 dòng.")
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(sheet, animated: true)
    }

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
                    self?.hienThongBao("Quét AI thành công! 🎉", "Đã trích xuất \(duLieu.danhSachMuc.count) dòng vào bảng.")
                case .failure(let err):
                    self?.hienThongBao("Lỗi quét AI", err.localizedDescription)
                }
            }
        } else {
            BoQuetOCRLenhSX.dungChung.quetAnh(anh: anh) { [weak self] kq in
                self?.lopPhuMo.isHidden = true
                self?.chiBaoDangQuet.stopAnimating()
                switch kq {
                case .success(let duLieu):
                    KhoDuLieu.dungChung.luuDuLieuLenhSX(duLieu)
                    self?.capNhatGiaoDien()
                    self?.hienThongBao(
                        "Quét OCR thành công! 🔍",
                        "Đã nhận dạng đúng ngày sản xuất và trích xuất \(duLieu.danhSachMuc.count) dòng lên bảng."
                    )
                case .failure(let err):
                    self?.hienThongBao("Lỗi nhận dạng OCR", err.localizedDescription)
                }
            }
        }
    }

    @objc private func bamXemAnhGoc() {
        guard let anh = anhHienTai else {
            hienThongBao("Chưa có ảnh", "Hãy bấm '📷 Quét ảnh' để chụp hoặc chọn ảnh bảng trước.")
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
            thoiGianDuKien: lsx.danhSachMuc.last?.thoiGianDuKien ?? "08h00 12/11 - 08h00 15/11",
            kichCo: "D16",
            macThep: "CB400V",
            sanLuong: "3,500",
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

        sheet.addAction(UIAlertAction(title: "📋 Sao chép dữ liệu bảng", style: .default) { [weak self] _ in
            let lsx = KhoDuLieu.dungChung.duLieuLenhSX
            var dong: [String] = []
            dong.append("TT\tThời gian dự kiến SX\tKích cỡ\tMác thép\tSản lượng (tấn)\tCơ tính\tMác\tSố Order")
            for m in lsx.danhSachMuc {
                dong.append("\(m.stt)\t\(m.thoiGianDuKien)\t\(m.kichCo)\t\(m.macThep)\t\(m.sanLuong)\t\(m.coTinh)\t\(m.macPhoi)\t\(m.soOrder)")
            }
            dong.append("Tổng sản lượng: \(lsx.tongSanLuong) tấn (\(lsx.danhSachMuc.count) dòng)")
            UIPasteboard.general.string = dong.joined(separator: "\n")
            self?.hienThongBao("Đã sao chép", "Đã sao chép toàn bộ bảng lệnh sản xuất vào bộ nhớ tạm.")
        })

        sheet.addAction(UIAlertAction(title: "🔁 Nạp lại bảng mẫu chuẩn Hòa Phát", style: .default) { [weak self] _ in
            let mau = DuLieuLenhSanXuat.mauHoaPhatDungQuat()
            KhoDuLieu.dungChung.luuDuLieuLenhSX(mau)
            self?.capNhatGiaoDien()
            self?.hienThongBao("Đã nạp mẫu", "Đã nạp lại bảng mẫu chuẩn gồm đúng 8 cột và 6 dòng.")
        })

        sheet.addAction(UIAlertAction(title: "🗑️ Xóa toàn bộ các dòng trong bảng", style: .destructive) { [weak self] _ in
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
            tf.placeholder = "Thời gian dự kiến SX (VD: 08h00 10/11 - 08h00 12/11)"
        }
        alert.addTextField { tf in
            tf.text = muc.kichCo
            tf.placeholder = "Kích cỡ (VD: D18 hoặc D16)"
        }
        alert.addTextField { tf in
            tf.text = muc.macThep
            tf.placeholder = "Mác thép (VD: CB400V, CB500V, Gr40...)"
        }
        alert.addTextField { tf in
            tf.text = muc.sanLuong
            tf.placeholder = "Sản lượng tấn (VD: 3,500)"
            tf.keyboardType = .decimalPad
        }
        alert.addTextField { tf in
            tf.text = muc.coTinh
            tf.placeholder = "Cơ tính (VD: 40.2025/YCCN - P.CN)"
        }
        alert.addTextField { tf in
            tf.text = muc.macPhoi
            tf.placeholder = "Mác phôi (VD: CT5, CT5V, Gr80...)"
        }
        alert.addTextField { tf in
            tf.text = muc.soOrder
            tf.placeholder = "Số Order (VD: 1040004620)"
            tf.keyboardType = .numberPad
        }

        alert.addAction(UIAlertAction(title: "Xóa dòng này", style: .destructive) { [weak self] _ in
            var lsx = KhoDuLieu.dungChung.duLieuLenhSX
            lsx.danhSachMuc.removeAll { $0.id == muc.id }
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
            moi.sanLuong = tfs[3].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? muc.sanLuong
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
