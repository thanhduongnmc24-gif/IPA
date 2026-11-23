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
    var nhanDinh: String

    init(
        gia: String = "",
        mucDo: String = "XANH",
        actTor: String = "",
        phanTramCoKhi: String = "",
        torqueMotor: String = "",
        tension: String = "",
        elongation: String = "",
        nhanDinh: String = ""
    ) {
        self.gia = gia
        self.mucDo = mucDo
        self.actTor = actTor
        self.phanTramCoKhi = phanTramCoKhi
        self.torqueMotor = torqueMotor
        self.tension = tension
        self.elongation = elongation
        self.nhanDinh = nhanDinh
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

// MARK: - 3. Màn hình chính: Trợ Lý Cán (Chụp ảnh HMI / TWS -> AI Chẩn đoán & Đưa hướng giải quyết)

final class ManHinhTroLyCan: UIViewController,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate,
                              PHPickerViewControllerDelegate {

    private enum LoaiAnhDangChon {
        case hmi
        case tws
    }

    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    private var cheDoChon: CheDoChanDoanCan = .moMenXoan
    private var kichThuocPhoiChon: String = "150x150 mm"
    private var quyCachSPChon: String = "D14 (2x14)"
    private var anhHMI: UIImage?
    private var anhTWS: UIImage?
    private var loaiAnhDangChon: LoaiAnhDangChon = .hmi
    private var dangPhanTich: Bool = false
    private var ketQuaHienTai: KetQuaChanDoanCan?

    private let chonCheDo = UISegmentedControl(items: CheDoChanDoanCan.allCases.map(\.tieuDeNgan))
    private let lbMoTaCheDo = UILabel()
    private let oGapThucTe = UITextField()
    private let oGhiChu = UITextField()
    private let nutPhanTich = UIButton(type: .system)
    private let vongXoay = UIActivityIndicatorView(style: .medium)
    private let lbTrangThai = UILabel()

    private let anhXemTruocHMI = UIImageView()
    private let anhXemTruocTWS = UIImageView()
    private let lbTrangThaiHMI = UILabel()
    private let lbTrangThaiTWS = UILabel()
    private let nutXoaHMI = UIButton(type: .system)
    private let nutXoaTWS = UIButton(type: .system)

    private var cacNutCoPhoi: [UIButton] = []
    private var cacNutQuyCach: [UIButton] = []
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

        let dsPhoi = ["130x130 mm", "150x150 mm", "160x160 mm"]
        let hangPhoi = UIStackView()
        hangPhoi.axis = .horizontal
        hangPhoi.spacing = 6
        hangPhoi.distribution = .fillEqually
        cacNutCoPhoi.removeAll()
        for co in dsPhoi {
            let b = UIButton(type: .system)
            b.setTitle(co.replacingOccurrences(of: " mm", with: ""), for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
            b.layer.cornerRadius = 8
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
            b.addAction(UIAction { [weak self] _ in
                self?.kichThuocPhoiChon = co
                self?.capNhatTrangThaiNutPhoi()
            }, for: .touchUpInside)
            cacNutCoPhoi.append(b)
            hangPhoi.addArrangedSubview(b)
        }
        nganCH.addArrangedSubview(lbPhoi)
        nganCH.addArrangedSubview(hangPhoi)

        let lbSP = UILabel()
        lbSP.text = "Quy cách sản phẩm (hệ lỗ hình K9–K20):"
        lbSP.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lbSP.tag = 901

        let dsSP = ["D10", "D12", "D14 (2x14)", "D16", "D18+"]
        let hangSP = UIStackView()
        hangSP.axis = .horizontal
        hangSP.spacing = 5
        hangSP.distribution = .fillEqually
        cacNutQuyCach.removeAll()
        for sp in dsSP {
            let b = UIButton(type: .system)
            b.setTitle(sp == "D14 (2x14)" ? "D14" : sp, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            b.layer.cornerRadius = 8
            b.heightAnchor.constraint(equalToConstant: 30).isActive = true
            b.addAction(UIAction { [weak self] _ in
                self?.quyCachSPChon = sp
                self?.capNhatTrangThaiNutPhoi()
            }, for: .touchUpInside)
            cacNutQuyCach.append(b)
            hangSP.addArrangedSubview(b)
        }
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
                tieuDe: "1. Ảnh HMI Bargraph",
                phuDe: "Torque, Act/Des Tor, P1",
                imgView: anhXemTruocHMI,
                lbTT: lbTrangThaiHMI,
                nutXoa: nutXoaHMI,
                loai: .hmi
            ),
            taoOChonAnh(
                tieuDe: "2. Ảnh TWS (Tùy chọn)",
                phuDe: "Elongation, Lead, D",
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
        imgView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: loai == .hmi ? #selector(bamChonAnhHMI) : #selector(bamChonAnhTWS)))

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
        nutChup.addTarget(self, action: loai == .hmi ? #selector(bamChonAnhHMI) : #selector(bamChonAnhTWS), for: .touchUpInside)

        nutXoa.setTitle("✕ Xóa ảnh", for: .normal)
        nutXoa.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        nutXoa.isHidden = true
        nutXoa.addAction(UIAction { [weak self] _ in
            if loai == .hmi {
                self?.anhHMI = nil
            } else {
                self?.anhTWS = nil
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
        let dsPhoi = ["130x130 mm", "150x150 mm", "160x160 mm"]
        for (idx, b) in cacNutCoPhoi.enumerated() where idx < dsPhoi.count {
            let dangChon = (dsPhoi[idx] == kichThuocPhoiChon)
            b.backgroundColor = dangChon ? mau.primary : mau.iconBg
            b.setTitleColor(dangChon ? .white : mau.text, for: .normal)
        }
        let dsSP = ["D10", "D12", "D14 (2x14)", "D16", "D18+"]
        for (idx, b) in cacNutQuyCach.enumerated() where idx < dsSP.count {
            let dangChon = (dsSP[idx] == quyCachSPChon)
            b.backgroundColor = dangChon ? mau.xuongCanAccent : mau.iconBg
            b.setTitleColor(dangChon ? .white : mau.text, for: .normal)
        }
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
    }

    // MARK: - Hành động người dùng

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
        }
        capNhatXemTruocAnh()
    }

    // MARK: - Gọi Gemini AI Phân tích

    @objc private func bamPhanTich() {
        view.endEditing(true)
        guard !dangPhanTich else { return }

        guard anhHMI != nil || anhTWS != nil else {
            hienThongBao("Chưa có ảnh thông số", "Hãy chụp hoặc chọn ít nhất 1 ảnh (màn hình HMI Bargraph hoặc bảng TWS) trước khi bấm phân tích.")
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

        let gapStr = oGapThucTe.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ghiChu = oGhiChu.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        DichVuGemini.dungChung.phanTichThongSoCan(
            anhHMI: anhHMI,
            anhTWS: anhTWS,
            cheDo: cheDoChon,
            kichThuocPhoi: kichThuocPhoiChon,
            quyCachSanPham: quyCachSPChon,
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
