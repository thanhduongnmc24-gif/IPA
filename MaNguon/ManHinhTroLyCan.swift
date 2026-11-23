import UIKit
import PhotosUI

// MARK: - 1. Mô hình dữ liệu Chẩn đoán Cán (Mô-men xoắn / Nhiệt / Tension)

enum CheDoChanDoanCan: String, Codable, CaseIterable {
    case moMenXoan = "moMenXoan"
    case socDauNhiet = "socDauNhiet"
    case tensionMTC = "tensionMTC"

    var tieuDeNgan: String {
        switch self {
        case .moMenXoan: return "⚡ Mô-men"
        case .socDauNhiet: return "🔥 Sốc đầu"
        case .tensionMTC: return "🎯 Tension"
        }
    }

    var moTaChuyenDe: String {
        switch self {
        case .moMenXoan:
            return "Chẩn đoán quá tải mô-men xoắn trục các đăng (Act Tor / Des Tor), đề xuất san tải lượng ép Δh và kiểm soát rủi ro nới ép."
        case .socDauNhiet:
            return "Phân tích sốc tải đầu phôi do nhiệt độ P1 thấp, vết nguội lò nung, Lead speed cao hoặc rơ khớp trục các đăng."
        case .tensionMTC:
            return "Phân tích lực căng/đẩy giữa các giá (N/mm²), sai lệch Sample T₀, Elongation thực tế vs Setup và bão hòa MTC."
        }
    }
}

struct ThongSoGiaCanAI: Codable, Hashable {
    var gia: String
    var mucDo: String           // "DO", "VANG", "XANH"
    var actTor: String          // VD: "80.0 / 85 kNm"
    var phanTramCoKhi: String   // VD: "94.1%"
    var torqueMotor: String     // VD: "67% (T0: 66%)"
    var tension: String         // VD: "+1.7 N/mm²"
    var elongation: String      // VD: "1.313 (Setup 1.293)"
    var kichThuocThucTe: String    // VD: "74.0 × 72.5"
    var kichThuocMau: String       // VD: "72.5 × 72.5"
    var chenhLechKichThuoc: String // VD: "+2.1% Đạt"
    var nhanDinh: String

    init(
        gia: String = "",
        mucDo: String = "XANH",
        actTor: String = "",
        phanTramCoKhi: String = "",
        torqueMotor: String = "",
        tension: String = "",
        elongation: String = "",
        kichThuocThucTe: String = "",
        kichThuocMau: String = "",
        chenhLechKichThuoc: String = "",
        nhanDinh: String = ""
    ) {
        self.gia = gia
        self.mucDo = mucDo
        self.actTor = actTor
        self.phanTramCoKhi = phanTramCoKhi
        self.torqueMotor = torqueMotor
        self.tension = tension
        self.elongation = elongation
        self.kichThuocThucTe = kichThuocThucTe
        self.kichThuocMau = kichThuocMau
        self.chenhLechKichThuoc = chenhLechKichThuoc
        self.nhanDinh = nhanDinh
    }

    enum CodingKeys: String, CodingKey {
        case gia, mucDo, actTor, phanTramCoKhi, torqueMotor, tension, elongation, kichThuocThucTe, kichThuocMau, chenhLechKichThuoc, nhanDinh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.gia = (try? c.decodeIfPresent(String.self, forKey: .gia)) ?? ""
        self.mucDo = (try? c.decodeIfPresent(String.self, forKey: .mucDo)) ?? "XANH"
        self.actTor = (try? c.decodeIfPresent(String.self, forKey: .actTor)) ?? ""
        self.phanTramCoKhi = (try? c.decodeIfPresent(String.self, forKey: .phanTramCoKhi)) ?? ""
        self.torqueMotor = (try? c.decodeIfPresent(String.self, forKey: .torqueMotor)) ?? ""
        self.tension = (try? c.decodeIfPresent(String.self, forKey: .tension)) ?? ""
        self.elongation = (try? c.decodeIfPresent(String.self, forKey: .elongation)) ?? ""
        self.kichThuocThucTe = (try? c.decodeIfPresent(String.self, forKey: .kichThuocThucTe)) ?? ""
        self.kichThuocMau = (try? c.decodeIfPresent(String.self, forKey: .kichThuocMau)) ?? ""
        self.chenhLechKichThuoc = (try? c.decodeIfPresent(String.self, forKey: .chenhLechKichThuoc)) ?? ""
        self.nhanDinh = (try? c.decodeIfPresent(String.self, forKey: .nhanDinh)) ?? ""
    }
}

struct BuocXuLyCanAI: Codable, Hashable {
    var thuTu: Int
    var tieuDe: String
    var chiTiet: String
    var mucChinhCuThe: String   // VD: "Nới S06 từng bước 1.0 mm (tổng 2.0–3.0 mm), giữ nguyên S07"

    init(thuTu: Int = 1, tieuDe: String = "", chiTiet: String = "", mucChinhCuThe: String = "") {
        self.thuTu = thuTu
        self.tieuDe = tieuDe
        self.chiTiet = chiTiet
        self.mucChinhCuThe = mucChinhCuThe
    }
}

struct KetQuaChanDoanCan: Codable, Hashable, Identifiable {
    var id: String
    var thoiGian: Date
    var cheDo: CheDoChanDoanCan
    var kichThuocPhoi: String
    var mucDoTongThe: String    // "NGUY_HIEM", "CANH_BAO", "ON_DINH"
    var nhietDoPhoi: String     // VD: "P1: 989 °C | Ra lò: 876 °C"
    var tomTatNguyenNhan: String
    var danhSachGia: [ThongSoGiaCanAI]
    var cacBuocXuLy: [BuocXuLyCanAI]
    var canhBaoRuiRo: [String]
    var ghiChuTWS: String
    var modelSuDung: String

    init(
        id: String = UUID().uuidString,
        thoiGian: Date = Date(),
        cheDo: CheDoChanDoanCan = .moMenXoan,
        kichThuocPhoi: String = "150x150 mm",
        mucDoTongThe: String = "CANH_BAO",
        nhietDoPhoi: String = "",
        tomTatNguyenNhan: String = "",
        danhSachGia: [ThongSoGiaCanAI] = [],
        cacBuocXuLy: [BuocXuLyCanAI] = [],
        canhBaoRuiRo: [String] = [],
        ghiChuTWS: String = "",
        modelSuDung: String = ""
    ) {
        self.id = id
        self.thoiGian = thoiGian
        self.cheDo = cheDo
        self.kichThuocPhoi = kichThuocPhoi
        self.mucDoTongThe = mucDoTongThe
        self.nhietDoPhoi = nhietDoPhoi
        self.tomTatNguyenNhan = tomTatNguyenNhan
        self.danhSachGia = danhSachGia
        self.cacBuocXuLy = cacBuocXuLy
        self.canhBaoRuiRo = canhBaoRuiRo
        self.ghiChuTWS = ghiChuTWS
        self.modelSuDung = modelSuDung
    }

    func xuatVanBanCopy() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm dd/MM/yyyy"
        var lines: [String] = []
        lines.append("🔧 CHẨN ĐOÁN XƯỞNG CÁN (\(cheDo.tieuDeNgan)) — \(df.string(from: thoiGian))")
        lines.append("• Cỡ phôi: \(kichThuocPhoi) | Mức độ: \(mucDoTongThe)")
        if !nhietDoPhoi.isEmpty { lines.append("• Nhiệt độ phôi: \(nhietDoPhoi)") }
        lines.append("")
        lines.append("📌 TÓM TẮT NGUYÊN NHÂN:")
        lines.append(tomTatNguyenNhan)

        if !danhSachGia.isEmpty {
            lines.append("")
            lines.append("📊 THÔNG SỐ CÁC GIÁ CHÍNH:")
            for g in danhSachGia {
                let icon = g.mucDo == "DO" ? "🔴" : (g.mucDo == "VANG" ? "🟡" : "🟢")
                var row = "\(icon) \(g.gia): \(g.actTor) (\(g.phanTramCoKhi))"
                if !g.torqueMotor.isEmpty { row += " | Motor: \(g.torqueMotor)" }
                if !g.tension.isEmpty { row += " | Tension: \(g.tension)" }
                if !g.elongation.isEmpty { row += " | Elong: \(g.elongation)" }
                lines.append(row)
                if !g.kichThuocThucTe.isEmpty {
                    let mauStr = g.kichThuocMau.isEmpty ? "" : " | Mẫu: \(g.kichThuocMau)"
                    let lechStr = g.chenhLechKichThuoc.isEmpty ? "" : " (\(g.chenhLechKichThuoc))"
                    lines.append("   📐 Thực tế: \(g.kichThuocThucTe)\(mauStr)\(lechStr)")
                }
                if !g.nhanDinh.isEmpty { lines.append("   → \(g.nhanDinh)") }
            }
        }

        if !cacBuocXuLy.isEmpty {
            lines.append("")
            lines.append("✅ HƯỚNG XỬ LÝ ƯU TIÊN:")
            for b in cacBuocXuLy {
                lines.append("\(b.thuTu). \(b.tieuDe)")
                if !b.mucChinhCuThe.isEmpty { lines.append("   ▸ Mức chỉnh: \(b.mucChinhCuThe)") }
                if !b.chiTiet.isEmpty { lines.append("   ▸ Chi tiết: \(b.chiTiet)") }
            }
        }

        if !canhBaoRuiRo.isEmpty {
            lines.append("")
            lines.append("⚠️ LƯU Ý RỦI RO KHI CHỈNH:")
            for r in canhBaoRuiRo {
                lines.append("• \(r)")
            }
        }

        if !ghiChuTWS.isEmpty {
            lines.append("")
            lines.append("💾 THAO TÁC TWS: \(ghiChuTWS)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - 2. Kho lưu lịch sử chẩn đoán cục bộ (Tối đa 25 bản ghi gần nhất)

final class KhoLichSuChanDoanCan {
    static let dungChung = KhoLichSuChanDoanCan()
    private let tepLuu: URL
    private(set) var danhSach: [KetQuaChanDoanCan] = []

    private init() {
        tepLuu = ThuMucDuLieu.dungChung.thuMuc.appendingPathComponent("lich-su-chan-doan-can.json")
        if let ds = ThuMucDuLieu.dungChung.doc([KetQuaChanDoanCan].self, tu: tepLuu) {
            danhSach = ds
        }
    }

    func them(_ ketQua: KetQuaChanDoanCan) {
        danhSach.insert(ketQua, at: 0)
        if danhSach.count > 25 {
            danhSach = Array(danhSach.prefix(25))
        }
        ThuMucDuLieu.dungChung.ghi(danhSach, vao: tepLuu)
    }

    func xoa(tai chiSo: Int) {
        guard chiSo >= 0, chiSo < danhSach.count else { return }
        danhSach.remove(at: chiSo)
        ThuMucDuLieu.dungChung.ghi(danhSach, vao: tepLuu)
    }
}


// MARK: - 2B. Mô hình & Kho lưu Hệ thống lỗ hình mẫu K9 – K20 theo từng Sản phẩm

struct ThongSoLoHinhGia: Codable, Hashable {
    var gia: String          // "K9" ... "K20"
    var loaiLoHinh: String   // "Hộp", "Ôvan", "Tròn", "Dẹt", "Tách đôi"
    var chieuRongTK: Double  // B thiết kế (mm), 0 = không sử dụng giá này
    var chieuCaoTK: Double   // H thiết kế (mm), 0 = không sử dụng giá này
    var gapTK: Double        // Gap thiết kế (mm)
    var soNhanh: Int         // 1 (đơn) hoặc 2 (sau tách đôi 2 nhánh)

    var heSoHinhHoc: Double {
        let l = loaiLoHinh.lowercased()
        if l.contains("hộp") || l.contains("hop") || l.contains("dẹt") || l.contains("det") { return 0.90 }
        if l.contains("ôvan") || l.contains("ovan") || l.contains("oval") { return 0.74 }
        return 0.785 // Tròn / mặc định
    }

    var coSuDung: Bool {
        chieuRongTK > 0 && chieuCaoTK > 0
    }
}

struct HeLoHinhSanPham: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var tenSanPham: String
    var kichThuocPhoiMacDinh: String = "150x150 mm"
    var danhSachGia: [ThongSoLoHinhGia]

    func moTaChoAI() -> String {
        let dung = danhSachGia.filter { $0.coSuDung }
        guard !dung.isEmpty else { return "" }
        return dung.map { g in
            let nhanhStr = g.soNhanh > 1 ? " | \(g.soNhanh) nhánh" : ""
            return "- \(g.gia) (\(g.loaiLoHinh)): \(String(format: "%.2f", g.chieuRongTK)) x \(String(format: "%.2f", g.chieuCaoTK)) mm | Gap TK: \(String(format: "%.2f", g.gapTK)) mm\(nhanhStr)"
        }.joined(separator: "\n")
    }

    static func danhSachGiaRongK9K20() -> [ThongSoLoHinhGia] {
        (9...20).map { so in
            let loai = (so % 2 == 1) ? "Ôvan" : "Tròn"
            return ThongSoLoHinhGia(gia: "K\(so)", loaiLoHinh: loai, chieuRongTK: 0, chieuCaoTK: 0, gapTK: 0, soNhanh: 1)
        }
    }

    static func mauDB2x14() -> HeLoHinhSanPham {
        let ds: [ThongSoLoHinhGia] = [
            ThongSoLoHinhGia(gia: "K9",  loaiLoHinh: "Dẹt",      chieuRongTK: 61.10, chieuCaoTK: 35.00, gapTK: 35.50, soNhanh: 1),
            ThongSoLoHinhGia(gia: "K10", loaiLoHinh: "Hộp",      chieuRongTK: 53.00, chieuCaoTK: 36.00, gapTK: 9.80,  soNhanh: 1),
            ThongSoLoHinhGia(gia: "K11", loaiLoHinh: "Dẹt",      chieuRongTK: 55.50, chieuCaoTK: 31.00, gapTK: 31.00, soNhanh: 1),
            ThongSoLoHinhGia(gia: "K12", loaiLoHinh: "Hộp",      chieuRongTK: 51.70, chieuCaoTK: 31.40, gapTK: 6.70,  soNhanh: 1),
            ThongSoLoHinhGia(gia: "K13", loaiLoHinh: "Tách đôi", chieuRongTK: 54.80, chieuCaoTK: 30.80, gapTK: 4.00,  soNhanh: 1),
            ThongSoLoHinhGia(gia: "K14", loaiLoHinh: "Tách đôi", chieuRongTK: 59.20, chieuCaoTK: 27.50, gapTK: 1.50,  soNhanh: 1),
            ThongSoLoHinhGia(gia: "K15", loaiLoHinh: "Ôvan",     chieuRongTK: 70.40, chieuCaoTK: 16.50, gapTK: 3.00,  soNhanh: 2),
            ThongSoLoHinhGia(gia: "K16", loaiLoHinh: "Tròn",     chieuRongTK: 43.20, chieuCaoTK: 21.60, gapTK: 3.00,  soNhanh: 2),
            ThongSoLoHinhGia(gia: "K17", loaiLoHinh: "Ôvan",     chieuRongTK: 26.56, chieuCaoTK: 13.90, gapTK: 2.20,  soNhanh: 2),
            ThongSoLoHinhGia(gia: "K18", loaiLoHinh: "Tròn",     chieuRongTK: 17.53, chieuCaoTK: 17.32, gapTK: 1.93,  soNhanh: 2),
            ThongSoLoHinhGia(gia: "K19", loaiLoHinh: "Ôvan",     chieuRongTK: 21.57, chieuCaoTK: 9.68,  gapTK: 1.78,  soNhanh: 2),
            ThongSoLoHinhGia(gia: "K20", loaiLoHinh: "Tròn",     chieuRongTK: 13.84, chieuCaoTK: 13.84, gapTK: 2.80,  soNhanh: 2)
        ]
        return HeLoHinhSanPham(tenSanPham: "DB 2x14 (D14)", kichThuocPhoiMacDinh: "150x150 mm", danhSachGia: ds)
    }
}

final class KhoHeLoHinhSanPham {
    static let dungChung = KhoHeLoHinhSanPham()
    private let tepLuu: URL
    private let kIdDangChon = "TRO_LY_CAN_SAN_PHAM_DANG_CHON_ID"
    private(set) var danhSach: [HeLoHinhSanPham] = []

    var idDangChon: String? {
        get { UserDefaults.standard.string(forKey: kIdDangChon) }
        set { UserDefaults.standard.setValue(newValue, forKey: kIdDangChon) }
    }

    var sanPhamDangChon: HeLoHinhSanPham? {
        if let id = idDangChon, let found = danhSach.first(where: { $0.id == id }) {
            return found
        }
        return danhSach.first
    }

    private init() {
        tepLuu = ThuMucDuLieu.dungChung.thuMuc.appendingPathComponent("he-lo-hinh-san-pham.json")
        if let ds = ThuMucDuLieu.dungChung.doc([HeLoHinhSanPham].self, tu: tepLuu), !ds.isEmpty {
            danhSach = ds
        } else {
            let mau = HeLoHinhSanPham.mauDB2x14()
            danhSach = [mau]
            idDangChon = mau.id
            luuXuongMay()
        }
    }

    func luuHoacCapNhat(_ sp: HeLoHinhSanPham) {
        if let idx = danhSach.firstIndex(where: { $0.id == sp.id }) {
            danhSach[idx] = sp
        } else {
            danhSach.append(sp)
        }
        idDangChon = sp.id
        luuXuongMay()
    }

    func xoa(id: String) {
        danhSach.removeAll { $0.id == id }
        if idDangChon == id {
            idDangChon = danhSach.first?.id
        }
        luuXuongMay()
    }

    private func luuXuongMay() {
        ThuMucDuLieu.dungChung.ghi(danhSach, vao: tepLuu)
    }
}

// MARK: - 3. Màn hình chính: Trợ Lý Cán (Chụp ảnh HMI / TWS -> AI Chẩn đoán & Đưa hướng giải quyết)

final class ManHinhTroLyCan: UIViewController,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate,
                              PHPickerViewControllerDelegate {

    private enum LoaiAnhDangChon {
        case hmi
        case tws
        case k9k20
    }

    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    private var cheDoChon: CheDoChanDoanCan = .moMenXoan
    private var kichThuocPhoiChon: String = "150x150 mm"
        private let nutChonSanPham = UIButton(type: .system)
    private let nutQuanLyLoHinh = UIButton(type: .system)
    private var anhHMI: UIImage?
    private var anhTWS: UIImage?
    private var anhK9K20: UIImage?
    private var loaiAnhDangChon: LoaiAnhDangChon = .hmi
    private var dangPhanTich: Bool = false
    private var ketQuaHienTai: KetQuaChanDoanCan?

    private let chonCheDo = UISegmentedControl(items: CheDoChanDoanCan.allCases.map(\.tieuDeNgan))
    private let lbMoTaCheDo = UILabel()
    private let oCoPhoi = UITextField()
    private let oGapThucTe = UITextField()
    private let oGhiChu = UITextField()
    private let nutPhanTich = UIButton(type: .system)
    private let vongXoay = UIActivityIndicatorView(style: .medium)
    private let lbTrangThai = UILabel()

    private let anhXemTruocHMI = UIImageView()
    private let anhXemTruocTWS = UIImageView()
    private let anhXemTruocK9K20 = UIImageView()
    private let lbTrangThaiHMI = UILabel()
    private let lbTrangThaiTWS = UILabel()
    private let lbTrangThaiK9K20 = UILabel()
    private let nutXoaHMI = UIButton(type: .system)
    private let nutXoaTWS = UIButton(type: .system)
    private let nutXoaK9K20 = UIButton(type: .system)

    private var cacNutCoPhoi: [UIButton] = []
    private let khungKetQua = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Trợ Lý Cán"
        cauHinhNutThanhTieuDe()
        taoGiaoDien()
        capNhatMauSac()

        if let ganNhat = KhoLichSuChanDoanCan.dungChung.danhSach.first {
            ketQuaHienTai = ganNhat
            hienThiKetQua(ganNhat)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiCaiDatThayDoi),
            name: .caiDatThayDoi,
            object: nil
        )

        let cham = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        cham.cancelsTouchesInView = false
        view.addGestureRecognizer(cham)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func anBanPhim() {
        view.endEditing(true)
    }

    @objc private func khiCaiDatThayDoi() {
        capNhatMauSac()
        if let kq = ketQuaHienTai {
            hienThiKetQua(kq)
        }
    }

    private func cauHinhNutThanhTieuDe() {
        let nutTinh = UIBarButtonItem(
            image: UIImage(systemName: "function"),
            style: .plain,
            target: self,
            action: #selector(moMayTinhMoMen)
        )
        nutTinh.accessibilityLabel = "Tính mô-men xoắn"

        let nutLichSu = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            style: .plain,
            target: self,
            action: #selector(moLichSuChanDoan)
        )
        nutLichSu.accessibilityLabel = "Lịch sử chẩn đoán"

        navigationItem.rightBarButtonItems = [nutLichSu, nutTinh]
    }

    // MARK: - Xây dựng giao diện

    private func taoGiaoDien() {
        cuon.alwaysBounceVertical = true
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 12
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 12),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -36),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        // 1. Thẻ Chọn Chuyên đề & Cỡ phôi
        let theCauHinh = taoThe()
        let nganCH = taoNganBenTrong(theCauHinh)

        chonCheDo.selectedSegmentIndex = 0
        chonCheDo.addTarget(self, action: #selector(khiDoiCheDo), for: .valueChanged)
        nganCH.addArrangedSubview(chonCheDo)

        lbMoTaCheDo.font = .systemFont(ofSize: 12.5)
        lbMoTaCheDo.numberOfLines = 0
        lbMoTaCheDo.text = cheDoChon.moTaChuyenDe
        nganCH.addArrangedSubview(lbMoTaCheDo)

        let lbPhoi = UILabel()
        lbPhoi.text = "Cỡ phôi đầu vào:"
        lbPhoi.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lbPhoi.tag = 901

        let dsPhoi = ["150x150 mm", "165x165 mm"]
        let hangPhoi = UIStackView()
        hangPhoi.axis = .horizontal
        hangPhoi.spacing = 5
        hangPhoi.distribution = .fillEqually
        cacNutCoPhoi.removeAll()
        for co in dsPhoi {
            let b = UIButton(type: .system)
            b.setTitle(co.replacingOccurrences(of: " mm", with: ""), for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            b.layer.cornerRadius = 8
            b.heightAnchor.constraint(equalToConstant: 30).isActive = true
            b.addAction(UIAction { [weak self] _ in
                self?.kichThuocPhoiChon = co
                self?.oCoPhoi.text = co
                self?.capNhatTrangThaiNutPhoi()
            }, for: .touchUpInside)
            cacNutCoPhoi.append(b)
            hangPhoi.addArrangedSubview(b)
        }

        oCoPhoi.borderStyle = .roundedRect
        oCoPhoi.font = .systemFont(ofSize: 13)
        oCoPhoi.text = kichThuocPhoiChon
        oCoPhoi.placeholder = "Hoặc nhập cỡ phôi khác (VD: 130x130, 140x140, 150x180...)"
        oCoPhoi.clearButtonMode = .whileEditing
        oCoPhoi.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let txt = self.oCoPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.kichThuocPhoiChon = txt.isEmpty ? "150x150 mm" : txt
            self.capNhatTrangThaiNutPhoi()
        }, for: .editingChanged)

        nganCH.addArrangedSubview(lbPhoi)
        nganCH.addArrangedSubview(hangPhoi)
        nganCH.addArrangedSubview(oCoPhoi)

        let lbSP = UILabel()
        lbSP.text = "Sản phẩm & Hệ lỗ hình K9–K20 (chọn mẫu đã lưu):"
        lbSP.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lbSP.tag = 901

        nutChonSanPham.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        nutChonSanPham.layer.cornerRadius = 8
        nutChonSanPham.heightAnchor.constraint(equalToConstant: 36).isActive = true
        nutChonSanPham.addTarget(self, action: #selector(bamChonSanPhamDaLuu), for: .touchUpInside)

        nutQuanLyLoHinh.setTitle("⚙️ Lỗ hình mẫu", for: .normal)
        nutQuanLyLoHinh.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nutQuanLyLoHinh.layer.cornerRadius = 8
        nutQuanLyLoHinh.heightAnchor.constraint(equalToConstant: 36).isActive = true
        nutQuanLyLoHinh.widthAnchor.constraint(equalToConstant: 118).isActive = true
        nutQuanLyLoHinh.addTarget(self, action: #selector(moQuanLyLoHinhMau), for: .touchUpInside)

        let hangSP = UIStackView(arrangedSubviews: [nutChonSanPham, nutQuanLyLoHinh])
        hangSP.axis = .horizontal
        hangSP.spacing = 8
        nganCH.addArrangedSubview(lbSP)
        nganCH.addArrangedSubview(hangSP)

        oGapThucTe.borderStyle = .roundedRect
        oGapThucTe.font = .systemFont(ofSize: 13)
        oGapThucTe.placeholder = "Gap thực tế nếu khác thiết kế (VD: 6V=11.5, 7H=9.0...)"
        oGapThucTe.clearButtonMode = .whileEditing
        nganCH.addArrangedSubview(oGapThucTe)

        oGhiChu.borderStyle = .roundedRect
        oGhiChu.font = .systemFont(ofSize: 13)
        oGhiChu.placeholder = "Ghi chú thêm (tùy chọn, VD: Đang cán D14, S06 hay báo đỏ...)"
        oGhiChu.clearButtonMode = .whileEditing
        nganCH.addArrangedSubview(oGhiChu)

        nganChinh.addArrangedSubview(theCauHinh)

        // 2. Khu vực chụp / chọn 2 ảnh (HMI Bargraph + TWS Setup)
        let theAnh = taoThe()
        let nganAnh = taoNganBenTrong(theAnh)

        let lbTieuDeAnh = UILabel()
        lbTieuDeAnh.text = "📸 CHỤP / CHỌN ẢNH THÔNG SỐ CÁN"
        lbTieuDeAnh.font = .systemFont(ofSize: 11.5, weight: .bold)
        lbTieuDeAnh.tag = 902
        nganAnh.addArrangedSubview(lbTieuDeAnh)

        let hangHaiAnh = UIStackView(arrangedSubviews: [
            taoOChonAnh(
                tieuDe: "1. HMI K1–K8",
                phuDe: "Torque, Act/Des, P1",
                imgView: anhXemTruocHMI,
                lbTT: lbTrangThaiHMI,
                nutXoa: nutXoaHMI,
                loai: .hmi
            ),
            taoOChonAnh(
                tieuDe: "2. Bảng TWS",
                phuDe: "Elong, Lead, D, Loop",
                imgView: anhXemTruocTWS,
                lbTT: lbTrangThaiTWS,
                nutXoa: nutXoaTWS,
                loai: .tws
            )
        ])
        hangHaiAnh.axis = .horizontal
        hangHaiAnh.spacing = 10
        hangHaiAnh.distribution = .fillEqually
        nganAnh.addArrangedSubview(hangHaiAnh)

        let oAnhK9K20 = taoOChonAnh(
            tieuDe: "3. Ảnh TWS / HMI K9–K20 (Elongation, Loop...)",
            phuDe: "Chụp phần K9–K20 trên TWS hoặc HMI S09–S20 (tùy chọn)",
            imgView: anhXemTruocK9K20,
            lbTT: lbTrangThaiK9K20,
            nutXoa: nutXoaK9K20,
            loai: .k9k20
        )
        nganAnh.addArrangedSubview(oAnhK9K20)

        // Nút Phân tích chính
        nutPhanTich.setTitle("🔍 Phân tích thông số & Đưa hướng xử lý", for: .normal)
        nutPhanTich.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        nutPhanTich.setTitleColor(.white, for: .normal)
        nutPhanTich.layer.cornerRadius = 11
        nutPhanTich.heightAnchor.constraint(equalToConstant: 46).isActive = true
        nutPhanTich.addTarget(self, action: #selector(bamPhanTich), for: .touchUpInside)
        nganAnh.addArrangedSubview(nutPhanTich)

        let hangTT = UIStackView(arrangedSubviews: [vongXoay, lbTrangThai])
        hangTT.axis = .horizontal
        hangTT.spacing = 8
        hangTT.alignment = .center
        vongXoay.hidesWhenStopped = true
        lbTrangThai.font = .systemFont(ofSize: 12.5)
        lbTrangThai.numberOfLines = 0
        lbTrangThai.isHidden = true
        nganAnh.addArrangedSubview(hangTT)

        nganChinh.addArrangedSubview(theAnh)

        // 3. Khung hiển thị kết quả chẩn đoán
        khungKetQua.axis = .vertical
        khungKetQua.spacing = 10
        nganChinh.addArrangedSubview(khungKetQua)
    }

    private func taoOChonAnh(
        tieuDe: String,
        phuDe: String,
        imgView: UIImageView,
        lbTT: UILabel,
        nutXoa: UIButton,
        loai: LoaiAnhDangChon
    ) -> UIView {
        let khung = UIView()
        khung.layer.cornerRadius = 10
        khung.layer.borderWidth = 1
        khung.tag = 910

        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 6
        st.translatesAutoresizingMaskIntoConstraints = false
        khung.addSubview(st)

        let lb1 = UILabel()
        lb1.text = tieuDe
        lb1.font = .systemFont(ofSize: 12.5, weight: .bold)
        lb1.tag = 901

        let lb2 = UILabel()
        lb2.text = phuDe
        lb2.font = .systemFont(ofSize: 11)
        lb2.tag = 902

        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        imgView.layer.cornerRadius = 8
        imgView.backgroundColor = UIColor.systemGray5
        imgView.heightAnchor.constraint(equalToConstant: 105).isActive = true
        imgView.isUserInteractionEnabled = true
        imgView.image = UIImage(systemName: "camera.viewfinder")
        imgView.contentMode = .center
        let hanhDongChon: Selector = (loai == .hmi) ? #selector(bamChonAnhHMI) : ((loai == .tws) ? #selector(bamChonAnhTWS) : #selector(bamChonAnhK9K20))
        imgView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: hanhDongChon))

        lbTT.text = "Chạm để chụp / chọn"
        lbTT.font = .systemFont(ofSize: 11, weight: .medium)
        lbTT.textAlignment = .center
        lbTT.tag = 902

        let nutChup = UIButton(type: .system)
        nutChup.setTitle("📷 Chụp / Chọn", for: .normal)
        nutChup.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        nutChup.layer.cornerRadius = 7
        nutChup.heightAnchor.constraint(equalToConstant: 30).isActive = true
        nutChup.tag = 920
        nutChup.addTarget(self, action: hanhDongChon, for: .touchUpInside)

        nutXoa.setTitle("✕ Xóa ảnh", for: .normal)
        nutXoa.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        nutXoa.isHidden = true
        nutXoa.addAction(UIAction { [weak self] _ in
            switch loai {
            case .hmi: self?.anhHMI = nil
            case .tws: self?.anhTWS = nil
            case .k9k20: self?.anhK9K20 = nil
            }
            self?.capNhatXemTruocAnh()
        }, for: .touchUpInside)

        st.addArrangedSubview(lb1)
        st.addArrangedSubview(lb2)
        st.addArrangedSubview(imgView)
        st.addArrangedSubview(lbTT)
        st.addArrangedSubview(nutChup)
        st.addArrangedSubview(nutXoa)

        NSLayoutConstraint.activate([
            st.topAnchor.constraint(equalTo: khung.topAnchor, constant: 8),
            st.bottomAnchor.constraint(equalTo: khung.bottomAnchor, constant: -8),
            st.leadingAnchor.constraint(equalTo: khung.leadingAnchor, constant: 8),
            st.trailingAnchor.constraint(equalTo: khung.trailingAnchor, constant: -8)
        ])
        return khung
    }

    private func capNhatMauSac() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        chonCheDo.selectedSegmentTintColor = mau.xuongCanAccent
        chonCheDo.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 12.5, weight: .bold)], for: .selected)
        chonCheDo.setTitleTextAttributes([.foregroundColor: mau.text, .font: UIFont.systemFont(ofSize: 12.5, weight: .medium)], for: .normal)

        lbMoTaCheDo.textColor = mau.subText
        lbTrangThai.textColor = mau.subText
        nutPhanTich.backgroundColor = mau.xuongCanAccent
        nutXoaHMI.setTitleColor(mau.error, for: .normal)
        nutXoaTWS.setTitleColor(mau.error, for: .normal)
        nutXoaK9K20.setTitleColor(mau.error, for: .normal)

        capNhatMauDeQuy(trong: view, mau: mau)
        capNhatTrangThaiNutPhoi()
        capNhatXemTruocAnh()
    }

    private func capNhatMauDeQuy(trong v: UIView, mau: BangMauChuDe) {
        if v.tag == 900 {
            v.backgroundColor = mau.card
            v.layer.borderColor = mau.border.cgColor
        } else if v.tag == 910 {
            v.backgroundColor = mau.iconBg
            v.layer.borderColor = mau.border.cgColor
        } else if v.tag == 901, let lb = v as? UILabel {
            lb.textColor = mau.text
        } else if v.tag == 902, let lb = v as? UILabel {
            lb.textColor = mau.subText
        } else if v.tag == 920, let b = v as? UIButton {
            b.backgroundColor = mau.primary.withAlphaComponent(0.14)
            b.setTitleColor(mau.primary, for: .normal)
        }
        for sub in v.subviews {
            capNhatMauDeQuy(trong: sub, mau: mau)
        }
    }

    private func capNhatTrangThaiNutPhoi() {
        let mau = KhoDuLieu.dungChung.mauSac
        let dsPhoi = ["150x150 mm", "165x165 mm"]
        for (idx, b) in cacNutCoPhoi.enumerated() where idx < dsPhoi.count {
            let dangChon = (dsPhoi[idx] == kichThuocPhoiChon)
            b.backgroundColor = dangChon ? mau.primary : mau.iconBg
            b.setTitleColor(dangChon ? .white : mau.text, for: .normal)
        }
        let spHienTai = KhoHeLoHinhSanPham.dungChung.sanPhamDangChon
        let tenSP = spHienTai?.tenSanPham ?? "Chưa chọn sản phẩm"
        nutChonSanPham.setTitle("📦 \(tenSP) ▾", for: .normal)
        nutChonSanPham.backgroundColor = mau.xuongCanAccent.withAlphaComponent(0.15)
        nutChonSanPham.setTitleColor(mau.xuongCanAccent, for: .normal)
        nutQuanLyLoHinh.backgroundColor = mau.primary.withAlphaComponent(0.14)
        nutQuanLyLoHinh.setTitleColor(mau.primary, for: .normal)
    }

    private func capNhatXemTruocAnh() {
        let mau = KhoDuLieu.dungChung.mauSac
        if let a = anhHMI {
            anhXemTruocHMI.image = a
            anhXemTruocHMI.contentMode = .scaleAspectFill
            lbTrangThaiHMI.text = "✓ Đã chọn ảnh HMI"
            lbTrangThaiHMI.textColor = mau.success
            nutXoaHMI.isHidden = false
        } else {
            anhXemTruocHMI.image = UIImage(systemName: "camera.viewfinder")
            anhXemTruocHMI.contentMode = .center
            anhXemTruocHMI.tintColor = mau.subText
            lbTrangThaiHMI.text = "Chạm để chụp / chọn"
            lbTrangThaiHMI.textColor = mau.subText
            nutXoaHMI.isHidden = true
        }

        if let b = anhTWS {
            anhXemTruocTWS.image = b
            anhXemTruocTWS.contentMode = .scaleAspectFill
            lbTrangThaiTWS.text = "✓ Đã chọn ảnh TWS"
            lbTrangThaiTWS.textColor = mau.success
            nutXoaTWS.isHidden = false
        } else {
            anhXemTruocTWS.image = UIImage(systemName: "tablecells.badge.ellipsis")
            anhXemTruocTWS.contentMode = .center
            anhXemTruocTWS.tintColor = mau.subText
            lbTrangThaiTWS.text = "Tùy chọn (nên thêm)"
            lbTrangThaiTWS.textColor = mau.subText
            nutXoaTWS.isHidden = true
        }

        if let c = anhK9K20 {
            anhXemTruocK9K20.image = c
            anhXemTruocK9K20.contentMode = .scaleAspectFill
            lbTrangThaiK9K20.text = "✓ Đã chọn ảnh K9–K20"
            lbTrangThaiK9K20.textColor = mau.success
            nutXoaK9K20.isHidden = false
        } else {
            anhXemTruocK9K20.image = UIImage(systemName: "photo.stack")
            anhXemTruocK9K20.contentMode = .center
            anhXemTruocK9K20.tintColor = mau.subText
            lbTrangThaiK9K20.text = "Tùy chọn (áp dụng cho K9–K20)"
            lbTrangThaiK9K20.textColor = mau.subText
            nutXoaK9K20.isHidden = true
        }
    }

    // MARK: - Hành động người dùng

    @objc private func bamChonSanPhamDaLuu() {
        let ds = KhoHeLoHinhSanPham.dungChung.danhSach
        let sheet = UIAlertController(
            title: "📦 Chọn hệ lỗ hình sản phẩm (K9–K20)",
            message: "Dùng tự động cho AI phân tích và máy tính cỡ phôi",
            preferredStyle: .actionSheet
        )
        for sp in ds {
            let dangChon = (sp.id == KhoHeLoHinhSanPham.dungChung.sanPhamDangChon?.id)
            let title = (dangChon ? "✓ " : "") + "\(sp.tenSanPham) (Phôi \(sp.kichThuocPhoiMacDinh))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                KhoHeLoHinhSanPham.dungChung.idDangChon = sp.id
                self?.kichThuocPhoiChon = sp.kichThuocPhoiMacDinh
                self?.oCoPhoi.text = sp.kichThuocPhoiMacDinh
                self?.capNhatTrangThaiNutPhoi()
            })
        }
        sheet.addAction(UIAlertAction(title: "➕ Thêm / Sửa hệ lỗ hình mẫu...", style: .default) { [weak self] _ in
            self?.moQuanLyLoHinhMau()
        })
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = nutChonSanPham
            pop.sourceRect = nutChonSanPham.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func moQuanLyLoHinhMau() {
        let vc = ManHinhQuanLyLoHinh { [weak self] in
            if let sp = KhoHeLoHinhSanPham.dungChung.sanPhamDangChon {
                self?.kichThuocPhoiChon = sp.kichThuocPhoiMacDinh
                self?.oCoPhoi.text = sp.kichThuocPhoiMacDinh
            }
            self?.capNhatTrangThaiNutPhoi()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func khiDoiCheDo() {
        let idx = chonCheDo.selectedSegmentIndex
        guard idx >= 0, idx < CheDoChanDoanCan.allCases.count else { return }
        cheDoChon = CheDoChanDoanCan.allCases[idx]
        lbMoTaCheDo.text = cheDoChon.moTaChuyenDe
    }

    @objc private func bamChonAnhHMI() {
        loaiAnhDangChon = .hmi
        hienMenuChonNguonAnh(tieuDe: "Ảnh màn hình HMI Bargraph")
    }

    @objc private func bamChonAnhTWS() {
        loaiAnhDangChon = .tws
        hienMenuChonNguonAnh(tieuDe: "Ảnh bảng Parameters Setup (TWS)")
    }

    @objc private func bamChonAnhK9K20() {
        loaiAnhDangChon = .k9k20
        hienMenuChonNguonAnh(tieuDe: "Ảnh TWS / HMI khu vực K9–K20")
    }

    private func hienMenuChonNguonAnh(tieuDe: String) {
        view.endEditing(true)
        let sheet = UIAlertController(title: tieuDe, message: "Chọn nguồn ảnh để AI đọc thông số", preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "📷 Chụp ảnh trực tiếp (Camera)", style: .default) { [weak self] _ in
                self?.moCamera()
            })
        }
        sheet.addAction(UIAlertAction(title: "🖼️ Chọn từ Thư viện ảnh", style: .default) { [weak self] _ in
            self?.moThuVienAnh()
        })
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func moCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func moThuVienAnh() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            ganAnhDaChon(img)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let img = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self?.ganAnhDaChon(img)
            }
        }
    }

    private func ganAnhDaChon(_ anh: UIImage) {
        switch loaiAnhDangChon {
        case .hmi: anhHMI = anh
        case .tws: anhTWS = anh
        case .k9k20: anhK9K20 = anh
        }
        capNhatXemTruocAnh()
    }

    // MARK: - Gọi Gemini AI Phân tích

    @objc private func bamPhanTich() {
        view.endEditing(true)
        guard !dangPhanTich else { return }

        guard anhHMI != nil || anhTWS != nil || anhK9K20 != nil else {
            hienThongBao("Chưa có ảnh thông số", "Hãy chụp hoặc chọn ít nhất 1 ảnh (HMI K1–K8, bảng TWS hoặc ảnh K9–K20) trước khi bấm phân tích.")
            return
        }

        let key = KhoDuLieu.dungChung.caiDat.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            hienHopThoaiNhapKeyNhanh()
            return
        }

        dangPhanTich = true
        nutPhanTich.isEnabled = false
        nutPhanTich.alpha = 0.6
        vongXoay.startAnimating()
        lbTrangThai.isHidden = false
        lbTrangThai.text = "Đang đọc số liệu từ ảnh và phân tích phương án xử lý (\(KhoDuLieu.dungChung.caiDat.tenHienThiModelGemini))..."

        let coPhoiThucTe = oCoPhoi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !coPhoiThucTe.isEmpty { kichThuocPhoiChon = coPhoiThucTe }
        let gapStr = oGapThucTe.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ghiChu = oGhiChu.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let spChon = KhoHeLoHinhSanPham.dungChung.sanPhamDangChon
        DichVuGemini.dungChung.phanTichThongSoCan(
            anhHMI: anhHMI,
            anhTWS: anhTWS,
            anhK9K20: anhK9K20,
            cheDo: cheDoChon,
            kichThuocPhoi: kichThuocPhoiChon,
            quyCachSanPham: spChon?.tenSanPham ?? "Chưa chọn",
            heLoHinhK9K20: spChon?.moTaChoAI() ?? "",
            gapThucTe: gapStr,
            ghiChuThem: ghiChu
        ) { [weak self] kq in
            guard let self else { return }
            self.dangPhanTich = false
            self.nutPhanTich.isEnabled = true
            self.nutPhanTich.alpha = 1.0
            self.vongXoay.stopAnimating()

            switch kq {
            case .success(let duLieu):
                self.lbTrangThai.text = "✅ Phân tích xong bằng \(DichVuGemini.tenThanThien(cua: duLieu.modelSuDung))"
                self.ketQuaHienTai = duLieu
                KhoLichSuChanDoanCan.dungChung.them(duLieu)
                self.hienThiKetQua(duLieu)
            case .failure(let err):
                self.lbTrangThai.text = "❌ \(err.localizedDescription)"
                self.hienThongBao("Không thể phân tích", err.localizedDescription)
            }
        }
    }

    // MARK: - Hiển thị kết quả chẩn đoán trực quan

    private func hienThiKetQua(_ kq: KetQuaChanDoanCan) {
        khungKetQua.arrangedSubviews.forEach {
            khungKetQua.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let mau = KhoDuLieu.dungChung.mauSac

        // 1. Thẻ Tổng quan
        let theTQ = taoThe()
        let nganTQ = taoNganBenTrong(theTQ)

        let mauTrangThai: UIColor
        let nhanMucDo: String
        switch kq.mucDoTongThe.uppercased() {
        case "NGUY_HIEM":
            mauTrangThai = mau.error
            nhanMucDo = "🔴 NGUY HIỂM — CẦN XỬ LÝ NGAY"
        case "ON_DINH":
            mauTrangThai = mau.success
            nhanMucDo = "🟢 ỔN ĐỊNH"
        default:
            mauTrangThai = .systemOrange
            nhanMucDo = "🟡 CẢNH BÁO — CẦN THEO DÕI / SAN TẢI"
        }

        let lbBanner = UILabel()
        lbBanner.text = nhanMucDo
        lbBanner.font = .systemFont(ofSize: 13.5, weight: .bold)
        lbBanner.textColor = mauTrangThai
        nganTQ.addArrangedSubview(lbBanner)

        let df = DateFormatter()
        df.dateFormat = "HH:mm dd/MM/yyyy"
        let lbMeta = UILabel()
        var metaText = "\(kq.cheDo.tieuDeNgan) • Phôi \(kq.kichThuocPhoi) • \(df.string(from: kq.thoiGian))"
        if !kq.nhietDoPhoi.isEmpty {
            metaText += "\n🌡️ \(kq.nhietDoPhoi)"
        }
        lbMeta.text = metaText
        lbMeta.font = .systemFont(ofSize: 12, weight: .medium)
        lbMeta.textColor = mau.subText
        lbMeta.numberOfLines = 0
        nganTQ.addArrangedSubview(lbMeta)

        let lbTomTat = UILabel()
        lbTomTat.text = kq.tomTatNguyenNhan
        lbTomTat.font = .systemFont(ofSize: 13.5)
        lbTomTat.textColor = mau.text
        lbTomTat.numberOfLines = 0
        nganTQ.addArrangedSubview(lbTomTat)

        // Nút Copy báo cáo
        let nutCopy = UIButton(type: .system)
        nutCopy.setTitle("📋 Copy toàn bộ hướng xử lý", for: .normal)
        nutCopy.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nutCopy.setTitleColor(mau.primary, for: .normal)
        nutCopy.backgroundColor = mau.primary.withAlphaComponent(0.12)
        nutCopy.layer.cornerRadius = 8
        nutCopy.heightAnchor.constraint(equalToConstant: 34).isActive = true
        nutCopy.addAction(UIAction { [weak self] _ in
            UIPasteboard.general.string = kq.xuatVanBanCopy()
            self?.hienThongBao("Đã sao chép ✅", "Toàn bộ kết quả chẩn đoán và hướng xử lý đã được copy vào bộ nhớ tạm.")
        }, for: .touchUpInside)
        nganTQ.addArrangedSubview(nutCopy)

        khungKetQua.addArrangedSubview(theTQ)

        // 2. Các bước xử lý ưu tiên
        if !kq.cacBuocXuLy.isEmpty {
            let theXL = taoThe()
            let nganXL = taoNganBenTrong(theXL)

            let lbTD = UILabel()
            lbTD.text = "✅ HƯỚNG GIẢI QUYẾT ƯU TIÊN"
            lbTD.font = .systemFont(ofSize: 12, weight: .bold)
            lbTD.textColor = mau.primary
            nganXL.addArrangedSubview(lbTD)

            for buoc in kq.cacBuocXuLy {
                let hop = UIView()
                hop.backgroundColor = mau.iconBg
                hop.layer.cornerRadius = 9
                let st = UIStackView()
                st.axis = .vertical
                st.spacing = 4
                st.translatesAutoresizingMaskIntoConstraints = false
                hop.addSubview(st)

                let lbT = UILabel()
                lbT.text = "\(buoc.thuTu). \(buoc.tieuDe)"
                lbT.font = .systemFont(ofSize: 13.5, weight: .bold)
                lbT.textColor = mau.text
                lbT.numberOfLines = 0
                st.addArrangedSubview(lbT)

                if !buoc.mucChinhCuThe.isEmpty {
                    let lbM = UILabel()
                    lbM.text = "▸ Mức chỉnh: \(buoc.mucChinhCuThe)"
                    lbM.font = .systemFont(ofSize: 13, weight: .semibold)
                    lbM.textColor = mau.xuongCanAccent
                    lbM.numberOfLines = 0
                    st.addArrangedSubview(lbM)
                }

                if !buoc.chiTiet.isEmpty {
                    let lbC = UILabel()
                    lbC.text = buoc.chiTiet
                    lbC.font = .systemFont(ofSize: 12.5)
                    lbC.textColor = mau.subText
                    lbC.numberOfLines = 0
                    st.addArrangedSubview(lbC)
                }

                NSLayoutConstraint.activate([
                    st.topAnchor.constraint(equalTo: hop.topAnchor, constant: 8),
                    st.bottomAnchor.constraint(equalTo: hop.bottomAnchor, constant: -8),
                    st.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 10),
                    st.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -10)
                ])
                nganXL.addArrangedSubview(hop)
            }

            if !kq.ghiChuTWS.isEmpty {
                let lbTWS = UILabel()
                lbTWS.text = "💾 Lưu ý TWS: \(kq.ghiChuTWS)"
                lbTWS.font = .systemFont(ofSize: 12.5, weight: .medium)
                lbTWS.textColor = mau.primary
                lbTWS.numberOfLines = 0
                nganXL.addArrangedSubview(lbTWS)
            }

            khungKetQua.addArrangedSubview(theXL)
        }

        // 2B. Bảng so sánh kích thước vật cán thực tế vs Mẫu bảng cán (K1 – K20)
        let dsCoKT = kq.danhSachGia.filter { !$0.kichThuocThucTe.isEmpty || !$0.kichThuocMau.isEmpty }
        if !dsCoKT.isEmpty {
            let theBangKT = taoThe()
            let nganBangKT = taoNganBenTrong(theBangKT)

            let lbTD = UILabel()
            lbTD.text = "📐 SO SÁNH KÍCH THƯỚC VẬT CÁN THỰC TẾ VS MẪU (K1–K20)"
            lbTD.font = .systemFont(ofSize: 11.5, weight: .bold)
            lbTD.textColor = mau.primary
            lbTD.numberOfLines = 0
            nganBangKT.addArrangedSubview(lbTD)

            let hdr = taoDongBangSoSanh(
                c1: "Giá",
                c2: "Thực tế (mm)",
                c3: "Mẫu bảng cán",
                c4: "So sánh",
                laHeader: true,
                mauSoSanh: mau.subText,
                mau: mau
            )
            nganBangKT.addArrangedSubview(hdr)

            for (idx, g) in dsCoKT.enumerated() {
                let lechLower = g.chenhLechKichThuoc.lowercased()
                let mauSS: UIColor
                if lechLower.contains("tràn") || lechLower.contains("vượt") || lechLower.contains("cao") {
                    mauSS = mau.error
                } else if lechLower.contains("non") || lechLower.contains("thiếu") || lechLower.contains("nhỏ") {
                    mauSS = .systemOrange
                } else {
                    mauSS = mau.success
                }
                let dong = taoDongBangSoSanh(
                    c1: g.gia.components(separatedBy: " ").first ?? g.gia,
                    c2: g.kichThuocThucTe.isEmpty ? "-" : g.kichThuocThucTe,
                    c3: g.kichThuocMau.isEmpty ? "-" : g.kichThuocMau,
                    c4: g.chenhLechKichThuoc.isEmpty ? "-" : g.chenhLechKichThuoc,
                    laHeader: false,
                    mauSoSanh: mauSS,
                    mau: mau,
                    nenXenKe: (idx % 2 == 1)
                )
                nganBangKT.addArrangedSubview(dong)
            }
            khungKetQua.addArrangedSubview(theBangKT)
        }

        // 3. Bảng chi tiết từng giá cán
        if !kq.danhSachGia.isEmpty {
            let theGia = taoThe()
            let nganGia = taoNganBenTrong(theGia)

            let lbTD = UILabel()
            lbTD.text = "📊 CHI TIẾT THÔNG SỐ CÁC GIÁ ĐỌC ĐƯỢC"
            lbTD.font = .systemFont(ofSize: 12, weight: .bold)
            lbTD.textColor = mau.subText
            nganGia.addArrangedSubview(lbTD)

            for g in kq.danhSachGia {
                let hop = UIView()
                hop.backgroundColor = mau.iconBg
                hop.layer.cornerRadius = 9
                hop.layer.borderWidth = 1

                let mauVien: UIColor
                let icon: String
                switch g.mucDo.uppercased() {
                case "DO":
                    mauVien = mau.error
                    icon = "🔴"
                case "VANG":
                    mauVien = .systemOrange
                    icon = "🟡"
                default:
                    mauVien = mau.border
                    icon = "🟢"
                }
                hop.layer.borderColor = mauVien.withAlphaComponent(0.6).cgColor

                let st = UIStackView()
                st.axis = .vertical
                st.spacing = 3
                st.translatesAutoresizingMaskIntoConstraints = false
                hop.addSubview(st)

                let lbDau = UILabel()
                lbDau.text = "\(icon) \(g.gia)  •  \(g.actTor)  (\(g.phanTramCoKhi))"
                lbDau.font = .systemFont(ofSize: 13, weight: .bold)
                lbDau.textColor = (g.mucDo.uppercased() == "DO") ? mau.error : mau.text
                lbDau.numberOfLines = 0
                st.addArrangedSubview(lbDau)

                var thongSoPhu: [String] = []
                if !g.torqueMotor.isEmpty { thongSoPhu.append("Motor: \(g.torqueMotor)") }
                if !g.tension.isEmpty { thongSoPhu.append("Tension: \(g.tension)") }
                if !g.elongation.isEmpty { thongSoPhu.append("Elong: \(g.elongation)") }
                if !thongSoPhu.isEmpty {
                    let lbPhu = UILabel()
                    lbPhu.text = thongSoPhu.joined(separator: "  |  ")
                    lbPhu.font = .monospacedSystemFont(ofSize: 11.5, weight: .medium)
                    lbPhu.textColor = mau.subText
                    lbPhu.numberOfLines = 0
                    st.addArrangedSubview(lbPhu)
                }

                if !g.kichThuocThucTe.isEmpty {
                    let lbKT = UILabel()
                    lbKT.text = "📐 Phôi thực tế: \(g.kichThuocThucTe)"
                    lbKT.font = .systemFont(ofSize: 12, weight: .semibold)
                    lbKT.textColor = mau.primary
                    lbKT.numberOfLines = 0
                    st.addArrangedSubview(lbKT)
                }

                if !g.nhanDinh.isEmpty {
                    let lbND = UILabel()
                    lbND.text = "→ \(g.nhanDinh)"
                    lbND.font = .systemFont(ofSize: 12.5)
                    lbND.textColor = mau.text
                    lbND.numberOfLines = 0
                    st.addArrangedSubview(lbND)
                }

                NSLayoutConstraint.activate([
                    st.topAnchor.constraint(equalTo: hop.topAnchor, constant: 8),
                    st.bottomAnchor.constraint(equalTo: hop.bottomAnchor, constant: -8),
                    st.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 10),
                    st.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -10)
                ])
                nganGia.addArrangedSubview(hop)
            }

            khungKetQua.addArrangedSubview(theGia)
        }

        // 4. Cảnh báo rủi ro khi chỉnh
        if !kq.canhBaoRuiRo.isEmpty {
            let theRR = taoThe()
            let nganRR = taoNganBenTrong(theRR)

            let lbTD = UILabel()
            lbTD.text = "⚠️ RỦI RO CẦN CANH CHỪNG KHI THAO TÁC"
            lbTD.font = .systemFont(ofSize: 12, weight: .bold)
            lbTD.textColor = .systemOrange
            nganRR.addArrangedSubview(lbTD)

            for rr in kq.canhBaoRuiRo {
                let lb = UILabel()
                lb.text = "• \(rr)"
                lb.font = .systemFont(ofSize: 12.5)
                lb.textColor = mau.text
                lb.numberOfLines = 0
                nganRR.addArrangedSubview(lb)
            }

            khungKetQua.addArrangedSubview(theRR)
        }
    }

    // MARK: - Công cụ phụ: Máy tính Mô-men xoắn ngoại tuyến & Lịch sử chẩn đoán

    @objc private func moMayTinhMoMen() {
        let sheet = UIAlertController(
            title: "🧮 Công cụ tính toán cán thô",
            message: "Chạy ngoại tuyến ngay tại xưởng không cần mạng",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "📐 Tính kích thước phôi thực tế (1H – 8V)", style: .default) { [weak self] _ in
            guard let self else { return }
            let vc = ManHinhTinhKichThuocPhoi(coPhoiMacDinh: self.kichThuocPhoiChon)
            self.present(UINavigationController(rootViewController: vc), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "⚡ Tính nhanh Mô-men xoắn (9550×P/n)", style: .default) { [weak self] _ in
            self?.moHopThoaiTinhMoMen()
        })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.maxX - 40, y: 80, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func moHopThoaiTinhMoMen() {
        let alert = UIAlertController(
            title: "🧮 Tính nhanh Mô-men xoắn",
            message: "Công thức: T (Nm) = (9550 × P × η) ÷ n",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Công suất P (kW), VD: 800"
            tf.keyboardType = .decimalPad
        }
        alert.addTextField { tf in
            tf.placeholder = "Tốc độ quay n (RPM), VD: 1100"
            tf.keyboardType = .decimalPad
        }
        alert.addTextField { tf in
            tf.placeholder = "Hiệu suất hộp số η (%), mặc định 95"
            tf.text = "95"
            tf.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        alert.addAction(UIAlertAction(title: "Tính ngay", style: .default) { [weak self] _ in
            let pStr = (alert.textFields?[0].text ?? "").replacingOccurrences(of: ",", with: ".")
            let nStr = (alert.textFields?[1].text ?? "").replacingOccurrences(of: ",", with: ".")
            let eStr = (alert.textFields?[2].text ?? "95").replacingOccurrences(of: ",", with: ".")
            guard let p = Double(pStr), let n = Double(nStr), n > 0 else {
                self?.hienThongBao("Thiếu số liệu", "Hãy nhập hợp lệ Công suất P (kW) và Tốc độ quay n (> 0 RPM).")
                return
            }
            let eta = (Double(eStr) ?? 95.0) / 100.0
            let tLyThuyet = (9550.0 * p) / n
            let tThuc = tLyThuyet * eta
            let msg = String(
                format: "• Mô-men lý thuyết: %.1f Nm (%.2f kNm)\n• Mô-men thực (η=%.0f%%): %.1f Nm (%.2f kNm)",
                tLyThuyet, tLyThuyet / 1000.0, eta * 100.0, tThuc, tThuc / 1000.0
            )
            self?.hienThongBao("Kết quả Mô-men xoắn", msg)
        })
        present(alert, animated: true)
    }

    @objc private func moLichSuChanDoan() {
        let ds = KhoLichSuChanDoanCan.dungChung.danhSach
        guard !ds.isEmpty else {
            hienThongBao("Lịch sử trống", "Chưa có lần phân tích nào được lưu. Hãy chụp ảnh HMI/TWS để bắt đầu!")
            return
        }
        let df = DateFormatter()
        df.dateFormat = "HH:mm dd/MM"
        let sheet = UIAlertController(title: "📜 Lịch sử chẩn đoán gần đây", message: "Chọn để xem lại & đối chiếu trước/sau chỉnh", preferredStyle: .actionSheet)
        for item in ds.prefix(10) {
            let icon = item.mucDoTongThe == "NGUY_HIEM" ? "🔴" : (item.mucDoTongThe == "ON_DINH" ? "🟢" : "🟡")
            let title = "\(icon) \(df.string(from: item.thoiGian)) • \(item.cheDo.tieuDeNgan) (\(item.kichThuocPhoi))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.ketQuaHienTai = item
                self?.hienThiKetQua(item)
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func hienHopThoaiNhapKeyNhanh() {
        let alert = UIAlertController(
            title: "🔑 Chưa có Gemini API Key",
            message: "Dán Gemini API Key để kích hoạt Trợ Lý Cán (dùng chung với tab Lệnh SX & Cài đặt).",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "AIzaSy..."
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu & Phân tích", style: .default) { [weak self] _ in
            let k = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !k.isEmpty else { return }
            var cd = KhoDuLieu.dungChung.caiDat
            cd.geminiApiKey = k
            KhoDuLieu.dungChung.luuCaiDat(cd, thongBao: true)
            self?.bamPhanTich()
        })
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func taoDongBangSoSanh(
        c1: String,
        c2: String,
        c3: String,
        c4: String,
        laHeader: Bool,
        mauSoSanh: UIColor,
        mau: BangMauChuDe,
        nenXenKe: Bool = false
    ) -> UIView {
        let wrap = UIView()
        wrap.layer.cornerRadius = 6
        if laHeader {
            wrap.backgroundColor = mau.primary.withAlphaComponent(0.14)
        } else if nenXenKe {
            wrap.backgroundColor = mau.iconBg
        } else {
            wrap.backgroundColor = .clear
        }

        func taoO(_ txt: String, weight: UIFont.Weight, color: UIColor, align: NSTextAlignment, width: CGFloat? = nil) -> UILabel {
            let lb = UILabel()
            lb.text = txt
            lb.font = laHeader ? .systemFont(ofSize: 11, weight: .bold) : .monospacedDigitSystemFont(ofSize: 11, weight: weight)
            lb.textColor = color
            lb.textAlignment = align
            lb.numberOfLines = 0
            if let w = width { lb.widthAnchor.constraint(equalToConstant: w).isActive = true }
            return lb
        }

        let l1 = taoO(c1, weight: .bold, color: laHeader ? mau.primary : mau.text, align: .left, width: 42)
        let l2 = taoO(c2, weight: .semibold, color: laHeader ? mau.primary : mau.text, align: .center)
        let l3 = taoO(c3, weight: .regular, color: laHeader ? mau.primary : mau.subText, align: .center)
        let l4 = taoO(c4, weight: .semibold, color: laHeader ? mau.primary : mauSoSanh, align: .right, width: 82)

        let st = UIStackView(arrangedSubviews: [l1, l2, l3, l4])
        st.axis = .horizontal
        st.spacing = 4
        st.alignment = .center
        st.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(st)
        NSLayoutConstraint.activate([
            st.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 5),
            st.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -5),
            st.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 6),
            st.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -6)
        ])
        return wrap
    }

    private func taoThe() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let v = UIView()
        v.backgroundColor = mau.card
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = mau.border.cgColor
        v.tag = 900
        return v
    }

    private func taoNganBenTrong(_ the: UIView) -> UIStackView {
        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 8
        st.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(st)
        NSLayoutConstraint.activate([
            st.topAnchor.constraint(equalTo: the.topAnchor, constant: 12),
            st.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -12),
            st.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            st.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])
        return st
    }

    private func hienThongBao(_ tieuDe: String, _ noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}


// MARK: - 4. Máy tính kích thước vật cán thực tế qua 1H – 8V (Từ Cỡ phôi + Elongation + Gap thực tế)

final class ManHinhTinhKichThuocPhoi: UIViewController {
    private struct CauHinhGiaTho {
        let ten: String
        let loaiLoHinh: String   // "Hộp", "Ôvan", "Tròn"
        let heSoHinh: Double     // Hộp 0.92, Tròn 0.785, Ôvan 0.74
        let bTK: Double          // Rộng thiết kế (mm)
        let hTK: Double          // Cao thiết kế (mm)
        let gapTK: Double        // Gap thiết kế (mm)
        let elongMacDinh: Double // Elongation mặc định từ TWS
    }

    private let dsGiaChuan: [CauHinhGiaTho] = [
        CauHinhGiaTho(ten: "1H (K1)", loaiLoHinh: "Hộp",  heSoHinh: 0.920, bTK: 162.0, hTK: 108.0, gapTK: 15.0, elongMacDinh: 1.307),
        CauHinhGiaTho(ten: "2V (K2)", loaiLoHinh: "Hộp",  heSoHinh: 0.920, bTK: 119.0, hTK: 119.0, gapTK: 15.0, elongMacDinh: 1.246),
        CauHinhGiaTho(ten: "3H (K3)", loaiLoHinh: "Ôvan", heSoHinh: 0.740, bTK: 138.0, hTK: 81.5,  gapTK: 12.0, elongMacDinh: 1.350),
        CauHinhGiaTho(ten: "4V (K4)", loaiLoHinh: "Tròn", heSoHinh: 0.785, bTK: 99.0,  hTK: 99.0,  gapTK: 12.0, elongMacDinh: 1.355),
        CauHinhGiaTho(ten: "5H (K5)", loaiLoHinh: "Ôvan", heSoHinh: 0.740, bTK: 112.6, hTK: 60.0,  gapTK: 10.0, elongMacDinh: 1.326),
        CauHinhGiaTho(ten: "6V (K6)", loaiLoHinh: "Tròn", heSoHinh: 0.785, bTK: 72.5,  hTK: 72.5,  gapTK: 10.0, elongMacDinh: 1.313),
        CauHinhGiaTho(ten: "7H (K7)", loaiLoHinh: "Ôvan", heSoHinh: 0.740, bTK: 87.0,  hTK: 43.6,  gapTK: 8.8,  elongMacDinh: 1.273),
        CauHinhGiaTho(ten: "8V (K8)", loaiLoHinh: "Tròn", heSoHinh: 0.785, bTK: 54.5,  hTK: 54.5,  gapTK: 8.5,  elongMacDinh: 1.357)
    ]

    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()
    private let chonPhoi = UISegmentedControl(items: ["150×150 mm", "165×165 mm"])
    private let oPhoiTuyChinh = UITextField()
    private var cacOElong: [UITextField] = []
    private var cacOGap: [UITextField] = []
    private let khungKetQua = UIStackView()

    private var coPhoiBanDau: String

    init(coPhoiMacDinh: String = "150x150 mm") {
        self.coPhoiBanDau = coPhoiMacDinh
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "📐 Cỡ phôi thực tế (1H–8V)"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dongManHinh))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Tính lại", style: .done, target: self, action: #selector(tinhVaHienThi))

        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        cuon.alwaysBounceVertical = true
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 10
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 12),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -40),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        taoGiaoDienNhap()
        khungKetQua.axis = .vertical
        khungKetQua.spacing = 8
        nganChinh.addArrangedSubview(khungKetQua)
        tinhVaHienThi()

        let cham = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        cham.cancelsTouchesInView = false
        view.addGestureRecognizer(cham)
    }

    @objc private func dongManHinh() { dismiss(animated: true) }
    @objc private func anBanPhim() { view.endEditing(true) }

    private func taoGiaoDienNhap() {
        let mau = KhoDuLieu.dungChung.mauSac

        // 1. Chọn phôi đầu vào
        let thePhoi = taoThe(mau: mau)
        let stPhoi = taoNgan(thePhoi)

        let lb1 = UILabel()
        lb1.text = "1. Kích thước phôi đầu vào (mặc định 150×150 hoặc 165×165):"
        lb1.font = .systemFont(ofSize: 12.5, weight: .bold)
        lb1.textColor = mau.text
        lb1.numberOfLines = 0
        stPhoi.addArrangedSubview(lb1)

        chonPhoi.selectedSegmentIndex = coPhoiBanDau.contains("165") ? 1 : 0
        chonPhoi.selectedSegmentTintColor = mau.primary
        chonPhoi.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        chonPhoi.setTitleTextAttributes([.foregroundColor: mau.text, .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        chonPhoi.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.oPhoiTuyChinh.text = (self.chonPhoi.selectedSegmentIndex == 1) ? "165x165" : "150x150"
            self.tinhVaHienThi()
        }, for: .valueChanged)
        stPhoi.addArrangedSubview(chonPhoi)

        oPhoiTuyChinh.borderStyle = .roundedRect
        oPhoiTuyChinh.font = .systemFont(ofSize: 13)
        oPhoiTuyChinh.text = coPhoiBanDau.contains("165") ? "165x165" : "150x150"
        oPhoiTuyChinh.placeholder = "Hoặc nhập cỡ khác (VD: 140x140, 150x180)"
        oPhoiTuyChinh.addAction(UIAction { [weak self] _ in self?.tinhVaHienThi() }, for: .editingDidEnd)
        stPhoi.addArrangedSubview(oPhoiTuyChinh)
        nganChinh.addArrangedSubview(thePhoi)

        // 2. Bảng nhập Elongation & Gap thực tế cho 1H–8V
        let theBang = taoThe(mau: mau)
        let stBang = taoNgan(theBang)

        let lb2 = UILabel()
        lb2.text = "2. Nhập Elongation (dòng xanh TWS) & Gap thực tế (mm):"
        lb2.font = .systemFont(ofSize: 12.5, weight: .bold)
        lb2.textColor = mau.text
        stBang.addArrangedSubview(lb2)

        let header = UIStackView(arrangedSubviews: [
            taoNhanCot("Giá / Lỗ hình", mau: mau.subText, align: .left),
            taoNhanCot("Elongation", mau: mau.subText, align: .center),
            taoNhanCot("Gap thực (mm)", mau: mau.subText, align: .center)
        ])
        header.distribution = .fillEqually
        stBang.addArrangedSubview(header)

        cacOElong.removeAll()
        cacOGap.removeAll()
        for g in dsGiaChuan {
            let lbTen = UILabel()
            lbTen.text = "\(g.ten) • \(g.loaiLoHinh)"
            lbTen.font = .systemFont(ofSize: 12.5, weight: .semibold)
            lbTen.textColor = mau.text

            let tfE = UITextField()
            tfE.borderStyle = .roundedRect
            tfE.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
            tfE.textAlignment = .center
            tfE.keyboardType = .decimalPad
            tfE.text = String(format: "%.3f", g.elongMacDinh)

            let tfG = UITextField()
            tfG.borderStyle = .roundedRect
            tfG.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
            tfG.textAlignment = .center
            tfG.keyboardType = .decimalPad
            tfG.text = String(format: "%.1f", g.gapTK)

            cacOElong.append(tfE)
            cacOGap.append(tfG)

            let row = UIStackView(arrangedSubviews: [lbTen, tfE, tfG])
            row.spacing = 6
            row.distribution = .fillEqually
            row.alignment = .center
            stBang.addArrangedSubview(row)
        }

        let nutTinh = UIButton(type: .system)
        nutTinh.setTitle("📐 Tính kích thước vật cán thực tế", for: .normal)
        nutTinh.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        nutTinh.setTitleColor(.white, for: .normal)
        nutTinh.backgroundColor = mau.xuongCanAccent
        nutTinh.layer.cornerRadius = 10
        nutTinh.heightAnchor.constraint(equalToConstant: 42).isActive = true
        nutTinh.addTarget(self, action: #selector(tinhVaHienThi), for: .touchUpInside)
        stBang.addArrangedSubview(nutTinh)

        nganChinh.addArrangedSubview(theBang)
    }

    private func docDienTichPhoiBanDau() -> (a0: Double, nhan: String) {
        let raw = (oPhoiTuyChinh.text ?? "150x150")
            .lowercased()
            .replacingOccurrences(of: "mm", with: "")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: " ", with: "")
        let parts = raw.components(separatedBy: "x").compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        if parts.count >= 2, parts[0] > 50, parts[1] > 50 {
            return (parts[0] * parts[1], "\(Int(parts[0]))×\(Int(parts[1])) mm")
        }
        return (22500.0, "150×150 mm")
    }

    @objc private func tinhVaHienThi() {
        view.endEditing(true)
        khungKetQua.arrangedSubviews.forEach {
            khungKetQua.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let mau = KhoDuLieu.dungChung.mauSac
        let (a0, nhanPhoi) = docDienTichPhoiBanDau()

        let theKQ = taoThe(mau: mau)
        let stKQ = taoNgan(theKQ)

        let lbTD = UILabel()
        lbTD.text = "📐 BẢNG SO SÁNH KÍCH THƯỚC VẬT CÁN K1–K20 (Phôi \(nhanPhoi))"
        lbTD.font = .systemFont(ofSize: 12, weight: .bold)
        lbTD.textColor = mau.primary
        lbTD.numberOfLines = 0
        stKQ.addArrangedSubview(lbTD)

        func taoDong(_ c1: String, _ c2: String, _ c3: String, _ c4: String, laHeader: Bool, mauSS: UIColor, xenKe: Bool = false) -> UIView {
            let wrap = UIView()
            wrap.layer.cornerRadius = 6
            wrap.backgroundColor = laHeader ? mau.primary.withAlphaComponent(0.14) : (xenKe ? mau.iconBg : .clear)
            func o(_ t: String, w: UIFont.Weight, c: UIColor, al: NSTextAlignment, width: CGFloat? = nil) -> UILabel {
                let lb = UILabel()
                lb.text = t
                lb.font = laHeader ? .systemFont(ofSize: 11, weight: .bold) : .monospacedDigitSystemFont(ofSize: 11, weight: w)
                lb.textColor = c
                lb.textAlignment = al
                lb.numberOfLines = 0
                if let ww = width { lb.widthAnchor.constraint(equalToConstant: ww).isActive = true }
                return lb
            }
            let st = UIStackView(arrangedSubviews: [
                o(c1, w: .bold, c: laHeader ? mau.primary : mau.text, al: .left, width: 46),
                o(c2, w: .semibold, c: laHeader ? mau.primary : mau.text, al: .center),
                o(c3, w: .regular, c: laHeader ? mau.primary : mau.subText, al: .center),
                o(c4, w: .semibold, c: laHeader ? mau.primary : mauSS, al: .right, width: 78)
            ])
            st.axis = .horizontal
            st.spacing = 4
            st.alignment = .center
            st.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(st)
            NSLayoutConstraint.activate([
                st.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 5),
                st.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -5),
                st.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 6),
                st.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -6)
            ])
            return wrap
        }

        stKQ.addArrangedSubview(taoDong("Giá", "Thực tế (mm)", "Mẫu bảng cán", "So sánh", laHeader: true, mauSS: mau.subText))

        var aHienTai = a0
        var demDong = 0
        for (idx, g) in dsGiaChuan.enumerated() {
            let eStr = (idx < cacOElong.count ? cacOElong[idx].text : nil)?.replacingOccurrences(of: ",", with: ".") ?? ""
            let gStr = (idx < cacOGap.count ? cacOGap[idx].text : nil)?.replacingOccurrences(of: ",", with: ".") ?? ""
            let elong = max(1.01, Double(eStr) ?? g.elongMacDinh)
            let gapThuc = Double(gStr) ?? g.gapTK

            let aRa = aHienTai / elong
            let hThuc = max(10.0, g.hTK + (gapThuc - g.gapTK))
            let bThuc = aRa / (g.heSoHinh * hThuc)
            let tyLeLechB = ((bThuc - g.bTK) / g.bTK) * 100.0

            let ssText: String
            let mauCB: UIColor
            if tyLeLechB > 4.5 {
                ssText = String(format: "+%.1f%% Tràn", tyLeLechB)
                mauCB = mau.error
            } else if tyLeLechB < -5.5 {
                ssText = String(format: "%.1f%% Non", tyLeLechB)
                mauCB = .systemOrange
            } else {
                ssText = String(format: "%+.1f%% Đạt", tyLeLechB)
                mauCB = mau.success
            }

            let tenNgan = "K\(idx + 1)"
            let thucStr = String(format: "%.1f×%.1f", bThuc, hThuc)
            let mauStr = String(format: "%.1f×%.1f", g.bTK, g.hTK)
            stKQ.addArrangedSubview(taoDong(tenNgan, thucStr, mauStr, ssText, laHeader: false, mauSS: mauCB, xenKe: demDong % 2 == 1))
            demDong += 1
            aHienTai = aRa
        }

        // Tiếp nối K9–K20 theo Hệ lỗ hình mẫu đang chọn (tỉ lệ truyền sai lệch diện tích từ K8)
        if let sp = KhoHeLoHinhSanPham.dungChung.sanPhamDangChon {
            let dsK9 = sp.danhSachGia.filter { $0.coSuDung }
            if !dsK9.isEmpty {
                let lbK9 = UILabel()
                lbK9.text = "📦 K9–K20 THEO MẪU: \(sp.tenSanPham)"
                lbK9.font = .systemFont(ofSize: 11.5, weight: .bold)
                lbK9.textColor = mau.xuongCanAccent
                stKQ.addArrangedSubview(lbK9)

                let aK8TK = 0.785 * 54.5 * 54.5
                let heSoLanTruyen = (aK8TK > 0) ? (aHienTai / aK8TK) : 1.0
                for g in dsK9 {
                    // Quy đổi kích thước thực tế ước tính khi lan truyền sai lệch tiết diện từ K8 (giảm dần ảnh hưởng qua từng giá)
                    let aTK = g.heSoHinhHoc * g.chieuRongTK * g.chieuCaoTK
                    let aThucK = aTK * (1.0 + (heSoLanTruyen - 1.0) * 0.45)
                    let hThucK = g.chieuCaoTK
                    let bThucK = (g.heSoHinhHoc * hThucK > 0) ? (aThucK / (g.heSoHinhHoc * hThucK)) : g.chieuRongTK
                    let lechB = (g.chieuRongTK > 0) ? ((bThucK - g.chieuRongTK) / g.chieuRongTK) * 100.0 : 0

                    let ssText: String
                    let mauCB: UIColor
                    if lechB > 4.5 {
                        ssText = String(format: "+%.1f%% Tràn", lechB)
                        mauCB = mau.error
                    } else if lechB < -5.5 {
                        ssText = String(format: "%.1f%% Non", lechB)
                        mauCB = .systemOrange
                    } else {
                        ssText = String(format: "%+.1f%% Đạt", lechB)
                        mauCB = mau.success
                    }

                    let tenK = g.soNhanh > 1 ? "\(g.gia)*2" : g.gia
                    let thucStr = String(format: "%.1f×%.1f", bThucK, hThucK)
                    let mauStr = String(format: "%.1f×%.1f", g.chieuRongTK, g.chieuCaoTK)
                    stKQ.addArrangedSubview(taoDong(tenK, thucStr, mauStr, ssText, laHeader: false, mauSS: mauCB, xenKe: demDong % 2 == 1))
                    demDong += 1
                }
            }
        }

        khungKetQua.addArrangedSubview(theKQ)
    }

    private func taoThe(mau: BangMauChuDe) -> UIView {
        let v = UIView()
        v.backgroundColor = mau.card
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = mau.border.cgColor
        return v
    }

    private func taoNgan(_ the: UIView) -> UIStackView {
        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 8
        st.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(st)
        NSLayoutConstraint.activate([
            st.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
            st.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
            st.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 10),
            st.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -10)
        ])
        return st
    }

    private func taoNhanCot(_ txt: String, mau: UIColor, align: NSTextAlignment) -> UILabel {
        let lb = UILabel()
        lb.text = txt
        lb.font = .systemFont(ofSize: 11.5, weight: .bold)
        lb.textColor = mau
        lb.textAlignment = align
        return lb
    }
}


// MARK: - 5. Màn hình Quản lý & Nhập Hệ thống Lỗ hình mẫu K9 – K20 theo Sản phẩm

final class ManHinhQuanLyLoHinh: UITableViewController {
    private let khiCapNhat: () -> Void

    init(khiCapNhat: @escaping () -> Void) {
        self.khiCapNhat = khiCapNhat
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Hệ lỗ hình mẫu (K9–K20)"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(themMoi))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "O")
    }

    @objc private func dong() {
        khiCapNhat()
        dismiss(animated: true)
    }

    @objc private func themMoi() {
        let vc = ManHinhBienTapLoHinh(sanPham: nil) { [weak self] in
            self?.tableView.reloadData()
            self?.khiCapNhat()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        KhoHeLoHinhSanPham.dungChung.danhSach.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "O", for: indexPath)
        let sp = KhoHeLoHinhSanPham.dungChung.danhSach[indexPath.row]
        let soGia = sp.danhSachGia.filter { $0.coSuDung }.count
        let dangChon = (sp.id == KhoHeLoHinhSanPham.dungChung.sanPhamDangChon?.id)

        var cfg = cell.defaultContentConfiguration()
        cfg.text = (dangChon ? "✓ " : "") + sp.tenSanPham
        cfg.secondaryText = "Phôi mặc định: \(sp.kichThuocPhoiMacDinh) • Đã nhập \(soGia) giá (K9–K20)"
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sp = KhoHeLoHinhSanPham.dungChung.danhSach[indexPath.row]
        let vc = ManHinhBienTapLoHinh(sanPham: sp) { [weak self] in
            self?.tableView.reloadData()
            self?.khiCapNhat()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let sp = KhoHeLoHinhSanPham.dungChung.danhSach[indexPath.row]
            KhoHeLoHinhSanPham.dungChung.xoa(id: sp.id)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            khiCapNhat()
        }
    }
}

final class ManHinhBienTapLoHinh: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    private let sanPhamGoc: HeLoHinhSanPham?
    private let khiLuu: () -> Void

    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()
    private let oTenSP = UITextField()
    private let chonPhoi = UISegmentedControl(items: ["150x150 mm", "165x165 mm"])
    private let oPhoiKhac = UITextField()
    private let nutQuetAnhLoHinh = UIButton(type: .system)
    private let vongXoayQuet = UIActivityIndicatorView(style: .medium)
    private let lbTrangThaiQuet = UILabel()

    private struct HangNhapGia {
        let gia: String
        let nutLoai: UIButton
        let oB: UITextField
        let oH: UITextField
        let oGap: UITextField
        let nutNhanh: UIButton
    }
    private var cacHang: [HangNhapGia] = []
    private let dsLoaiLoHinh = ["Ôvan", "Tròn", "Hộp", "Dẹt", "Tách đôi"]

    init(sanPham: HeLoHinhSanPham?, khiLuu: @escaping () -> Void) {
        self.sanPhamGoc = sanPham
        self.khiLuu = khiLuu
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = sanPhamGoc == nil ? "Thêm lỗ hình K9–K20" : "Sửa lỗ hình"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(bamLuu))

        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        cuon.alwaysBounceVertical = true
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 10
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 12),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -40),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        taoGiaoDien()
        let cham = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        cham.cancelsTouchesInView = false
        view.addGestureRecognizer(cham)
    }

    @objc private func anBanPhim() { view.endEditing(true) }

    private func taoGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac

        // Thông tin chung sản phẩm
        let theChung = UIView()
        theChung.backgroundColor = mau.card
        theChung.layer.cornerRadius = 12
        theChung.layer.borderWidth = 1
        theChung.layer.borderColor = mau.border.cgColor

        let stC = UIStackView()
        stC.axis = .vertical
        stC.spacing = 8
        stC.translatesAutoresizingMaskIntoConstraints = false
        theChung.addSubview(stC)

        let lbTen = UILabel()
        lbTen.text = "Tên sản phẩm (VD: D10, D12, DB 2x14, D16...):"
        lbTen.font = .systemFont(ofSize: 12.5, weight: .bold)
        lbTen.textColor = mau.text

        oTenSP.borderStyle = .roundedRect
        oTenSP.font = .systemFont(ofSize: 14, weight: .semibold)
        oTenSP.placeholder = "Nhập tên sản phẩm..."
        oTenSP.text = sanPhamGoc?.tenSanPham ?? ""

        let lbPhoi = UILabel()
        lbPhoi.text = "Phôi mặc định đi kèm sản phẩm:"
        lbPhoi.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lbPhoi.textColor = mau.subText

        let phoiCu = sanPhamGoc?.kichThuocPhoiMacDinh ?? "150x150 mm"
        chonPhoi.selectedSegmentIndex = phoiCu.contains("165") ? 1 : 0
        chonPhoi.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.oPhoiKhac.text = (self.chonPhoi.selectedSegmentIndex == 1) ? "165x165 mm" : "150x150 mm"
        }, for: .valueChanged)

        oPhoiKhac.borderStyle = .roundedRect
        oPhoiKhac.font = .systemFont(ofSize: 13)
        oPhoiKhac.text = phoiCu
        oPhoiKhac.placeholder = "Hoặc nhập cỡ phôi khác..."

        nutQuetAnhLoHinh.setTitle("📸 Quét ảnh bảng lỗ hình (AI tự điền K9–K20)", for: .normal)
        nutQuetAnhLoHinh.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .bold)
        nutQuetAnhLoHinh.setTitleColor(.white, for: .normal)
        nutQuetAnhLoHinh.backgroundColor = mau.xuongCanAccent
        nutQuetAnhLoHinh.layer.cornerRadius = 10
        nutQuetAnhLoHinh.heightAnchor.constraint(equalToConstant: 42).isActive = true
        nutQuetAnhLoHinh.addTarget(self, action: #selector(bamQuetAnhLoHinh), for: .touchUpInside)

        vongXoayQuet.hidesWhenStopped = true
        lbTrangThaiQuet.font = .systemFont(ofSize: 12)
        lbTrangThaiQuet.textColor = mau.subText
        lbTrangThaiQuet.numberOfLines = 0
        lbTrangThaiQuet.isHidden = true
        let hangQuetTT = UIStackView(arrangedSubviews: [vongXoayQuet, lbTrangThaiQuet])
        hangQuetTT.axis = .horizontal
        hangQuetTT.spacing = 8
        hangQuetTT.alignment = .center

        stC.addArrangedSubview(nutQuetAnhLoHinh)
        stC.addArrangedSubview(hangQuetTT)
        stC.addArrangedSubview(lbTen)
        stC.addArrangedSubview(oTenSP)
        stC.addArrangedSubview(lbPhoi)
        stC.addArrangedSubview(chonPhoi)
        stC.addArrangedSubview(oPhoiKhac)

        NSLayoutConstraint.activate([
            stC.topAnchor.constraint(equalTo: theChung.topAnchor, constant: 10),
            stC.bottomAnchor.constraint(equalTo: theChung.bottomAnchor, constant: -10),
            stC.leadingAnchor.constraint(equalTo: theChung.leadingAnchor, constant: 10),
            stC.trailingAnchor.constraint(equalTo: theChung.trailingAnchor, constant: -10)
        ])
        nganChinh.addArrangedSubview(theChung)

        // Bảng nhập K9 – K20
        let theBang = UIView()
        theBang.backgroundColor = mau.card
        theBang.layer.cornerRadius = 12
        theBang.layer.borderWidth = 1
        theBang.layer.borderColor = mau.border.cgColor

        let stB = UIStackView()
        stB.axis = .vertical
        stB.spacing = 7
        stB.translatesAutoresizingMaskIntoConstraints = false
        theBang.addSubview(stB)

        let lbHD = UILabel()
        lbHD.text = "Nhập thông số lỗ hình K9 – K20 (Giá nào không chạy thì để trống B, H):"
        lbHD.font = .systemFont(ofSize: 12, weight: .bold)
        lbHD.textColor = mau.primary
        lbHD.numberOfLines = 0
        stB.addArrangedSubview(lbHD)

        let dsGoc = sanPhamGoc?.danhSachGia ?? HeLoHinhSanPham.danhSachGiaRongK9K20()
        cacHang.removeAll()

        for so in 9...20 {
            let tenGia = "K\(so)"
            let item = dsGoc.first(where: { $0.gia == tenGia })
                ?? ThongSoLoHinhGia(gia: tenGia, loaiLoHinh: (so % 2 == 1) ? "Ôvan" : "Tròn", chieuRongTK: 0, chieuCaoTK: 0, gapTK: 0, soNhanh: 1)

            let lbG = UILabel()
            lbG.text = tenGia
            lbG.font = .systemFont(ofSize: 12.5, weight: .bold)
            lbG.textColor = mau.text
            lbG.widthAnchor.constraint(equalToConstant: 34).isActive = true

            let nutLoai = UIButton(type: .system)
            nutLoai.setTitle(item.loaiLoHinh, for: .normal)
            nutLoai.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
            nutLoai.backgroundColor = mau.iconBg
            nutLoai.setTitleColor(mau.primary, for: .normal)
            nutLoai.layer.cornerRadius = 6
            nutLoai.widthAnchor.constraint(equalToConstant: 60).isActive = true
            nutLoai.heightAnchor.constraint(equalToConstant: 30).isActive = true
            nutLoai.addAction(UIAction { [weak self, weak nutLoai] _ in
                guard let self, let btn = nutLoai else { return }
                let cur = btn.title(for: .normal) ?? "Ôvan"
                let idx = self.dsLoaiLoHinh.firstIndex(of: cur) ?? 0
                let next = self.dsLoaiLoHinh[(idx + 1) % self.dsLoaiLoHinh.count]
                btn.setTitle(next, for: .normal)
            }, for: .touchUpInside)

            let oB = taoONhapSo(placeholder: "Rộng B", giaTri: item.chieuRongTK)
            let oH = taoONhapSo(placeholder: "Cao H", giaTri: item.chieuCaoTK)
            let oGap = taoONhapSo(placeholder: "Gap", giaTri: item.gapTK)

            let nutNhanh = UIButton(type: .system)
            nutNhanh.setTitle("\(max(1, item.soNhanh))n", for: .normal)
            nutNhanh.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .bold)
            nutNhanh.backgroundColor = mau.iconBg
            nutNhanh.setTitleColor(mau.xuongCanAccent, for: .normal)
            nutNhanh.layer.cornerRadius = 6
            nutNhanh.widthAnchor.constraint(equalToConstant: 30).isActive = true
            nutNhanh.heightAnchor.constraint(equalToConstant: 30).isActive = true
            nutNhanh.addAction(UIAction { [weak nutNhanh] _ in
                guard let btn = nutNhanh else { return }
                let cur = btn.title(for: .normal) ?? "1n"
                btn.setTitle(cur == "1n" ? "2n" : "1n", for: .normal)
            }, for: .touchUpInside)

            let hang = UIStackView(arrangedSubviews: [lbG, nutLoai, oB, oH, oGap, nutNhanh])
            hang.axis = .horizontal
            hang.spacing = 4
            hang.alignment = .center
            stB.addArrangedSubview(hang)

            cacHang.append(HangNhapGia(gia: tenGia, nutLoai: nutLoai, oB: oB, oH: oH, oGap: oGap, nutNhanh: nutNhanh))
        }

        NSLayoutConstraint.activate([
            stB.topAnchor.constraint(equalTo: theBang.topAnchor, constant: 10),
            stB.bottomAnchor.constraint(equalTo: theBang.bottomAnchor, constant: -10),
            stB.leadingAnchor.constraint(equalTo: theBang.leadingAnchor, constant: 8),
            stB.trailingAnchor.constraint(equalTo: theBang.trailingAnchor, constant: -8)
        ])
        nganChinh.addArrangedSubview(theBang)
    }

    private func taoONhapSo(placeholder: String, giaTri: Double) -> UITextField {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        tf.textAlignment = .center
        tf.keyboardType = .decimalPad
        tf.placeholder = placeholder
        if giaTri > 0 {
            tf.text = String(format: "%.2f", giaTri).replacingOccurrences(of: ".00", with: "")
        }
        return tf
    }

    @objc private func bamLuu() {
        view.endEditing(true)
        let ten = oTenSP.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !ten.isEmpty else {
            let alert = UIAlertController(title: "Thiếu tên sản phẩm", message: "Hãy nhập tên cho sản phẩm (VD: D12, DB 2x14, D16...).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .default))
            present(alert, animated: true)
            return
        }

        let phoi = (oPhoiKhac.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? (oPhoiKhac.text!.trimmingCharacters(in: .whitespacesAndNewlines))
            : "150x150 mm"

        let dsMoi: [ThongSoLoHinhGia] = cacHang.map { h in
            let b = Double((h.oB.text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
            let cao = Double((h.oH.text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
            let gap = Double((h.oGap.text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
            let loai = h.nutLoai.title(for: .normal) ?? "Ôvan"
            let nhanh = (h.nutNhanh.title(for: .normal) == "2n") ? 2 : 1
            return ThongSoLoHinhGia(gia: h.gia, loaiLoHinh: loai, chieuRongTK: b, chieuCaoTK: cao, gapTK: gap, soNhanh: nhanh)
        }

        let sp = HeLoHinhSanPham(
            id: sanPhamGoc?.id ?? UUID().uuidString,
            tenSanPham: ten,
            kichThuocPhoiMacDinh: phoi,
            danhSachGia: dsMoi
        )
        KhoHeLoHinhSanPham.dungChung.luuHoacCapNhat(sp)
        khiLuu()
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Quét ảnh bảng lỗ hình bằng Camera / Thư viện ảnh

    @objc private func bamQuetAnhLoHinh() {
        view.endEditing(true)
        let sheet = UIAlertController(
            title: "📸 Quét ảnh bảng hệ lỗ hình (K9–K20)",
            message: "Chụp hoặc chọn ảnh cột lỗ hình sản phẩm, AI sẽ tự đọc và điền sẵn toàn bộ K9–K20",
            preferredStyle: .actionSheet
        )
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "📷 Chụp ảnh trực tiếp (Camera)", style: .default) { [weak self] _ in
                guard let self else { return }
                let p = UIImagePickerController()
                p.sourceType = .camera
                p.delegate = self
                self.present(p, animated: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "🖼️ Chọn từ Thư viện ảnh", style: .default) { [weak self] _ in
            guard let self else { return }
            var cfg = PHPickerConfiguration(photoLibrary: .shared())
            cfg.selectionLimit = 1
            cfg.filter = .images
            let p = PHPickerViewController(configuration: cfg)
            p.delegate = self
            self.present(p, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = nutQuetAnhLoHinh
            pop.sourceRect = nutQuetAnhLoHinh.bounds
        }
        present(sheet, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            thucHienQuetAnhLoHinh(img)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let img = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self?.thucHienQuetAnhLoHinh(img)
            }
        }
    }

    private func thucHienQuetAnhLoHinh(_ anh: UIImage) {
        nutQuetAnhLoHinh.isEnabled = false
        nutQuetAnhLoHinh.alpha = 0.6
        vongXoayQuet.startAnimating()
        lbTrangThaiQuet.isHidden = false
        lbTrangThaiQuet.text = "Đang đọc ảnh bảng lỗ hình K9–K20 bằng AI..."

        DichVuGemini.dungChung.quetAnhBangLoHinhK9K20(anh: anh) { [weak self] kq in
            guard let self else { return }
            self.nutQuetAnhLoHinh.isEnabled = true
            self.nutQuetAnhLoHinh.alpha = 1.0
            self.vongXoayQuet.stopAnimating()

            switch kq {
            case .success(let duLieu):
                if (self.oTenSP.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !duLieu.tenGoiY.isEmpty {
                    self.oTenSP.text = duLieu.tenGoiY
                }
                // Xóa trắng bảng cũ rồi điền dữ liệu quét được
                for h in self.cacHang {
                    h.oB.text = ""
                    h.oH.text = ""
                    h.oGap.text = ""
                    h.nutNhanh.setTitle("1n", for: .normal)
                }
                for (idx, item) in duLieu.danhSachGia.enumerated() {
                    let hangMatch = self.cacHang.first(where: { $0.gia == item.gia })
                        ?? (idx < self.cacHang.count ? self.cacHang[idx] : nil)
                    guard let h = hangMatch else { continue }
                    h.nutLoai.setTitle(item.loaiLoHinh, for: .normal)
                    h.oB.text = String(format: "%.2f", item.chieuRongTK).replacingOccurrences(of: ".00", with: "")
                    h.oH.text = String(format: "%.2f", item.chieuCaoTK).replacingOccurrences(of: ".00", with: "")
                    h.oGap.text = String(format: "%.2f", item.gapTK).replacingOccurrences(of: ".00", with: "")
                    h.nutNhanh.setTitle("\(max(1, item.soNhanh))n", for: .normal)
                }
                self.lbTrangThaiQuet.text = "✅ Đã quét xong \(duLieu.danhSachGia.count) giá! Kiểm tra lại tên sản phẩm rồi bấm Lưu."
            case .failure(let err):
                self.lbTrangThaiQuet.text = "❌ \(err.localizedDescription)"
                let alert = UIAlertController(title: "Không quét được ảnh", message: err.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Đóng", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}
