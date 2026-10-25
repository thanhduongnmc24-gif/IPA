import UIKit

final class ManHinhXuongCan: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let hienNutDongModal: Bool
    private var chiSoBang: Int = 0
    private var cacMaAnhDangTaiLenDrive: Set<String> = []

    // Lưu vị trí ô ảnh đang chọn để nhận kết quả từ Camera / Thư viện ảnh
    private var oAnhDangChon: (idBang: String, idDong: String, idCot: String)?

    // Giao diện siêu gọn: chỉ 1 thanh ngang 30pt chứa danh sách bảng + nút thêm nhanh, tiếp theo là lưới bảng ngay bên dưới
    private let thanhChonBangCuon = UIScrollView()
    private let nganChonBang = UIStackView()
    private let cuonNgangBang = UIScrollView()
    private let cuonDocBang = UIScrollView()
    private let nganBangDuLieu = UIStackView()

    init(hienNutDongModal: Bool = false) {
        self.hienNutDongModal = hienNutDongModal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Xưởng Cán"

        if hienNutDongModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Đóng",
                style: .done,
                target: self,
                action: #selector(dongModal)
            )
        } else {
            let nutDrive = UIBarButtonItem(
                image: UIImage(systemName: "externaldrive.badge.icloud"),
                style: .plain,
                target: self,
                action: #selector(moCauHinhDrive)
            )
            let nutDongBo = UIBarButtonItem(
                image: UIImage(systemName: "arrow.triangle.2.circlepath"),
                style: .plain,
                target: self,
                action: #selector(dongBoThuCong)
            )
            navigationItem.leftBarButtonItems = [nutDrive, nutDongBo]
        }

        let nutMenu = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moMenuTuyChonBang)
        )
        let nutThemDong = UIBarButtonItem(
            title: "+Dòng",
            style: .done,
            target: self,
            action: #selector(themDongMoi)
        )
        let nutThemCot = UIBarButtonItem(
            title: "+Cột",
            style: .plain,
            target: self,
            action: #selector(hienHopThoaiThemCot)
        )
        navigationItem.rightBarButtonItems = [nutMenu, nutThemDong, nutThemCot]

        taoGiaoDien()
        napGiaoDien()

        NotificationCenter.default.addObserver(self, selector: #selector(napGiaoDien), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(napGiaoDien), name: .xuongCanCapNhat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(napGiaoDien), name: .duLieuDongBoXong, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        napGiaoDien()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func dongModal() {
        dismiss(animated: true)
    }

    private var bangHienTai: BangXuongCan? {
        let ds = KhoDuLieu.dungChung.danhSachBangXuongCan
        guard !ds.isEmpty else { return nil }
        if chiSoBang >= ds.count { chiSoBang = max(0, ds.count - 1) }
        return ds[chiSoBang]
    }

    private func taoGiaoDien() {
        // Thanh chọn bảng ngang siêu gọn (cao 30pt)
        thanhChonBangCuon.showsHorizontalScrollIndicator = false
        thanhChonBangCuon.translatesAutoresizingMaskIntoConstraints = false

        nganChonBang.axis = .horizontal
        nganChonBang.spacing = 6
        nganChonBang.alignment = .center
        nganChonBang.translatesAutoresizingMaskIntoConstraints = false
        thanhChonBangCuon.addSubview(nganChonBang)

        // Khung bảng cuộn 2 chiều (Ngang + Dọc) đặt sát ngay dưới thanh chọn bảng
        cuonDocBang.alwaysBounceVertical = true
        cuonDocBang.translatesAutoresizingMaskIntoConstraints = false

        cuonNgangBang.showsHorizontalScrollIndicator = true
        cuonNgangBang.alwaysBounceHorizontal = false
        cuonNgangBang.translatesAutoresizingMaskIntoConstraints = false

        nganBangDuLieu.axis = .vertical
        nganBangDuLieu.spacing = 0
        nganBangDuLieu.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(thanhChonBangCuon)
        view.addSubview(cuonDocBang)
        cuonDocBang.addSubview(cuonNgangBang)
        cuonNgangBang.addSubview(nganBangDuLieu)

        NSLayoutConstraint.activate([
            thanhChonBangCuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            thanhChonBangCuon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            thanhChonBangCuon.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            thanhChonBangCuon.heightAnchor.constraint(equalToConstant: 30),

            nganChonBang.topAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.topAnchor),
            nganChonBang.bottomAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.bottomAnchor),
            nganChonBang.leadingAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.leadingAnchor),
            nganChonBang.trailingAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.trailingAnchor),
            nganChonBang.heightAnchor.constraint(equalTo: thanhChonBangCuon.frameLayoutGuide.heightAnchor),

            cuonDocBang.topAnchor.constraint(equalTo: thanhChonBangCuon.bottomAnchor, constant: 4),
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
            nganBangDuLieu.trailingAnchor.constraint(equalTo: cuonNgangBang.contentLayoutGuide.trailingAnchor)
        ])
    }

    @objc private func napGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        nganChonBang.arrangedSubviews.forEach {
            nganChonBang.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let dsBang = KhoDuLieu.dungChung.danhSachBangXuongCan
        for (idx, bang) in dsBang.enumerated() {
            let dangChon = (idx == chiSoBang)
            let nut = UIButton(type: .system)
            nut.setTitle("  \(bang.tenBang)  ", for: .normal)
            nut.titleLabel?.font = .systemFont(ofSize: 12, weight: dangChon ? .bold : .medium)
            nut.titleLabel?.numberOfLines = 1
            nut.setTitleColor(dangChon ? .white : mau.text, for: .normal)
            nut.backgroundColor = dangChon ? mau.xuongCanAccent : mau.iconBg
            nut.layer.cornerRadius = 12
            nut.layer.borderWidth = dangChon ? 0 : 1
            nut.layer.borderColor = mau.border.cgColor
            nut.heightAnchor.constraint(equalToConstant: 24).isActive = true
            nut.addAction(UIAction { [weak self] _ in
                self?.chiSoBang = idx
                self?.napGiaoDien()
            }, for: .touchUpInside)
            nganChonBang.addArrangedSubview(nut)
        }

        let nutThemBangNhanh = UIButton(type: .system)
        nutThemBangNhanh.setTitle(" + Bảng ", for: .normal)
        nutThemBangNhanh.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        nutThemBangNhanh.setTitleColor(mau.primary, for: .normal)
        nutThemBangNhanh.backgroundColor = mau.primary.withAlphaComponent(0.1)
        nutThemBangNhanh.layer.cornerRadius = 12
        nutThemBangNhanh.heightAnchor.constraint(equalToConstant: 24).isActive = true
        nutThemBangNhanh.addTarget(self, action: #selector(hienHopThoaiThemBang), for: .touchUpInside)
        nganChonBang.addArrangedSubview(nutThemBangNhanh)

        nganBangDuLieu.arrangedSubviews.forEach {
            nganBangDuLieu.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let bang = bangHienTai else { return }

        let hangTieuDe = taoHangTieuDeCot(bang: bang)
        nganBangDuLieu.addArrangedSubview(hangTieuDe)

        if bang.dong.isEmpty {
            let oTrong = UILabel()
            oTrong.text = "Chưa có dòng nào. Bấm '+Dòng' ở góc trên phải để thêm."
            oTrong.font = .italicSystemFont(ofSize: 12.5)
            oTrong.textColor = mau.subText
            oTrong.textAlignment = .center
            oTrong.heightAnchor.constraint(equalToConstant: 60).isActive = true
            nganBangDuLieu.addArrangedSubview(oTrong)
        } else {
            for (chiSoDong, dong) in bang.dong.enumerated() {
                let hangDong = taoHangDuLieu(bang: bang, dong: dong, soThuTu: chiSoDong + 1)
                nganBangDuLieu.addArrangedSubview(hangDong)
            }
        }
    }

    // MARK: - Vẽ Lưới Bảng Gọn Gàng

    private func chieuRongCot(_ cot: CotXuongCan) -> CGFloat {
        cot.loai == .anh ? 112 : 128
    }

    private func taoHangTieuDeCot(bang: BangXuongCan) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.backgroundColor = mau.border

        let oSTT = taoKhungO(rong: 30, cao: 34, mauNen: mau.iconBg)
        let lbSTT = UILabel()
        lbSTT.text = "#"
        lbSTT.font = .systemFont(ofSize: 11, weight: .bold)
        lbSTT.textColor = mau.subText
        lbSTT.textAlignment = .center
        ganGiua(lbSTT, vao: oSTT)
        hang.addArrangedSubview(oSTT)

        let cacCot = bang.cot.sorted { $0.thuTu < $1.thuTu }
        for cot in cacCot {
            let khungCot = taoKhungO(rong: chieuRongCot(cot), cao: 34, mauNen: mau.iconBg)
            let nutCot = UIButton(type: .system)
            let kyHieu = cot.loai == .anh ? "📷 " : ""
            nutCot.setTitle(kyHieu + cot.tenCot, for: .normal)
            nutCot.setTitleColor(mau.text, for: .normal)
            nutCot.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .bold)
            nutCot.titleLabel?.numberOfLines = 2
            nutCot.titleLabel?.textAlignment = .center
            nutCot.translatesAutoresizingMaskIntoConstraints = false
            khungCot.addSubview(nutCot)
            NSLayoutConstraint.activate([
                nutCot.topAnchor.constraint(equalTo: khungCot.topAnchor, constant: 1),
                nutCot.bottomAnchor.constraint(equalTo: khungCot.bottomAnchor, constant: -1),
                nutCot.leadingAnchor.constraint(equalTo: khungCot.leadingAnchor, constant: 3),
                nutCot.trailingAnchor.constraint(equalTo: khungCot.trailingAnchor, constant: -3)
            ])
            nutCot.addAction(UIAction { [weak self] _ in
                self?.hienMenuChinhSuaCot(bang: bang, cot: cot)
            }, for: .touchUpInside)
            hang.addArrangedSubview(khungCot)
        }

        let oXoa = taoKhungO(rong: 34, cao: 34, mauNen: mau.iconBg)
        let icXoa = UIImageView(image: UIImage(systemName: "trash"))
        icXoa.tintColor = mau.subText
        icXoa.contentMode = .scaleAspectFit
        icXoa.translatesAutoresizingMaskIntoConstraints = false
        oXoa.addSubview(icXoa)
        NSLayoutConstraint.activate([
            icXoa.centerXAnchor.constraint(equalTo: oXoa.centerXAnchor),
            icXoa.centerYAnchor.constraint(equalTo: oXoa.centerYAnchor),
            icXoa.widthAnchor.constraint(equalToConstant: 13),
            icXoa.heightAnchor.constraint(equalToConstant: 13)
        ])
        hang.addArrangedSubview(oXoa)

        let vienBao = UIView()
        vienBao.backgroundColor = mau.border
        hang.translatesAutoresizingMaskIntoConstraints = false
        vienBao.addSubview(hang)
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: vienBao.topAnchor, constant: 1),
            hang.bottomAnchor.constraint(equalTo: vienBao.bottomAnchor, constant: -1),
            hang.leadingAnchor.constraint(equalTo: vienBao.leadingAnchor, constant: 1),
            hang.trailingAnchor.constraint(equalTo: vienBao.trailingAnchor, constant: -1)
        ])
        return vienBao
    }

    private func taoHangDuLieu(bang: BangXuongCan, dong: DongXuongCan, soThuTu: Int) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let chieuCaoDong: CGFloat = bang.cot.contains(where: { $0.loai == .anh }) ? 84 : 46
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.backgroundColor = mau.border

        let oSTT = taoKhungO(rong: 30, cao: chieuCaoDong, mauNen: mau.card)
        let lbSTT = UILabel()
        lbSTT.text = "\(soThuTu)"
        lbSTT.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        lbSTT.textColor = mau.subText
        lbSTT.textAlignment = .center
        ganGiua(lbSTT, vao: oSTT)
        hang.addArrangedSubview(oSTT)

        let cacCot = bang.cot.sorted { $0.thuTu < $1.thuTu }
        for cot in cacCot {
            let giaTriO = dong.giaTri[cot.id]
            let khungO = taoKhungO(rong: chieuRongCot(cot), cao: chieuCaoDong, mauNen: mau.card)

            if cot.loai == .chu {
                let chuHienTai = giaTriO?.vanBan ?? ""
                let nutChu = UIButton(type: .system)
                nutChu.setTitle(chuHienTai.isEmpty ? "Nhập..." : chuHienTai, for: .normal)
                nutChu.setTitleColor(chuHienTai.isEmpty ? mau.subText.withAlphaComponent(0.5) : mau.text, for: .normal)
                nutChu.titleLabel?.font = chuHienTai.isEmpty ? .italicSystemFont(ofSize: 12) : .systemFont(ofSize: 13, weight: .regular)
                nutChu.titleLabel?.numberOfLines = 3
                nutChu.contentHorizontalAlignment = .left
                nutChu.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
                nutChu.translatesAutoresizingMaskIntoConstraints = false
                khungO.addSubview(nutChu)
                NSLayoutConstraint.activate([
                    nutChu.topAnchor.constraint(equalTo: khungO.topAnchor),
                    nutChu.bottomAnchor.constraint(equalTo: khungO.bottomAnchor),
                    nutChu.leadingAnchor.constraint(equalTo: khungO.leadingAnchor),
                    nutChu.trailingAnchor.constraint(equalTo: khungO.trailingAnchor)
                ])
                nutChu.addAction(UIAction { [weak self] _ in
                    self?.moHopThoaiNhapChu(bang: bang, dong: dong, cot: cot, giaTriCu: chuHienTai)
                }, for: .touchUpInside)
            } else {
                // Ô kiểu Ảnh chụp: hiển thị gọn gàng với chấm icon trạng thái 14x14 ở góc dưới phải
                if let thongTinAnh = giaTriO?.anh {
                    let khungAnh = UIImageView()
                    khungAnh.contentMode = .scaleAspectFill
                    khungAnh.clipsToBounds = true
                    khungAnh.layer.cornerRadius = 5
                    khungAnh.backgroundColor = mau.iconBg
                    khungAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(khungAnh)

                    let dangTai = cacMaAnhDangTaiLenDrive.contains(thongTinAnh.maAnh)
                    let chamTrangThai = UIImageView()
                    chamTrangThai.backgroundColor = UIColor.black.withAlphaComponent(0.55)
                    chamTrangThai.layer.cornerRadius = 8
                    chamTrangThai.clipsToBounds = true
                    chamTrangThai.contentMode = .center
                    let cfgIcon = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
                    if dangTai {
                        chamTrangThai.image = UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: cfgIcon)
                        chamTrangThai.tintColor = .systemCyan
                    } else if thongTinAnh.daTaiLenDrive {
                        chamTrangThai.image = UIImage(systemName: "checkmark.icloud.fill", withConfiguration: cfgIcon)
                        chamTrangThai.tintColor = .systemGreen
                    } else {
                        chamTrangThai.image = UIImage(systemName: "icloud.slash.fill", withConfiguration: cfgIcon)
                        chamTrangThai.tintColor = .systemOrange
                    }
                    chamTrangThai.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(chamTrangThai)

                    let nutChamAnh = UIButton(type: .custom)
                    nutChamAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(nutChamAnh)

                    NSLayoutConstraint.activate([
                        khungAnh.topAnchor.constraint(equalTo: khungO.topAnchor, constant: 4),
                        khungAnh.bottomAnchor.constraint(equalTo: khungO.bottomAnchor, constant: -4),
                        khungAnh.leadingAnchor.constraint(equalTo: khungO.leadingAnchor, constant: 4),
                        khungAnh.trailingAnchor.constraint(equalTo: khungO.trailingAnchor, constant: -4),

                        chamTrangThai.bottomAnchor.constraint(equalTo: khungAnh.bottomAnchor, constant: -3),
                        chamTrangThai.trailingAnchor.constraint(equalTo: khungAnh.trailingAnchor, constant: -3),
                        chamTrangThai.widthAnchor.constraint(equalToConstant: 16),
                        chamTrangThai.heightAnchor.constraint(equalToConstant: 16),

                        nutChamAnh.topAnchor.constraint(equalTo: khungO.topAnchor),
                        nutChamAnh.bottomAnchor.constraint(equalTo: khungO.bottomAnchor),
                        nutChamAnh.leadingAnchor.constraint(equalTo: khungO.leadingAnchor),
                        nutChamAnh.trailingAnchor.constraint(equalTo: khungO.trailingAnchor)
                    ])

                    BoNhoDemAnh.dungChung.taiAnh(thongTin: thongTinAnh) { [weak khungAnh] anh in
                        khungAnh?.image = anh ?? UIImage(systemName: "photo")
                    }

                    nutChamAnh.addAction(UIAction { [weak self] _ in
                        self?.moMenuThaoTacOAnh(bang: bang, dong: dong, cot: cot, thongTinAnh: thongTinAnh)
                    }, for: .touchUpInside)
                } else {
                    let nutChonAnh = UIButton(type: .system)
                    let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                    nutChonAnh.setImage(UIImage(systemName: "camera", withConfiguration: cfg), for: .normal)
                    nutChonAnh.tintColor = mau.primary
                    nutChonAnh.backgroundColor = mau.primary.withAlphaComponent(0.08)
                    nutChonAnh.layer.cornerRadius = 6
                    nutChonAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(nutChonAnh)
                    NSLayoutConstraint.activate([
                        nutChonAnh.topAnchor.constraint(equalTo: khungO.topAnchor, constant: 6),
                        nutChonAnh.bottomAnchor.constraint(equalTo: khungO.bottomAnchor, constant: -6),
                        nutChonAnh.leadingAnchor.constraint(equalTo: khungO.leadingAnchor, constant: 6),
                        nutChonAnh.trailingAnchor.constraint(equalTo: khungO.trailingAnchor, constant: -6)
                    ])
                    nutChonAnh.addAction(UIAction { [weak self] _ in
                        self?.chonNguonAnh(idBang: bang.id, idDong: dong.id, idCot: cot.id)
                    }, for: .touchUpInside)
                }
            }
            hang.addArrangedSubview(khungO)
        }

        let oXoa = taoKhungO(rong: 34, cao: chieuCaoDong, mauNen: mau.card)
        let nutXoa = UIButton(type: .system)
        let cfgTrash = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        nutXoa.setImage(UIImage(systemName: "trash", withConfiguration: cfgTrash), for: .normal)
        nutXoa.tintColor = mau.error.withAlphaComponent(0.8)
        ganGiua(nutXoa, vao: oXoa)
        nutXoa.addAction(UIAction { [weak self] _ in
            self?.xacNhanXoaDong(bang: bang, idDong: dong.id, soThuTu: soThuTu)
        }, for: .touchUpInside)
        hang.addArrangedSubview(oXoa)

        let vienBao = UIView()
        vienBao.backgroundColor = mau.border
        hang.translatesAutoresizingMaskIntoConstraints = false
        vienBao.addSubview(hang)
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: vienBao.topAnchor),
            hang.bottomAnchor.constraint(equalTo: vienBao.bottomAnchor, constant: -1),
            hang.leadingAnchor.constraint(equalTo: vienBao.leadingAnchor, constant: 1),
            hang.trailingAnchor.constraint(equalTo: vienBao.trailingAnchor, constant: -1)
        ])
        return vienBao
    }

    private func taoKhungO(rong: CGFloat, cao: CGFloat, mauNen: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = mauNen
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: rong),
            v.heightAnchor.constraint(equalToConstant: cao)
        ])
        return v
    }

    private func ganGiua(_ con: UIView, vao cha: UIView) {
        con.translatesAutoresizingMaskIntoConstraints = false
        cha.addSubview(con)
        NSLayoutConstraint.activate([
            con.centerXAnchor.constraint(equalTo: cha.centerXAnchor),
            con.centerYAnchor.constraint(equalTo: cha.centerYAnchor)
        ])
    }

    // MARK: - Thao tác Bảng, Cột, Hàng

    @objc private func hienHopThoaiThemBang() {
        let alert = UIAlertController(
            title: "Tạo bảng mới",
            message: "Bảng mới sẽ tự động đồng bộ lên Supabase.",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Tên bảng (VD: Cán Thép Lô B2)"
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Tạo", style: .default) { [weak self] _ in
            guard let self else { return }
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let tenChuan = ten.isEmpty ? "Bảng \(KhoDuLieu.dungChung.danhSachBangXuongCan.count + 1)" : ten

            let c1 = CotXuongCan(tenCot: "Mã lô", loai: .chu, thuTu: 0)
            let c2 = CotXuongCan(tenCot: "Thông số", loai: .chu, thuTu: 1)
            let c3 = CotXuongCan(tenCot: "Ảnh chụp", loai: .anh, thuTu: 2)
            let bangMoi = BangXuongCan(tenBang: tenChuan, moTa: "", cot: [c1, c2, c3], dong: [DongXuongCan()])

            var ds = KhoDuLieu.dungChung.danhSachBangXuongCan
            ds.append(bangMoi)
            self.chiSoBang = ds.count - 1
            KhoDuLieu.dungChung.luuBangXuongCan(ds)
        })
        present(alert, animated: true)
    }

    @objc private func hienHopThoaiThemCot() {
        guard var bang = bangHienTai else { return }
        let alert = UIAlertController(
            title: "Thêm cột mới",
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Tên cột..."
        }
        alert.addAction(UIAlertAction(title: "📝 Cột Chữ", style: .default) { _ in
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cotMoi = CotXuongCan(
                tenCot: ten.isEmpty ? "Cột \(bang.cot.count + 1)" : ten,
                loai: .chu,
                thuTu: bang.cot.count
            )
            bang.cot.append(cotMoi)
            bang.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bang)
        })
        alert.addAction(UIAlertAction(title: "📷 Cột Ảnh", style: .default) { _ in
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cotMoi = CotXuongCan(
                tenCot: ten.isEmpty ? "Ảnh \(bang.cot.count + 1)" : ten,
                loai: .anh,
                thuTu: bang.cot.count
            )
            bang.cot.append(cotMoi)
            bang.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bang)
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func themDongMoi() {
        guard var bang = bangHienTai else { return }
        bang.dong.append(DongXuongCan())
        bang.capNhatLuc = Date()
        KhoDuLieu.dungChung.capNhatMotBangXuongCan(bang)
    }

    private func hienMenuChinhSuaCot(bang: BangXuongCan, cot: CotXuongCan) {
        let sheet = UIAlertController(title: cot.tenCot, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Đổi tên cột", style: .default) { [weak self] _ in
            self?.doiTenCot(bang: bang, cot: cot)
        })
        let loaiKhac: LoaiCotXuongCan = (cot.loai == .chu) ? .anh : .chu
        sheet.addAction(UIAlertAction(title: "Đổi sang \(loaiKhac.tenHienThi)", style: .default) { _ in
            var bangMoi = bang
            if let idx = bangMoi.cot.firstIndex(where: { $0.id == cot.id }) {
                bangMoi.cot[idx].loai = loaiKhac
                bangMoi.capNhatLuc = Date()
                KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
            }
        })
        if bang.cot.count > 1 {
            sheet.addAction(UIAlertAction(title: "Xóa cột", style: .destructive) { _ in
                var bangMoi = bang
                bangMoi.cot.removeAll { $0.id == cot.id }
                bangMoi.capNhatLuc = Date()
                KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func doiTenCot(bang: BangXuongCan, cot: CotXuongCan) {
        let alert = UIAlertController(title: "Đổi tên cột", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = cot.tenCot }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { _ in
            let tenMoi = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !tenMoi.isEmpty else { return }
            var bangMoi = bang
            if let idx = bangMoi.cot.firstIndex(where: { $0.id == cot.id }) {
                bangMoi.cot[idx].tenCot = tenMoi
                bangMoi.capNhatLuc = Date()
                KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
            }
        })
        present(alert, animated: true)
    }

    private func xacNhanXoaDong(bang: BangXuongCan, idDong: String, soThuTu: Int) {
        let alert = UIAlertController(title: "Xóa dòng #\(soThuTu)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Xóa", style: .destructive) { _ in
            var bangMoi = bang
            bangMoi.dong.removeAll { $0.id == idDong }
            bangMoi.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
        })
        present(alert, animated: true)
    }

    @objc private func moMenuTuyChonBang() {
        guard let bang = bangHienTai else { return }
        let sheet = UIAlertController(title: bang.tenBang, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Tạo bảng mới", style: .default) { [weak self] _ in
            self?.hienHopThoaiThemBang()
        })
        sheet.addAction(UIAlertAction(title: "Đổi tên bảng", style: .default) { [weak self] _ in
            self?.doiTenBang(bang)
        })
        sheet.addAction(UIAlertAction(title: "Đồng bộ lên Supabase", style: .default) { [weak self] _ in
            self?.dongBoThuCong()
        })
        sheet.addAction(UIAlertAction(title: "Tải bảng từ Supabase về", style: .default) { [weak self] _ in
            DichVuSupabase.dungChung.taiXuongCanTuSupabase { ok, msg in
                self?.hienThongBao(tieuDe: ok ? "Thành công" : "Thông báo", noiDung: msg)
            }
        })
        sheet.addAction(UIAlertAction(title: "Kết nối Google Drive (OAuth 2.0)", style: .default) { [weak self] _ in
            self?.moCauHinhDrive()
        })
        if KhoDuLieu.dungChung.danhSachBangXuongCan.count > 1 {
            sheet.addAction(UIAlertAction(title: "Xóa bảng '\(bang.tenBang)'", style: .destructive) { [weak self] _ in
                guard let self else { return }
                var ds = KhoDuLieu.dungChung.danhSachBangXuongCan
                ds.removeAll { $0.id == bang.id }
                self.chiSoBang = max(0, self.chiSoBang - 1)
                KhoDuLieu.dungChung.luuBangXuongCan(ds)
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func doiTenBang(_ bang: BangXuongCan) {
        let alert = UIAlertController(title: "Đổi tên bảng", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = bang.tenBang }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { _ in
            let tenMoi = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !tenMoi.isEmpty else { return }
            var bangMoi = bang
            bangMoi.tenBang = tenMoi
            bangMoi.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
        })
        present(alert, animated: true)
    }

    // MARK: - Nhập dữ liệu Ô Chữ (Text)

    private func moHopThoaiNhapChu(bang: BangXuongCan, dong: DongXuongCan, cot: CotXuongCan, giaTriCu: String) {
        let vc = ManHinhNhapVanBanO(tenCot: cot.tenCot, giaTriBanDau: giaTriCu) { vanBanMoi in
            var bangMoi = bang
            guard let iDong = bangMoi.dong.firstIndex(where: { $0.id == dong.id }) else { return }
            var oHienTai = bangMoi.dong[iDong].giaTri[cot.id] ?? GiaTriOXuongCan()
            oHienTai.vanBan = vanBanMoi
            bangMoi.dong[iDong].giaTri[cot.id] = oHienTai
            bangMoi.dong[iDong].capNhatLuc = Date()
            bangMoi.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
        }
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(nav, animated: true)
    }

    // MARK: - Menu Ô Ảnh Gọn Gàng

    private func moMenuThaoTacOAnh(bang: BangXuongCan, dong: DongXuongCan, cot: CotXuongCan, thongTinAnh: ThongTinAnhXuongCan) {
        let trangThai = thongTinAnh.daTaiLenDrive ? "Đã lưu Drive" : "Lưu tại bộ nhớ đệm"
        let sheet = UIAlertController(title: "\(cot.tenCot) (\(trangThai))", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Xem ảnh toàn màn hình", style: .default) { [weak self] _ in
            let xemVC = ManHinhXemAnhToanManHinh(thongTinAnh: thongTinAnh, tieuDe: cot.tenCot)
            let nav = UINavigationController(rootViewController: xemVC)
            nav.modalPresentationStyle = .fullScreen
            self?.present(nav, animated: true)
        })
        if !thongTinAnh.daTaiLenDrive {
            sheet.addAction(UIAlertAction(title: "Tải lên Google Drive", style: .default) { [weak self] _ in
                guard let self,
                      let anhTrongCache = BoNhoDemAnh.dungChung.layAnhTucThi(maAnh: thongTinAnh.maAnh) else { return }
                self.thucHienTaiAnhLenDrive(
                    anh: anhTrongCache,
                    maAnh: thongTinAnh.maAnh,
                    viTri: (bang.id, dong.id, cot.id)
                )
            })
        }
        sheet.addAction(UIAlertAction(title: "Đổi ảnh khác", style: .default) { [weak self] _ in
            self?.chonNguonAnh(idBang: bang.id, idDong: dong.id, idCot: cot.id)
        })
        if let link = thongTinAnh.driveUrl, !link.isEmpty {
            sheet.addAction(UIAlertAction(title: "Copy Link Drive", style: .default) { _ in
                UIPasteboard.general.string = link
            })
        }
        sheet.addAction(UIAlertAction(title: "Xóa ảnh", style: .destructive) { _ in
            var bangMoi = bang
            guard let iDong = bangMoi.dong.firstIndex(where: { $0.id == dong.id }) else { return }
            bangMoi.dong[iDong].giaTri.removeValue(forKey: cot.id)
            bangMoi.dong[iDong].capNhatLuc = Date()
            bangMoi.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
        })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func chonNguonAnh(idBang: String, idDong: String, idCot: String) {
        oAnhDangChon = (idBang, idDong, idCot)
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Chụp ảnh (Camera)", style: .default) { [weak self] _ in
                self?.moTrinhChonAnh(loai: .camera)
            })
        }
        sheet.addAction(UIAlertAction(title: "Chọn từ Thư viện", style: .default) { [weak self] _ in
            self?.moTrinhChonAnh(loai: .photoLibrary)
        })
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func moTrinhChonAnh(loai: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = loai
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let anhGoc = info[.originalImage] as? UIImage,
              let viTri = oAnhDangChon else { return }

        let maAnh = "XC_\(UUID().uuidString)"
        BoNhoDemAnh.dungChung.luuAnh(anhGoc, maAnh: maAnh)

        let thongTinTam = ThongTinAnhXuongCan(
            maAnh: maAnh,
            driveFileId: nil,
            driveUrl: nil,
            capNhatLuc: Date(),
            daTaiLenDrive: false
        )
        capNhatThongTinAnhVaoBang(viTri: viTri, thongTin: thongTinTam)
        thucHienTaiAnhLenDrive(anh: anhGoc, maAnh: maAnh, viTri: viTri)
    }

    private func thucHienTaiAnhLenDrive(
        anh: UIImage,
        maAnh: String,
        viTri: (idBang: String, idDong: String, idCot: String)
    ) {
        let tenTep = "XuongCan_\(Int(Date().timeIntervalSince1970)).jpg"
        cacMaAnhDangTaiLenDrive.insert(maAnh)
        napGiaoDien()

        DichVuGoogleDrive.dungChung.taiAnhLenDrive(anh: anh, tenTep: tenTep) { [weak self] fileId, driveUrl, thongBaoLoi in
            guard let self else { return }
            self.cacMaAnhDangTaiLenDrive.remove(maAnh)

            if let fileId, !fileId.isEmpty {
                BoNhoDemAnh.dungChung.luuAnh(anh, maAnh: fileId)
                let thongTinDaLuuDrive = ThongTinAnhXuongCan(
                    maAnh: maAnh,
                    driveFileId: fileId,
                    driveUrl: driveUrl,
                    capNhatLuc: Date(),
                    daTaiLenDrive: true
                )
                self.capNhatThongTinAnhVaoBang(viTri: viTri, thongTin: thongTinDaLuuDrive)
            } else {
                self.napGiaoDien()
                if let thongBaoLoi {
                    self.hienThongBao(
                        tieuDe: "Chưa tải lên Google Drive",
                        noiDung: thongBaoLoi
                    )
                }
            }
        }
    }

    private func capNhatThongTinAnhVaoBang(viTri: (idBang: String, idDong: String, idCot: String), thongTin: ThongTinAnhXuongCan) {
        var dsBang = KhoDuLieu.dungChung.danhSachBangXuongCan
        guard let iBang = dsBang.firstIndex(where: { $0.id == viTri.idBang }),
              let iDong = dsBang[iBang].dong.firstIndex(where: { $0.id == viTri.idDong }) else { return }
        var o = dsBang[iBang].dong[iDong].giaTri[viTri.idCot] ?? GiaTriOXuongCan()
        o.anh = thongTin
        dsBang[iBang].dong[iDong].giaTri[viTri.idCot] = o
        dsBang[iBang].dong[iDong].capNhatLuc = Date()
        dsBang[iBang].capNhatLuc = Date()
        KhoDuLieu.dungChung.luuBangXuongCan(dsBang, dongBoSupabase: true)
    }

    @objc private func dongBoThuCong() {
        DichVuSupabase.dungChung.dongBoXuongCanTuDong { [weak self] ok, msg in
            self?.hienThongBao(tieuDe: ok ? "Thành công" : "Thông báo", noiDung: msg)
        }
    }

    @objc private func moCauHinhDrive() {
        let vc = ManHinhCauHinhDriveXuongCan()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func hienThongBao(tieuDe: String, noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Màn hình Nhập Văn Bản Cho Ô

final class ManHinhNhapVanBanO: UIViewController {
    private let tenCot: String
    private let giaTriBanDau: String
    private let khiLuu: (String) -> Void
    private let oVanBan = UITextView()

    init(tenCot: String, giaTriBanDau: String, khiLuu: @escaping (String) -> Void) {
        self.tenCot = tenCot
        self.giaTriBanDau = giaTriBanDau
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
        navigationItem.title = tenCot

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Hủy", style: .plain, target: self, action: #selector(huy))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(luu))

        oVanBan.text = giaTriBanDau
        oVanBan.font = .systemFont(ofSize: 16)
        oVanBan.textColor = mau.text
        oVanBan.backgroundColor = mau.iconBg
        oVanBan.layer.cornerRadius = 10
        oVanBan.layer.borderWidth = 1
        oVanBan.layer.borderColor = mau.border.cgColor
        oVanBan.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        oVanBan.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(oVanBan)

        NSLayoutConstraint.activate([
            oVanBan.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            oVanBan.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            oVanBan.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            oVanBan.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        oVanBan.becomeFirstResponder()
    }

    @objc private func huy() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        let chu = oVanBan.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        khiLuu(chu)
        dismiss(animated: true)
    }
}

// MARK: - Màn hình Xem Ảnh Phóng To Toàn Màn Hình

final class ManHinhXemAnhToanManHinh: UIViewController, UIScrollViewDelegate {
    private let thongTinAnh: ThongTinAnhXuongCan
    private let tieuDeAnh: String
    private let cuonZoom = UIScrollView()
    private let khungAnh = UIImageView()

    init(thongTinAnh: ThongTinAnhXuongCan, tieuDe: String) {
        self.thongTinAnh = thongTinAnh
        self.tieuDeAnh = tieuDe
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.title = tieuDeAnh
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .done, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(chiaSeAnh)
        )

        cuonZoom.delegate = self
        cuonZoom.minimumZoomScale = 1.0
        cuonZoom.maximumZoomScale = 5.0
        cuonZoom.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuonZoom)

        khungAnh.contentMode = .scaleAspectFit
        khungAnh.translatesAutoresizingMaskIntoConstraints = false
        cuonZoom.addSubview(khungAnh)

        NSLayoutConstraint.activate([
            cuonZoom.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuonZoom.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuonZoom.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuonZoom.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            khungAnh.widthAnchor.constraint(equalTo: cuonZoom.frameLayoutGuide.widthAnchor),
            khungAnh.heightAnchor.constraint(equalTo: cuonZoom.frameLayoutGuide.heightAnchor),
            khungAnh.centerXAnchor.constraint(equalTo: cuonZoom.contentLayoutGuide.centerXAnchor),
            khungAnh.centerYAnchor.constraint(equalTo: cuonZoom.contentLayoutGuide.centerYAnchor)
        ])

        BoNhoDemAnh.dungChung.taiAnh(thongTin: thongTinAnh) { [weak self] img in
            self?.khungAnh.image = img
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        khungAnh
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func chiaSeAnh() {
        guard let img = khungAnh.image else { return }
        let ac = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        present(ac, animated: true)
    }
}

// MARK: - Màn hình Kết Nối Google Drive Trực Tiếp Qua OAuth 2.0 (Không Dùng Script)

final class ManHinhCauHinhDriveXuongCan: UIViewController {
    private let oClientId = UITextField()
    private let oClientSecret = UITextField()
    private let oRefreshToken = UITextField()
    private let oFolderId = UITextField()
    private let nutTestDrive = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg
        navigationItem.title = "Kết nối Google Drive (OAuth 2.0)"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(luu))

        let cd = KhoDuLieu.dungChung.caiDat
        oClientId.text = cd.driveClientId
        oClientSecret.text = cd.driveClientSecret
        oRefreshToken.text = cd.driveRefreshToken
        oFolderId.text = cd.driveFolderId

        let cuon = UIScrollView()
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        let ngan = UIStackView()
        ngan.axis = .vertical
        ngan.spacing = 12
        ngan.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(ngan)

        var chTest = UIButton.Configuration.filled()
        chTest.title = "🧪 Test thử tải 1 ảnh lên Google Drive"
        chTest.baseBackgroundColor = mau.success
        nutTestDrive.configuration = chTest
        nutTestDrive.addTarget(self, action: #selector(testTaiAnhLenDrive), for: .touchUpInside)

        let hopHuongDan = UILabel()
        hopHuongDan.numberOfLines = 0
        hopHuongDan.font = .systemFont(ofSize: 12.5)
        hopHuongDan.textColor = mau.subText
        hopHuongDan.text = """
        📌 CÁCH LẤY THÔNG TIN OAUTH 2.0 GOOGLE DRIVE (KHÔNG DÙNG SCRIPT):
        1. Vào console.cloud.google.com -> APIs & Services -> Library -> bật "Google Drive API".
        2. Vào Credentials -> Create Credentials -> OAuth client ID (loại Web application), mục Authorized redirect URIs thêm:
           https://developers.google.com/oauthplayground
           Copy Client ID và Client Secret dán vào 2 ô trên.
        3. Mở developers.google.com/oauthplayground -> bấm bánh răng góc phải trên -> tích "Use your own OAuth credentials" và nhập Client ID, Secret.
        4. Cột trái chọn Drive API v3 -> https://www.googleapis.com/auth/drive.file -> bấm Authorize APIs -> bấm Exchange authorization code for tokens -> copy Refresh token (1//04...) dán vào ô thứ 3.
        """

        [
            taoNhomONhap("1. OAuth Client ID:", oClientId, goiY: "...apps.googleusercontent.com"),
            taoNhomONhap("2. OAuth Client Secret:", oClientSecret, goiY: "GOCSPX-..."),
            taoNhomONhap("3. OAuth Refresh Token (hoặc Access Token ya29...):", oRefreshToken, goiY: "1//04..."),
            taoNhomONhap("4. Link hoặc ID Thư mục Google Drive (Tùy chọn):", oFolderId, goiY: "Để trống sẽ lưu vào thư mục gốc Drive"),
            nutTestDrive,
            hopHuongDan
        ].forEach { ngan.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            ngan.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 14),
            ngan.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -24),
            ngan.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 14),
            ngan.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -14)
        ])
    }

    private func taoNhomONhap(_ tieuDe: String, _ tf: UITextField, goiY: String) -> UIStackView {
        let mau = KhoDuLieu.dungChung.mauSac
        let lb = UILabel()
        lb.text = tieuDe
        lb.font = .systemFont(ofSize: 12.5, weight: .semibold)
        lb.textColor = mau.text

        tf.borderStyle = .roundedRect
        tf.backgroundColor = mau.card
        tf.textColor = mau.text
        tf.font = .systemFont(ofSize: 13)
        tf.placeholder = goiY
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing

        let st = UIStackView(arrangedSubviews: [lb, tf])
        st.axis = .vertical
        st.spacing = 4
        return st
    }

    private func luuTamVaoKho() {
        var cd = KhoDuLieu.dungChung.caiDat
        cd.driveClientId = oClientId.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cd.driveClientSecret = oClientSecret.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cd.driveRefreshToken = oRefreshToken.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cd.driveFolderId = DichVuGoogleDrive.chuanHoaFolderId(oFolderId.text ?? "")
        oFolderId.text = cd.driveFolderId
        KhoDuLieu.dungChung.luuCaiDat(cd, thongBao: false)
    }

    @objc private func testTaiAnhLenDrive() {
        view.endEditing(true)
        luuTamVaoKho()

        let boVe = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 260))
        let anhTest = boVe.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 260))
            let chu = "TEST GOOGLE DRIVE API V3\n\(TienIchLich.dinhDangNgayViet.string(from: Date()))" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.white
            ]
            chu.draw(in: CGRect(x: 30, y: 90, width: 340, height: 100), withAttributes: attrs)
        }

        nutTestDrive.isEnabled = false
        DichVuGoogleDrive.dungChung.taiAnhLenDrive(anh: anhTest, tenTep: "Test_XuongCan_Drive.jpg") { [weak self] fileId, driveUrl, loi in
            guard let self else { return }
            self.nutTestDrive.isEnabled = true
            if let fileId, !fileId.isEmpty {
                self.hienThongBao(
                    tieuDe: "✅ Tải lên Google Drive Thành Công!",
                    noiDung: "Ảnh đã lưu vào Google Drive!\n• File ID: \(fileId)\n• Link: \(driveUrl ?? "")"
                )
            } else {
                self.hienThongBao(
                    tieuDe: "❌ Chưa tải lên được Google Drive",
                    noiDung: loi ?? "Lỗi không xác định."
                )
            }
        }
    }

    private func hienThongBao(tieuDe: String, noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        view.endEditing(true)
        luuTamVaoKho()
        dismiss(animated: true)
    }
}
