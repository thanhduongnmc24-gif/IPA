import UIKit

final class ManHinhXuongCan: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let hienNutDongModal: Bool
    private var chiSoBang: Int = 0
    private var cacMaAnhDangTaiLenDrive: Set<String> = []

    // Lưu vị trí ô ảnh đang chọn để nhận kết quả từ Camera / Thư viện ảnh
    private var oAnhDangChon: (idBang: String, idDong: String, idCot: String)?

    // Giao diện
    private let thanhChonBangCuon = UIScrollView()
    private let nganChonBang = UIStackView()
    private let nhanThongTinBang = UILabel()
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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "+ Bảng",
            style: .done,
            target: self,
            action: #selector(hienHopThoaiThemBang)
        )

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
        // 1. Thanh chọn bảng ngang nhỏ gọn (cao 32pt)
        thanhChonBangCuon.showsHorizontalScrollIndicator = false
        thanhChonBangCuon.translatesAutoresizingMaskIntoConstraints = false

        nganChonBang.axis = .horizontal
        nganChonBang.spacing = 6
        nganChonBang.alignment = .center
        nganChonBang.translatesAutoresizingMaskIntoConstraints = false
        thanhChonBangCuon.addSubview(nganChonBang)

        // 2. Thanh nút chức năng nhỏ gọn trên 1 hàng (cao 30pt, chữ 1 dòng không bao giờ bị rớt dòng)
        let nutThemCot = taoNutCongCuGon(tieuDe: "＋ Cột", bieuTuong: "rectangle.badge.plus", mauChu: .systemBlue)
        nutThemCot.addTarget(self, action: #selector(hienHopThoaiThemCot), for: .touchUpInside)

        let nutThemHang = taoNutCongCuGon(tieuDe: "＋ Dòng", bieuTuong: "plus.square", mauChu: .systemGreen)
        nutThemHang.addTarget(self, action: #selector(themDongMoi), for: .touchUpInside)

        let nutTuyChonBang = taoNutCongCuGon(tieuDe: "Tùy chọn", bieuTuong: "slider.horizontal.3", mauChu: .systemOrange)
        nutTuyChonBang.addTarget(self, action: #selector(moMenuTuyChonBang), for: .touchUpInside)

        let hangNutChucNang = UIStackView(arrangedSubviews: [nutThemCot, nutThemHang, nutTuyChonBang])
        hangNutChucNang.axis = .horizontal
        hangNutChucNang.distribution = .fillEqually
        hangNutChucNang.spacing = 6
        hangNutChucNang.translatesAutoresizingMaskIntoConstraints = false

        nhanThongTinBang.font = .systemFont(ofSize: 11, weight: .regular)
        nhanThongTinBang.numberOfLines = 1
        nhanThongTinBang.lineBreakMode = .byTruncatingTail
        nhanThongTinBang.translatesAutoresizingMaskIntoConstraints = false

        // 3. Khung bảng cuộn 2 chiều (Ngang + Dọc)
        cuonDocBang.alwaysBounceVertical = true
        cuonDocBang.translatesAutoresizingMaskIntoConstraints = false

        cuonNgangBang.showsHorizontalScrollIndicator = true
        cuonNgangBang.alwaysBounceHorizontal = false
        cuonNgangBang.translatesAutoresizingMaskIntoConstraints = false

        nganBangDuLieu.axis = .vertical
        nganBangDuLieu.spacing = 0
        nganBangDuLieu.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(thanhChonBangCuon)
        view.addSubview(hangNutChucNang)
        view.addSubview(nhanThongTinBang)
        view.addSubview(cuonDocBang)
        cuonDocBang.addSubview(cuonNgangBang)
        cuonNgangBang.addSubview(nganBangDuLieu)

        NSLayoutConstraint.activate([
            thanhChonBangCuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            thanhChonBangCuon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            thanhChonBangCuon.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            thanhChonBangCuon.heightAnchor.constraint(equalToConstant: 32),

            nganChonBang.topAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.topAnchor),
            nganChonBang.bottomAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.bottomAnchor),
            nganChonBang.leadingAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.leadingAnchor),
            nganChonBang.trailingAnchor.constraint(equalTo: thanhChonBangCuon.contentLayoutGuide.trailingAnchor),
            nganChonBang.heightAnchor.constraint(equalTo: thanhChonBangCuon.frameLayoutGuide.heightAnchor),

            hangNutChucNang.topAnchor.constraint(equalTo: thanhChonBangCuon.bottomAnchor, constant: 5),
            hangNutChucNang.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            hangNutChucNang.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            hangNutChucNang.heightAnchor.constraint(equalToConstant: 30),

            nhanThongTinBang.topAnchor.constraint(equalTo: hangNutChucNang.bottomAnchor, constant: 4),
            nhanThongTinBang.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nhanThongTinBang.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            cuonDocBang.topAnchor.constraint(equalTo: nhanThongTinBang.bottomAnchor, constant: 4),
            cuonDocBang.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            cuonDocBang.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            cuonDocBang.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),

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

    private func taoNutCongCuGon(tieuDe: String, bieuTuong: String, mauChu: UIColor) -> UIButton {
        let nut = UIButton(type: .system)
        let cauHinhIcon = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        nut.setImage(UIImage(systemName: bieuTuong, withConfiguration: cauHinhIcon), for: .normal)
        nut.setTitle(" " + tieuDe, for: .normal)
        nut.tintColor = mauChu
        nut.setTitleColor(mauChu, for: .normal)
        nut.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nut.titleLabel?.numberOfLines = 1
        nut.titleLabel?.lineBreakMode = .byTruncatingTail
        nut.backgroundColor = mauChu.withAlphaComponent(0.12)
        nut.layer.cornerRadius = 8
        nut.layer.borderWidth = 1
        nut.layer.borderColor = mauChu.withAlphaComponent(0.3).cgColor
        return nut
    }

    @objc private func napGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg
        nhanThongTinBang.textColor = mau.subText

        nganChonBang.arrangedSubviews.forEach {
            nganChonBang.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let dsBang = KhoDuLieu.dungChung.danhSachBangXuongCan
        for (idx, bang) in dsBang.enumerated() {
            let dangChon = (idx == chiSoBang)
            let nut = UIButton(type: .system)
            nut.setTitle("  \(bang.tenBang)  ", for: .normal)
            nut.titleLabel?.font = .systemFont(ofSize: 12.5, weight: dangChon ? .bold : .medium)
            nut.titleLabel?.numberOfLines = 1
            nut.setTitleColor(dangChon ? .white : mau.text, for: .normal)
            nut.backgroundColor = dangChon ? mau.xuongCanAccent : mau.iconBg
            nut.layer.cornerRadius = 14
            nut.layer.borderWidth = dangChon ? 0 : 1
            nut.layer.borderColor = mau.border.cgColor
            nut.heightAnchor.constraint(equalToConstant: 28).isActive = true
            nut.addAction(UIAction { [weak self] _ in
                self?.chiSoBang = idx
                self?.napGiaoDien()
            }, for: .touchUpInside)
            nganChonBang.addArrangedSubview(nut)
        }

        nganBangDuLieu.arrangedSubviews.forEach {
            nganBangDuLieu.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let bang = bangHienTai else {
            nhanThongTinBang.text = "Chưa có bảng nào. Bấm '+ Bảng' ở góc trên phải để tạo."
            return
        }

        let dungLuongCache = BoNhoDemAnh.dungChung.dungLuongBoNhoDemChuoi()
        nhanThongTinBang.text = "\(bang.cot.count) cột • \(bang.dong.count) dòng • Cache: \(dungLuongCache) (Chạm tiêu đề cột để sửa/xóa)"

        let hangTieuDe = taoHangTieuDeCot(bang: bang)
        nganBangDuLieu.addArrangedSubview(hangTieuDe)

        if bang.dong.isEmpty {
            let oTrong = UILabel()
            oTrong.text = "Chưa có dữ liệu. Bấm '＋ Dòng' để thêm hàng mới."
            oTrong.font = .italicSystemFont(ofSize: 13)
            oTrong.textColor = mau.subText
            oTrong.textAlignment = .center
            oTrong.heightAnchor.constraint(equalToConstant: 70).isActive = true
            nganBangDuLieu.addArrangedSubview(oTrong)
        } else {
            for (chiSoDong, dong) in bang.dong.enumerated() {
                let hangDong = taoHangDuLieu(bang: bang, dong: dong, soThuTu: chiSoDong + 1)
                nganBangDuLieu.addArrangedSubview(hangDong)
            }
        }
    }

    // MARK: - Vẽ Lưới Bảng (Header + Rows)

    private func chieuRongCot(_ cot: CotXuongCan) -> CGFloat {
        cot.loai == .anh ? 135 : 150
    }

    private func taoHangTieuDeCot(bang: BangXuongCan) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.backgroundColor = mau.border

        let oSTT = taoKhungO(rong: 38, cao: 40, mauNen: mau.iconBg)
        let lbSTT = UILabel()
        lbSTT.text = "#"
        lbSTT.font = .systemFont(ofSize: 12, weight: .bold)
        lbSTT.textColor = mau.subText
        lbSTT.textAlignment = .center
        ganGiua(lbSTT, vao: oSTT)
        hang.addArrangedSubview(oSTT)

        let cacCot = bang.cot.sorted { $0.thuTu < $1.thuTu }
        for cot in cacCot {
            let khungCot = taoKhungO(rong: chieuRongCot(cot), cao: 40, mauNen: mau.iconBg)
            let nutCot = UIButton(type: .system)
            let kyHieu = cot.loai == .anh ? "📸 " : "📝 "
            nutCot.setTitle(kyHieu + cot.tenCot, for: .normal)
            nutCot.setTitleColor(mau.text, for: .normal)
            nutCot.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
            nutCot.titleLabel?.numberOfLines = 2
            nutCot.titleLabel?.textAlignment = .center
            nutCot.translatesAutoresizingMaskIntoConstraints = false
            khungCot.addSubview(nutCot)
            NSLayoutConstraint.activate([
                nutCot.topAnchor.constraint(equalTo: khungCot.topAnchor, constant: 2),
                nutCot.bottomAnchor.constraint(equalTo: khungCot.bottomAnchor, constant: -2),
                nutCot.leadingAnchor.constraint(equalTo: khungCot.leadingAnchor, constant: 4),
                nutCot.trailingAnchor.constraint(equalTo: khungCot.trailingAnchor, constant: -4)
            ])
            nutCot.addAction(UIAction { [weak self] _ in
                self?.hienMenuChinhSuaCot(bang: bang, cot: cot)
            }, for: .touchUpInside)
            hang.addArrangedSubview(khungCot)
        }

        let oXoa = taoKhungO(rong: 42, cao: 40, mauNen: mau.iconBg)
        let lbXoa = UILabel()
        lbXoa.text = "Xóa"
        lbXoa.font = .systemFont(ofSize: 11, weight: .bold)
        lbXoa.textColor = mau.error
        lbXoa.textAlignment = .center
        ganGiua(lbXoa, vao: oXoa)
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
        let chieuCaoDong: CGFloat = bang.cot.contains(where: { $0.loai == .anh }) ? 104 : 56
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 1
        hang.backgroundColor = mau.border

        let oSTT = taoKhungO(rong: 38, cao: chieuCaoDong, mauNen: mau.card)
        let lbSTT = UILabel()
        lbSTT.text = "\(soThuTu)"
        lbSTT.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
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
                nutChu.setTitle(chuHienTai.isEmpty ? "Chạm để nhập..." : chuHienTai, for: .normal)
                nutChu.setTitleColor(chuHienTai.isEmpty ? mau.subText.withAlphaComponent(0.6) : mau.text, for: .normal)
                nutChu.titleLabel?.font = chuHienTai.isEmpty ? .italicSystemFont(ofSize: 12.5) : .systemFont(ofSize: 13.5, weight: .regular)
                nutChu.titleLabel?.numberOfLines = 4
                nutChu.contentHorizontalAlignment = .left
                nutChu.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
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
                // Ô kiểu Ảnh chụp
                if let thongTinAnh = giaTriO?.anh {
                    let khungAnh = UIImageView()
                    khungAnh.contentMode = .scaleAspectFill
                    khungAnh.clipsToBounds = true
                    khungAnh.layer.cornerRadius = 6
                    khungAnh.backgroundColor = mau.iconBg
                    khungAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(khungAnh)

                    let dangTai = cacMaAnhDangTaiLenDrive.contains(thongTinAnh.maAnh)
                    let nhanTrangThai = UILabel()
                    nhanTrangThai.font = .systemFont(ofSize: 8.5, weight: .bold)
                    nhanTrangThai.textColor = .white
                    if dangTai {
                        nhanTrangThai.backgroundColor = mau.primary.withAlphaComponent(0.9)
                        nhanTrangThai.text = " ⏳ Đang tải Drive... "
                    } else if thongTinAnh.daTaiLenDrive {
                        nhanTrangThai.backgroundColor = mau.success.withAlphaComponent(0.9)
                        nhanTrangThai.text = " ☁️ Đã lưu Drive "
                    } else {
                        nhanTrangThai.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
                        nhanTrangThai.text = " ⚠️ Chỉ ở Cache "
                    }
                    nhanTrangThai.layer.cornerRadius = 4
                    nhanTrangThai.clipsToBounds = true
                    nhanTrangThai.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(nhanTrangThai)

                    let nutChamAnh = UIButton(type: .custom)
                    nutChamAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(nutChamAnh)

                    NSLayoutConstraint.activate([
                        khungAnh.topAnchor.constraint(equalTo: khungO.topAnchor, constant: 5),
                        khungAnh.bottomAnchor.constraint(equalTo: khungO.bottomAnchor, constant: -5),
                        khungAnh.leadingAnchor.constraint(equalTo: khungO.leadingAnchor, constant: 5),
                        khungAnh.trailingAnchor.constraint(equalTo: khungO.trailingAnchor, constant: -5),

                        nhanTrangThai.bottomAnchor.constraint(equalTo: khungAnh.bottomAnchor, constant: -3),
                        nhanTrangThai.trailingAnchor.constraint(equalTo: khungAnh.trailingAnchor, constant: -3),
                        nhanTrangThai.heightAnchor.constraint(equalToConstant: 14),

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
                    nutChonAnh.setImage(UIImage(systemName: "camera.fill"), for: .normal)
                    nutChonAnh.setTitle(" Chụp/Chọn", for: .normal)
                    nutChonAnh.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
                    nutChonAnh.tintColor = mau.primary
                    nutChonAnh.setTitleColor(mau.primary, for: .normal)
                    nutChonAnh.backgroundColor = mau.primary.withAlphaComponent(0.1)
                    nutChonAnh.layer.cornerRadius = 6
                    nutChonAnh.translatesAutoresizingMaskIntoConstraints = false
                    khungO.addSubview(nutChonAnh)
                    NSLayoutConstraint.activate([
                        nutChonAnh.topAnchor.constraint(equalTo: khungO.topAnchor, constant: 8),
                        nutChonAnh.bottomAnchor.constraint(equalTo: khungO.bottomAnchor, constant: -8),
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

        let oXoa = taoKhungO(rong: 42, cao: chieuCaoDong, mauNen: mau.card)
        let nutXoa = UIButton(type: .system)
        nutXoa.setImage(UIImage(systemName: "trash"), for: .normal)
        nutXoa.tintColor = mau.error
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
            title: "Thêm bảng Xưởng Cán mới",
            message: "Tạo bảng mới với các cột mặc định (có thể thêm/sửa cột tùy ý).",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Tên bảng (VD: Cán Thép Lô B2)"
        }
        alert.addTextField { tf in
            tf.placeholder = "Mô tả ngắn (tùy chọn)"
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Tạo bảng", style: .default) { [weak self] _ in
            guard let self else { return }
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let moTa = alert.textFields?.last?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let tenChuan = ten.isEmpty ? "Bảng Xưởng Cán \(KhoDuLieu.dungChung.danhSachBangXuongCan.count + 1)" : ten

            let c1 = CotXuongCan(tenCot: "Nội dung / Mã", loai: .chu, thuTu: 0)
            let c2 = CotXuongCan(tenCot: "Thông số", loai: .chu, thuTu: 1)
            let c3 = CotXuongCan(tenCot: "Ảnh chụp", loai: .anh, thuTu: 2)
            let bangMoi = BangXuongCan(tenBang: tenChuan, moTa: moTa, cot: [c1, c2, c3], dong: [DongXuongCan()])

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
            title: "Thêm cột mới vào '\(bang.tenBang)'",
            message: "Nhập tên cột và chọn kiểu dữ liệu muốn điền vào cột này:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Tên cột (VD: Nhiệt độ cán, Ảnh bề mặt...)"
        }
        alert.addAction(UIAlertAction(title: "📝 Thêm cột Chữ (Text)", style: .default) { _ in
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cotMoi = CotXuongCan(
                tenCot: ten.isEmpty ? "Cột chữ \(bang.cot.count + 1)" : ten,
                loai: .chu,
                thuTu: bang.cot.count
            )
            bang.cot.append(cotMoi)
            bang.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bang)
        })
        alert.addAction(UIAlertAction(title: "📸 Thêm cột Ảnh chụp (Image)", style: .default) { _ in
            let ten = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cotMoi = CotXuongCan(
                tenCot: ten.isEmpty ? "Cột ảnh \(bang.cot.count + 1)" : ten,
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
        let sheet = UIAlertController(
            title: "Cột: \(cot.tenCot)",
            message: "Kiểu hiện tại: \(cot.loai.tenHienThi)",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "✏️ Đổi tên cột", style: .default) { [weak self] _ in
            self?.doiTenCot(bang: bang, cot: cot)
        })
        let loaiKhac: LoaiCotXuongCan = (cot.loai == .chu) ? .anh : .chu
        sheet.addAction(UIAlertAction(title: "🔄 Chuyển sang kiểu \(loaiKhac.tenHienThi)", style: .default) { _ in
            var bangMoi = bang
            if let idx = bangMoi.cot.firstIndex(where: { $0.id == cot.id }) {
                bangMoi.cot[idx].loai = loaiKhac
                bangMoi.capNhatLuc = Date()
                KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
            }
        })
        if bang.cot.count > 1 {
            sheet.addAction(UIAlertAction(title: "🗑️ Xóa cột này", style: .destructive) { _ in
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
        let alert = UIAlertController(
            title: "Xóa dòng #\(soThuTu)?",
            message: "Dữ liệu của dòng này sẽ bị xóa khỏi bảng.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Xóa dòng", style: .destructive) { _ in
            var bangMoi = bang
            bangMoi.dong.removeAll { $0.id == idDong }
            bangMoi.capNhatLuc = Date()
            KhoDuLieu.dungChung.capNhatMotBangXuongCan(bangMoi)
        })
        present(alert, animated: true)
    }

    @objc private func moMenuTuyChonBang() {
        guard let bang = bangHienTai else { return }
        let sheet = UIAlertController(
            title: bang.tenBang,
            message: "Quản lý bảng, đồng bộ Supabase và cấu hình lưu ảnh Google Drive",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "➕ Tạo bảng mới", style: .default) { [weak self] _ in
            self?.hienHopThoaiThemBang()
        })
        sheet.addAction(UIAlertAction(title: "✏️ Đổi tên bảng hiện tại", style: .default) { [weak self] _ in
            self?.doiTenBang(bang)
        })
        sheet.addAction(UIAlertAction(title: "☁️ Đồng bộ ngay lên Supabase", style: .default) { [weak self] _ in
            self?.dongBoThuCong()
        })
        sheet.addAction(UIAlertAction(title: "📥 Tải dữ liệu Xưởng Cán từ Supabase về", style: .default) { [weak self] _ in
            DichVuSupabase.dungChung.taiXuongCanTuSupabase { ok, msg in
                self?.hienThongBao(tieuDe: ok ? "Thành công" : "Thông báo", noiDung: msg)
            }
        })
        sheet.addAction(UIAlertAction(title: "🔑 Cấu hình Google Apps Script lưu ảnh Drive", style: .default) { [weak self] _ in
            self?.moCauHinhDrive()
        })
        if KhoDuLieu.dungChung.danhSachBangXuongCan.count > 1 {
            sheet.addAction(UIAlertAction(title: "🗑️ Xóa bảng '\(bang.tenBang)'", style: .destructive) { [weak self] _ in
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

    // MARK: - Chụp ảnh / Chọn ảnh, Lưu Bộ nhớ đệm (Cache) + Google Drive (KHÔNG lưu ảnh lên Supabase)

    private func moMenuThaoTacOAnh(bang: BangXuongCan, dong: DongXuongCan, cot: CotXuongCan, thongTinAnh: ThongTinAnhXuongCan) {
        let sheet = UIAlertController(
            title: "Ảnh: \(cot.tenCot)",
            message: thongTinAnh.daTaiLenDrive
                ? "✅ Đã lưu trên Google Drive (ID: \(thongTinAnh.driveFileId ?? "")) & Bộ nhớ đệm ứng dụng."
                : "⚠️ Ảnh hiện đang lưu trong Bộ nhớ đệm của ứng dụng (chưa lên Google Drive).",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "🔍 Xem ảnh phóng to toàn màn hình", style: .default) { [weak self] _ in
            let xemVC = ManHinhXemAnhToanManHinh(thongTinAnh: thongTinAnh, tieuDe: cot.tenCot)
            let nav = UINavigationController(rootViewController: xemVC)
            nav.modalPresentationStyle = .fullScreen
            self?.present(nav, animated: true)
        })
        if !thongTinAnh.daTaiLenDrive {
            sheet.addAction(UIAlertAction(title: "☁️ Thử tải lại ảnh này lên Google Drive", style: .default) { [weak self] _ in
                guard let self,
                      let anhTrongCache = BoNhoDemAnh.dungChung.layAnhTucThi(maAnh: thongTinAnh.maAnh) else { return }
                self.thucHienTaiAnhLenDrive(
                    anh: anhTrongCache,
                    maAnh: thongTinAnh.maAnh,
                    viTri: (bang.id, dong.id, cot.id)
                )
            })
        }
        sheet.addAction(UIAlertAction(title: "📸 Chụp hoặc chọn ảnh khác", style: .default) { [weak self] _ in
            self?.chonNguonAnh(idBang: bang.id, idDong: dong.id, idCot: cot.id)
        })
        if let link = thongTinAnh.driveUrl, !link.isEmpty {
            sheet.addAction(UIAlertAction(title: "📋 Copy Link ảnh Google Drive", style: .default) { [weak self] _ in
                UIPasteboard.general.string = link
                self?.hienThongBao(tieuDe: "Đã Copy", noiDung: "Đã sao chép đường dẫn ảnh trên Google Drive:\n\(link)")
            })
        }
        sheet.addAction(UIAlertAction(title: "🗑️ Xóa ảnh này", style: .destructive) { _ in
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
        let sheet = UIAlertController(
            title: "Điền ảnh vào ô",
            message: "Ảnh sẽ lưu vào Bộ nhớ đệm ứng dụng và tải thẳng lên Google Drive (không lưu ảnh vào Supabase).",
            preferredStyle: .actionSheet
        )
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "📸 Chụp ảnh trực tiếp (Camera)", style: .default) { [weak self] _ in
                self?.moTrinhChonAnh(loai: .camera)
            })
        }
        sheet.addAction(UIAlertAction(title: "🖼️ Chọn từ Thư viện ảnh", style: .default) { [weak self] _ in
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

        // 1. Lưu ngay vào Bộ nhớ đệm 2 tầng (RAM + Disk Cache) để lần sau mở siêu nhanh
        BoNhoDemAnh.dungChung.luuAnh(anhGoc, maAnh: maAnh)

        let thongTinTam = ThongTinAnhXuongCan(
            maAnh: maAnh,
            driveFileId: nil,
            driveUrl: nil,
            capNhatLuc: Date(),
            daTaiLenDrive: false
        )
        capNhatThongTinAnhVaoBang(viTri: viTri, thongTin: thongTinTam)

        // 2. Tải ảnh lên Google Drive và báo rõ nếu có lỗi cấu hình Script
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
                        tieuDe: "Chưa tải được ảnh lên Google Drive",
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
            self?.hienThongBao(tieuDe: ok ? "Đồng bộ thành công" : "Thông báo đồng bộ", noiDung: msg)
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
        oVanBan.layer.cornerRadius = 12
        oVanBan.layer.borderWidth = 1
        oVanBan.layer.borderColor = mau.border.cgColor
        oVanBan.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        oVanBan.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(oVanBan)

        NSLayoutConstraint.activate([
            oVanBan.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            oVanBan.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            oVanBan.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            oVanBan.heightAnchor.constraint(equalToConstant: 200)
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

// MARK: - Màn hình Xem Ảnh Phóng To Toàn Màn Hình (Hỗ trợ Zoom 2 ngón tay)

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

// MARK: - Màn hình Cấu Hình Google Drive & Nút Test Thử Tải Ảnh Lên Drive

final class ManHinhCauHinhDriveXuongCan: UIViewController {
    private let oScriptUrl = UITextField()
    private let oFolderId = UITextField()
    private let nutTestDrive = UIButton(type: .system)

    static let maGoogleAppsScriptMau = """
    // BƯỚC 1: Dán đoạn mã này vào https://script.google.com
    // BƯỚC 2: Trên thanh công cụ phía trên, chọn hàm "capQuyenDrive" rồi bấm nút "Run (Chạy)" để cấp quyền Google Drive!
    // BƯỚC 3: Bấm Deploy -> New deployment -> Web app (Execute as: Me, Who has access: Anyone) -> Copy Web App URL dán vào App.

    function capQuyenDrive() {
      var root = DriveApp.getRootFolder();
      Logger.log("Đã cấp quyền Google Drive thành công! Thư mục gốc: " + root.getName());
    }

    function tachFolderId(input) {
      if (!input) return "";
      var s = input.toString().trim();
      var m = s.match(/\\/folders\\/([a-zA-Z0-9_-]+)/);
      if (m && m[1]) return m[1];
      return s;
    }

    function doGet(e) {
      return ContentService.createTextOutput(JSON.stringify({
        result: "success",
        message: "Cau noi Google Drive Xuong Can dang hoat dong!"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    function doPost(e) {
      try {
        var data = JSON.parse(e.postData.contents);
        if (data.action === "upload_drive") {
          var fid = tachFolderId(data.folderId);
          var folder = fid ? DriveApp.getFolderById(fid) : DriveApp.getRootFolder();
          var bytes = Utilities.base64Decode(data.base64);
          var blob = Utilities.newBlob(bytes, data.mimeType || "image/jpeg", data.filename || "xuong_can.jpg");
          var file = folder.createFile(blob);
          file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
          var fileId = file.getId();
          return ContentService.createTextOutput(JSON.stringify({
            result: "success",
            fileId: fileId,
            url: "https://drive.google.com/uc?export=view&id=" + fileId
          })).setMimeType(ContentService.MimeType.JSON);
        }
        return ContentService.createTextOutput(JSON.stringify({
          result: "error",
          error: "Unknown action"
        })).setMimeType(ContentService.MimeType.JSON);
      } catch (err) {
        return ContentService.createTextOutput(JSON.stringify({
          result: "error",
          error: err.toString()
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg
        navigationItem.title = "Cấu hình Google Drive"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(luu))

        let cd = KhoDuLieu.dungChung.caiDat
        oScriptUrl.text = !cd.driveScriptUrl.isEmpty
            ? cd.driveScriptUrl
            : (cd.driveKey.hasPrefix("https://script.google.com") ? cd.driveKey : "")
        oFolderId.text = cd.driveFolderId

        let cuon = UIScrollView()
        cuon.keyboardDismissMode = .interactive
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        let ngan = UIStackView()
        ngan.axis = .vertical
        ngan.spacing = 14
        ngan.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(ngan)

        let hopLuuY = UILabel()
        hopLuuY.numberOfLines = 0
        hopLuuY.font = .systemFont(ofSize: 13)
        hopLuuY.textColor = mau.text
        hopLuuY.text = """
        📌 VÌ SAO ẢNH CHƯA LÊN GOOGLE DRIVE KHI DÙNG SCRIPT?
        99% trường hợp là do trong Google Apps Script bạn chưa bấm nút "Run (Chạy)" hàm `capQuyenDrive` để cấp quyền ghi vào Google Drive, hoặc bạn dán nguyên đường link thư mục thay vì mã ID.

        Cách làm chuẩn 3 bước:
        1. Bấm nút "Copy mã Google Apps Script" bên dưới và dán đè vào https://script.google.com.
        2. Trên thanh công cụ của trang Script, chọn hàm `capQuyenDrive` rồi bấm nút **Run (Chạy)** -> Bấm **Review permissions** -> Chọn tài khoản Google -> **Advanced** -> **Go to ... (unsafe)** -> **Allow**.
        3. Bấm **Deploy -> New deployment -> Web app** (Execute as: **Me**, Who has access: **Anyone**) -> Copy URL dán vào ô bên dưới rồi bấm nút **Test thử tải ảnh lên Drive**!
        """

        let nutCopyScript = UIButton(type: .system)
        var chScript = UIButton.Configuration.filled()
        chScript.title = "📋 1. Copy mã Google Apps Script chuẩn"
        chScript.baseBackgroundColor = mau.primary
        nutCopyScript.configuration = chScript
        nutCopyScript.addAction(UIAction { [weak self] _ in
            UIPasteboard.general.string = Self.maGoogleAppsScriptMau
            self?.hienThongBao(
                tieuDe: "Đã sao chép mã Script",
                noiDung: "Hãy dán mã này vào script.google.com, nhớ bấm nút 'Run' hàm capQuyenDrive để cấp quyền Google Drive trước khi bấm Deploy -> New deployment!"
            )
        }, for: .touchUpInside)

        var chTest = UIButton.Configuration.filled()
        chTest.title = "🧪 2. Bấm Test thử tải 1 ảnh mẫu lên Google Drive"
        chTest.baseBackgroundColor = mau.success
        nutTestDrive.configuration = chTest
        nutTestDrive.addTarget(self, action: #selector(testTaiAnhLenDrive), for: .touchUpInside)

        let nutCopySQL = UIButton(type: .system)
        var chSQL = UIButton.Configuration.tinted()
        chSQL.title = "📋 Copy mã SQL tạo bảng xuong_can_bang (Supabase)"
        nutCopySQL.configuration = chSQL
        nutCopySQL.addAction(UIAction { [weak self] _ in
            UIPasteboard.general.string = DichVuSupabase.sqlTaoBangXuongCan
            self?.hienThongBao(tieuDe: "Đã sao chép SQL", noiDung: "Hãy mở Supabase -> SQL Editor -> Dán và bấm Run.")
        }, for: .touchUpInside)

        [
            taoNhomONhap("Link Web App Google Apps Script (Bắt buộc để lưu ảnh lên Drive):", oScriptUrl, goiY: "https://script.google.com/macros/s/.../exec"),
            taoNhomONhap("Link hoặc ID Thư mục Google Drive (Để trống sẽ lưu vào thư mục gốc Drive):", oFolderId, goiY: "Dán link thư mục Drive hoặc ID thư mục..."),
            nutTestDrive,
            hopLuuY,
            nutCopyScript,
            nutCopySQL
        ].forEach { ngan.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            ngan.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 16),
            ngan.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -30),
            ngan.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            ngan.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    private func taoNhomONhap(_ tieuDe: String, _ tf: UITextField, goiY: String) -> UIStackView {
        let mau = KhoDuLieu.dungChung.mauSac
        let lb = UILabel()
        lb.text = tieuDe
        lb.font = .systemFont(ofSize: 13, weight: .semibold)
        lb.textColor = mau.subText
        lb.numberOfLines = 0

        tf.borderStyle = .roundedRect
        tf.backgroundColor = mau.card
        tf.textColor = mau.text
        tf.placeholder = goiY
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing

        let st = UIStackView(arrangedSubviews: [lb, tf])
        st.axis = .vertical
        st.spacing = 6
        return st
    }

    private func luuTamVaoKho() {
        var cd = KhoDuLieu.dungChung.caiDat
        cd.driveScriptUrl = oScriptUrl.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cd.driveFolderId = DichVuGoogleDrive.chuanHoaFolderId(oFolderId.text ?? "")
        oFolderId.text = cd.driveFolderId
        KhoDuLieu.dungChung.luuCaiDat(cd)
    }

    @objc private func testTaiAnhLenDrive() {
        view.endEditing(true)
        luuTamVaoKho()

        // Tạo 1 bức ảnh mẫu để test upload
        let boVe = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 260))
        let anhTest = boVe.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 260))
            let chu = "TEST XUONG CAN DRIVE\n\(TienIchLich.dinhDangNgayViet.string(from: Date()))" as NSString
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
                    noiDung: "Ảnh test đã được lưu vào Google Drive của bạn!\n• File ID: \(fileId)\n• Link: \(driveUrl ?? "")"
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
