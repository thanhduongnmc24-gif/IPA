import UIKit

// MARK: - Ô hiển thị từng mục Tab trong Menu trượt bên trái

private final class OMenuChuyenTab: UITableViewCell {
    static let ma = "OMenuChuyenTab"

    private let thanhChiThiTrai = UIView()
    private let bieuTuong = UIImageView()
    private let nhanTen = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        thanhChiThiTrai.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thanhChiThiTrai)

        bieuTuong.contentMode = .scaleAspectFit
        bieuTuong.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bieuTuong)

        nhanTen.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nhanTen)

        NSLayoutConstraint.activate([
            thanhChiThiTrai.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thanhChiThiTrai.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            thanhChiThiTrai.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            thanhChiThiTrai.widthAnchor.constraint(equalToConstant: 4.5),

            bieuTuong.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            bieuTuong.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            bieuTuong.widthAnchor.constraint(equalToConstant: 22),
            bieuTuong.heightAnchor.constraint(equalToConstant: 22),

            nhanTen.leadingAnchor.constraint(equalTo: bieuTuong.trailingAnchor, constant: 16),
            nhanTen.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nhanTen.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    func cauHinh(loai: LoaiTabUngDung, dangChon: Bool) {
        let laToi = KhoDuLieu.dungChung.caiDat.giaoDienToi
        let mauChinh = laToi
            ? UIColor(red: 0.25, green: 0.62, blue: 0.98, alpha: 1)
            : UIColor(red: 0.11, green: 0.33, blue: 0.85, alpha: 1)
        let mauChuThuong = laToi
            ? UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1)
            : UIColor(red: 0.15, green: 0.20, blue: 0.28, alpha: 1)
        let mauIconThuong = laToi
            ? UIColor(red: 0.64, green: 0.70, blue: 0.78, alpha: 1)
            : UIColor(red: 0.28, green: 0.34, blue: 0.43, alpha: 1)

        bieuTuong.image = UIImage(systemName: loai.bieuTuong) ?? UIImage(systemName: "doc.text")
        nhanTen.text = loai.tieuDeTab

        if dangChon {
            contentView.backgroundColor = laToi
                ? mauChinh.withAlphaComponent(0.18)
                : UIColor(red: 0.93, green: 0.96, blue: 1.00, alpha: 1)
            thanhChiThiTrai.isHidden = false
            thanhChiThiTrai.backgroundColor = mauChinh
            bieuTuong.tintColor = mauChinh
            nhanTen.textColor = mauChinh
            nhanTen.font = .systemFont(ofSize: 16, weight: .bold)
        } else {
            contentView.backgroundColor = .clear
            thanhChiThiTrai.isHidden = true
            bieuTuong.tintColor = mauIconThuong
            nhanTen.textColor = mauChuThuong
            nhanTen.font = .systemFont(ofSize: 16, weight: .semibold)
        }
    }
}

// MARK: - Màn hình gốc quản lý các Tab qua Menu trượt bên trái (Side Drawer)

final class ManHinhGocTabBar: UITabBarController,
                              UITabBarControllerDelegate,
                              UINavigationControllerDelegate,
                              UITableViewDataSource,
                              UITableViewDelegate,
                              UITableViewDragDelegate,
                              UITableViewDropDelegate,
                              UIGestureRecognizerDelegate {
    private let huyHieuDongBo = UIView()
    private let bieuTuongDongBo = UIImageView()
    private let nhanDongBo = UILabel()
    private var boNhoTab: [LoaiTabUngDung: UINavigationController] = [:]

    // Các thành phần của Menu trượt bên trái (Side Drawer)
    private let lopNenMo = UIView()
    private let khungMenuTrai = UIView()
    private let khungDauMenu = UIView()
    private let nhanThuongHieu = UILabel()
    private let nutSapXepMenu = UIButton(type: .system)
    private let vienVangDauMenu = UIView()
    private let bangMenu = UITableView(frame: .zero, style: .plain)

    private let chieuRongMenu: CGFloat = 285
    private var rangBuocTraiMenu: NSLayoutConstraint!
    private var dangMoMenu: Bool = false
    private var danhSachTabHienThi: [LoaiTabUngDung] = []

    private var vuotTuCanhTrai: UIScreenEdgePanGestureRecognizer!
    private var vuotVungTrai: UIPanGestureRecognizer!
    private var vuotDongMenu: UIPanGestureRecognizer!
    private var viTriBatDauKeo: CGFloat = -285

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        // Ẩn hoàn toàn thanh TabBar dưới cùng vì đã chuyển toàn bộ nút chuyển tab vào Menu trái
        tabBar.isHidden = true

        taoHuyHieuDongBo()
        taoGiaoDienMenuTrai()
        caiDatCuChiVuotMenu()
        capNhatDanhSachTab(giuTabCaiDat: false)
        capNhatGiaoDien()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiCaiDatThayDoi),
            name: .caiDatThayDoi,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiTrangThaiDongBoThayDoi(_:)),
            name: .trangThaiDongBoThayDoi,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(luuThuTuTabHienTaiKhiTamDung),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(luuThuTuTabHienTaiKhiTamDung),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Đảm bảo thanh TabBar dưới cùng luôn ẩn và lớp Menu luôn nổi trên cùng
        if !tabBar.isHidden {
            tabBar.isHidden = true
        }
        view.bringSubviewToFront(huyHieuDongBo)
        view.bringSubviewToFront(lopNenMo)
        view.bringSubviewToFront(khungMenuTrai)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func khiCaiDatThayDoi() {
        let dangOCaiDat = (selectedViewController as? UINavigationController)?.viewControllers.first is ManHinhCaiDat
        capNhatGiaoDien()
        capNhatDanhSachTab(giuTabCaiDat: dangOCaiDat)
    }

    private func capNhatGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.window?.overrideUserInterfaceStyle = KhoDuLieu.dungChung.caiDat.giaoDienToi ? .dark : .light
        view.window?.tintColor = mau.primary

        huyHieuDongBo.backgroundColor = mau.card
        huyHieuDongBo.layer.borderColor = mau.border.cgColor
        nhanDongBo.textColor = mau.text

        khungMenuTrai.backgroundColor = mau.card
        bangMenu.backgroundColor = mau.card
        bangMenu.reloadData()
    }

    // MARK: - Khởi tạo giao diện Menu trượt bên trái (giống mẫu DUONGNT)

    private func taoGiaoDienMenuTrai() {
        lopNenMo.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lopNenMo.alpha = 0
        lopNenMo.isHidden = true
        lopNenMo.translatesAutoresizingMaskIntoConstraints = false
        let chamNen = UITapGestureRecognizer(target: self, action: #selector(dongMenuTrai))
        lopNenMo.addGestureRecognizer(chamNen)
        view.addSubview(lopNenMo)

        khungMenuTrai.backgroundColor = .white
        khungMenuTrai.layer.shadowColor = UIColor.black.cgColor
        khungMenuTrai.layer.shadowOpacity = 0.22
        khungMenuTrai.layer.shadowRadius = 10
        khungMenuTrai.layer.shadowOffset = CGSize(width: 3, height: 0)
        khungMenuTrai.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(khungMenuTrai)

        // Phần Header màu xanh dương đậm có dòng chữ DUONGNT và viền vàng phía dưới
        khungDauMenu.backgroundColor = UIColor(red: 0.11, green: 0.33, blue: 0.85, alpha: 1)
        khungDauMenu.translatesAutoresizingMaskIntoConstraints = false
        khungMenuTrai.addSubview(khungDauMenu)

        nhanThuongHieu.text = "DUONGNT"
        nhanThuongHieu.font = .systemFont(ofSize: 21, weight: .bold)
        nhanThuongHieu.textColor = .white
        nhanThuongHieu.translatesAutoresizingMaskIntoConstraints = false
        khungDauMenu.addSubview(nhanThuongHieu)

        nutSapXepMenu.setTitle("⇅ Sắp xếp", for: .normal)
        nutSapXepMenu.setTitleColor(.white, for: .normal)
        nutSapXepMenu.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nutSapXepMenu.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        nutSapXepMenu.layer.cornerRadius = 7
        nutSapXepMenu.contentEdgeInsets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        nutSapXepMenu.translatesAutoresizingMaskIntoConstraints = false
        nutSapXepMenu.addTarget(self, action: #selector(batTatSapXepTrongMenu), for: .touchUpInside)
        khungDauMenu.addSubview(nutSapXepMenu)

        vienVangDauMenu.backgroundColor = UIColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1)
        vienVangDauMenu.translatesAutoresizingMaskIntoConstraints = false
        khungMenuTrai.addSubview(vienVangDauMenu)

        bangMenu.dataSource = self
        bangMenu.delegate = self
        bangMenu.dragDelegate = self
        bangMenu.dropDelegate = self
        bangMenu.dragInteractionEnabled = true
        bangMenu.register(OMenuChuyenTab.self, forCellReuseIdentifier: OMenuChuyenTab.ma)
        bangMenu.separatorStyle = .none
        bangMenu.rowHeight = 52
        bangMenu.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 24, right: 0)
        bangMenu.showsVerticalScrollIndicator = false
        bangMenu.translatesAutoresizingMaskIntoConstraints = false
        khungMenuTrai.addSubview(bangMenu)

        rangBuocTraiMenu = khungMenuTrai.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -chieuRongMenu - 15)

        NSLayoutConstraint.activate([
            lopNenMo.topAnchor.constraint(equalTo: view.topAnchor),
            lopNenMo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lopNenMo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lopNenMo.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            rangBuocTraiMenu,
            khungMenuTrai.topAnchor.constraint(equalTo: view.topAnchor),
            khungMenuTrai.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            khungMenuTrai.widthAnchor.constraint(equalToConstant: chieuRongMenu),

            khungDauMenu.topAnchor.constraint(equalTo: khungMenuTrai.topAnchor),
            khungDauMenu.leadingAnchor.constraint(equalTo: khungMenuTrai.leadingAnchor),
            khungDauMenu.trailingAnchor.constraint(equalTo: khungMenuTrai.trailingAnchor),
            khungDauMenu.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),

            nhanThuongHieu.leadingAnchor.constraint(equalTo: khungDauMenu.leadingAnchor, constant: 22),
            nhanThuongHieu.bottomAnchor.constraint(equalTo: khungDauMenu.bottomAnchor, constant: -16),

            nutSapXepMenu.trailingAnchor.constraint(equalTo: khungDauMenu.trailingAnchor, constant: -14),
            nutSapXepMenu.centerYAnchor.constraint(equalTo: nhanThuongHieu.centerYAnchor),

            vienVangDauMenu.topAnchor.constraint(equalTo: khungDauMenu.bottomAnchor),
            vienVangDauMenu.leadingAnchor.constraint(equalTo: khungMenuTrai.leadingAnchor),
            vienVangDauMenu.trailingAnchor.constraint(equalTo: khungMenuTrai.trailingAnchor),
            vienVangDauMenu.heightAnchor.constraint(equalToConstant: 3),

            bangMenu.topAnchor.constraint(equalTo: vienVangDauMenu.bottomAnchor),
            bangMenu.leadingAnchor.constraint(equalTo: khungMenuTrai.leadingAnchor),
            bangMenu.trailingAnchor.constraint(equalTo: khungMenuTrai.trailingAnchor),
            bangMenu.bottomAnchor.constraint(equalTo: khungMenuTrai.bottomAnchor)
        ])
    }

    // MARK: - Cử chỉ vuốt từ cạnh trái để mở Menu & vuốt sang trái để đóng Menu

    private func caiDatCuChiVuotMenu() {
        vuotTuCanhTrai = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(xuLyVuotMoMenu(_:)))
        vuotTuCanhTrai.edges = .left
        vuotTuCanhTrai.delegate = self
        view.addGestureRecognizer(vuotTuCanhTrai)

        vuotVungTrai = UIPanGestureRecognizer(target: self, action: #selector(xuLyVuotMoMenu(_:)))
        vuotVungTrai.delegate = self
        view.addGestureRecognizer(vuotVungTrai)

        vuotDongMenu = UIPanGestureRecognizer(target: self, action: #selector(xuLyVuotDongMenu(_:)))
        vuotDongMenu.delegate = self
        lopNenMo.addGestureRecognizer(vuotDongMenu)

        let vuotTrenKhungMenu = UIPanGestureRecognizer(target: self, action: #selector(xuLyVuotDongMenu(_:)))
        vuotTrenKhungMenu.delegate = self
        khungMenuTrai.addGestureRecognizer(vuotTrenKhungMenu)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === vuotTuCanhTrai {
            return !dangMoMenu
        }
        if gestureRecognizer === vuotVungTrai, let pan = gestureRecognizer as? UIPanGestureRecognizer {
            guard !dangMoMenu else { return false }
            // Không mở menu nếu đang đẩy sâu trong NavigationStack (để giữ cử chỉ back mặc định)
            if let nav = selectedViewController as? UINavigationController, nav.viewControllers.count > 1 {
                return false
            }
            let viTri = pan.location(in: view)
            let vanToc = pan.velocity(in: view)
            return viTri.x <= 36 && vanToc.x > 0 && abs(vanToc.x) > abs(vanToc.y) * 1.2
        }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer,
           (gestureRecognizer === vuotDongMenu || gestureRecognizer.view === khungMenuTrai) {
            guard dangMoMenu && !bangMenu.isEditing else { return false }
            let vanToc = pan.velocity(in: view)
            return vanToc.x < 0 && abs(vanToc.x) > abs(vanToc.y)
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer === vuotTuCanhTrai || gestureRecognizer === vuotVungTrai {
            return true
        }
        return false
    }

    @objc private func xuLyVuotMoMenu(_ pan: UIPanGestureRecognizer) {
        let dichChuyen = pan.translation(in: view).x
        let vanToc = pan.velocity(in: view).x

        switch pan.state {
        case .began:
            view.endEditing(true)
            lopNenMo.isHidden = false
            viTriBatDauKeo = -chieuRongMenu
        case .changed:
            let viTriMoi = min(0, max(-chieuRongMenu, viTriBatDauKeo + dichChuyen))
            rangBuocTraiMenu.constant = viTriMoi
            let tienDo = (viTriMoi + chieuRongMenu) / chieuRongMenu
            lopNenMo.alpha = max(0, min(1, tienDo))
        case .ended, .cancelled:
            let hienTai = rangBuocTraiMenu.constant
            if hienTai > -chieuRongMenu * 0.5 || vanToc > 450 {
                moMenuTrai()
            } else {
                dongMenuTrai()
            }
        default:
            break
        }
    }

    @objc private func xuLyVuotDongMenu(_ pan: UIPanGestureRecognizer) {
        let dichChuyen = pan.translation(in: view).x
        let vanToc = pan.velocity(in: view).x

        switch pan.state {
        case .began:
            viTriBatDauKeo = rangBuocTraiMenu.constant
        case .changed:
            let viTriMoi = min(0, max(-chieuRongMenu, viTriBatDauKeo + dichChuyen))
            rangBuocTraiMenu.constant = viTriMoi
            let tienDo = (viTriMoi + chieuRongMenu) / chieuRongMenu
            lopNenMo.alpha = max(0, min(1, tienDo))
        case .ended, .cancelled:
            let hienTai = rangBuocTraiMenu.constant
            if hienTai < -chieuRongMenu * 0.35 || vanToc < -450 {
                dongMenuTrai()
            } else {
                moMenuTrai()
            }
        default:
            break
        }
    }

    @objc func moMenuTrai() {
        view.endEditing(true)
        dangMoMenu = true
        lopNenMo.isHidden = false
        bangMenu.reloadData()
        view.bringSubviewToFront(lopNenMo)
        view.bringSubviewToFront(khungMenuTrai)

        rangBuocTraiMenu.constant = 0
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            self.lopNenMo.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    @objc func dongMenuTrai() {
        dangMoMenu = false
        if bangMenu.isEditing {
            bangMenu.setEditing(false, animated: true)
            nutSapXepMenu.setTitle("⇅ Sắp xếp", for: .normal)
        }
        rangBuocTraiMenu.constant = -chieuRongMenu - 15
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn]) {
            self.lopNenMo.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            if !self.dangMoMenu {
                self.lopNenMo.isHidden = true
            }
        }
    }

    @objc private func batTatSapXepTrongMenu() {
        let dangSua = !bangMenu.isEditing
        bangMenu.setEditing(dangSua, animated: true)
        nutSapXepMenu.setTitle(dangSua ? "✓ Xong" : "⇅ Sắp xếp", for: .normal)
    }

    // MARK: - Tự động gắn nút Menu (☰) vào góc trái trên cùng của mọi màn hình Tab

    private func ganNutMoMenu(cho vc: UIViewController) {
        let maDinhDanh = "NUT_MO_MENU_TRAI"
        var danhSachTrai = vc.navigationItem.leftBarButtonItems ?? []
        if danhSachTrai.contains(where: { $0.accessibilityIdentifier == maDinhDanh }) {
            return
        }

        let cauHinhIcon = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let nutMenu = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal", withConfiguration: cauHinhIcon),
            style: .plain,
            target: self,
            action: #selector(moMenuTrai)
        )
        nutMenu.accessibilityIdentifier = maDinhDanh
        danhSachTrai.insert(nutMenu, at: 0)
        vc.navigationItem.leftBarButtonItems = danhSachTrai
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        if viewController === navigationController.viewControllers.first {
            if viewController is ManHinhLich {
                navigationController.setNavigationBarHidden(false, animated: false)
                if (viewController.navigationItem.title ?? "").isEmpty {
                    viewController.navigationItem.title = "Lịch Làm Việc"
                }
            }
            ganNutMoMenu(cho: viewController)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        if viewController === navigationController.viewControllers.first {
            if viewController is ManHinhLich && navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: false)
                viewController.navigationItem.title = "Lịch Làm Việc"
            }
            ganNutMoMenu(cho: viewController)
        }
    }

    // MARK: - Quản lý danh sách ViewControllers của các Tab

    private func taoHoacLayNavigationController(cho loai: LoaiTabUngDung) -> UINavigationController {
        if let daCo = boNhoTab[loai] {
            daCo.delegate = self
            daCo.tabBarItem = taoTabBarItem(cho: loai)
            if let root = daCo.viewControllers.first {
                root.hidesBottomBarWhenPushed = true
                ganNutMoMenu(cho: root)
            }
            return daCo
        }

        let rootVC: UIViewController
        switch loai {
        case .xuongCan:
            rootVC = ManHinhXuongCan()
        case .troLyCan:
            rootVC = ManHinhTroLyCan()
        case .lenhSanXuat:
            rootVC = ManHinhLenhSanXuat()
        case .baoCao:
            rootVC = ManHinhBaoCao()
        case .calendar:
            rootVC = ManHinhLich()
        case .thucDon:
            rootVC = ManHinhThucDon()
        case .notes:
            rootVC = ManHinhGhiChu()
        case .sheets:
            rootVC = ManHinhSheets()
        case .media:
            rootVC = ManHinhMedia()
        case .reminders:
            rootVC = ManHinhNhacNho()
        case .caiDat:
            rootVC = ManHinhCaiDat()
        }

        rootVC.hidesBottomBarWhenPushed = true
        ganNutMoMenu(cho: rootVC)

        let nav = UINavigationController(rootViewController: rootVC)
        nav.delegate = self
        nav.tabBarItem = taoTabBarItem(cho: loai)
        boNhoTab[loai] = nav
        return nav
    }

    private func taoTabBarItem(cho loai: LoaiTabUngDung) -> UITabBarItem {
        let img = UIImage(systemName: loai.bieuTuong) ?? UIImage(systemName: "doc.text")
        let item = UITabBarItem(title: loai.tieuDeTab, image: img, tag: loai.tagSo)
        item.accessibilityIdentifier = loai.rawValue
        return item
    }

    private func xacDinhLoaiTab(cua vc: UIViewController) -> LoaiTabUngDung? {
        if let id = vc.tabBarItem.accessibilityIdentifier,
           let loai = LoaiTabUngDung(rawValue: id) {
            return loai
        }
        guard let nav = vc as? UINavigationController,
              let root = nav.viewControllers.first else {
            return LoaiTabUngDung.allCases.first(where: { $0.tagSo == vc.tabBarItem.tag })
        }
        switch root {
        case is ManHinhXuongCan: return .xuongCan
        case is ManHinhTroLyCan: return .troLyCan
        case is ManHinhLenhSanXuat: return .lenhSanXuat
        case is ManHinhBaoCao: return .baoCao
        case is ManHinhLich: return .calendar
        case is ManHinhThucDon: return .thucDon
        case is ManHinhGhiChu: return .notes
        case is ManHinhSheets: return .sheets
        case is ManHinhMedia: return .media
        case is ManHinhNhacNho: return .reminders
        case is ManHinhCaiDat: return .caiDat
        default: return nil
        }
    }

    private func capNhatDanhSachTab(giuTabCaiDat: Bool) {
        let caiDat = KhoDuLieu.dungChung.caiDat
        let tt = caiDat.trangThaiTab
        let thuTu = caiDat.danhSachLoaiTabTheoThuTu

        let loaiDangChon = selectedViewController.flatMap { xacDinhLoaiTab(cua: $0) }

        var danhSach: [UIViewController] = []
        var tabHienThi: [LoaiTabUngDung] = []

        for loai in thuTu {
            if tt.dangBat(loai) {
                let nav = taoHoacLayNavigationController(cho: loai)
                danhSach.append(nav)
                tabHienThi.append(loai)
            }
        }

        danhSachTabHienThi = tabHienThi
        setViewControllers(danhSach, animated: false)
        tabBar.isHidden = true

        if giuTabCaiDat {
            if let idx = danhSach.firstIndex(where: { xacDinhLoaiTab(cua: $0) == .caiDat }) {
                selectedIndex = idx
            }
        } else if let loaiDangChon,
                  let idx = danhSach.firstIndex(where: { xacDinhLoaiTab(cua: $0) == loaiDangChon }) {
            selectedIndex = idx
        }

        bangMenu.reloadData()
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate cho Menu bên trái

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        danhSachTabHienThi.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let o = tableView.dequeueReusableCell(withIdentifier: OMenuChuyenTab.ma, for: indexPath) as! OMenuChuyenTab
        let loai = danhSachTabHienThi[indexPath.row]
        let loaiDangChon = selectedViewController.flatMap { xacDinhLoaiTab(cua: $0) }
        o.cauHinh(loai: loai, dangChon: loai == loaiDangChon)
        return o
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < danhSachTabHienThi.count else { return }
        selectedIndex = indexPath.row
        tableView.reloadData()
        dongMenuTrai()
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.row != destinationIndexPath.row,
              sourceIndexPath.row < danhSachTabHienThi.count,
              destinationIndexPath.row < danhSachTabHienThi.count else { return }

        let loaiDangChon = selectedViewController.flatMap { xacDinhLoaiTab(cua: $0) }
        let phanTu = danhSachTabHienThi.remove(at: sourceIndexPath.row)
        danhSachTabHienThi.insert(phanTu, at: destinationIndexPath.row)

        // Cập nhật thứ tự viewControllers theo danh sách mới và lưu ngay xuống máy
        let vcsMoi = danhSachTabHienThi.map { taoHoacLayNavigationController(cho: $0) }
        setViewControllers(vcsMoi, animated: false)
        tabBar.isHidden = true
        if let loaiDangChon, let idx = danhSachTabHienThi.firstIndex(of: loaiDangChon) {
            selectedIndex = idx
        }
        luuThuTuTabTuDanhSachLoai(danhSachTabHienThi)
        tableView.reloadData()
    }

    // Hỗ trợ nhấn giữ để kéo thả đổi thứ tự các tab trực tiếp trong Menu mà không cần bật chế độ Sửa
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let loai = danhSachTabHienThi[indexPath.row]
        let itemProvider = NSItemProvider(object: loai.rawValue as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = loai
        return [dragItem]
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        // UIKit tự động gọi tableView(_:moveRowAt:to:) khi kéo thả nội bộ
    }

    // MARK: - Lưu thứ tự Tab

    @objc private func luuThuTuTabHienTaiKhiTamDung() {
        guard !danhSachTabHienThi.isEmpty else { return }
        luuThuTuTabTuDanhSachLoai(danhSachTabHienThi)
    }

    private func luuThuTuTabTuDanhSachLoai(_ thuTuHienThi: [LoaiTabUngDung]) {
        guard !thuTuHienThi.isEmpty else { return }
        let thuTuGoc = KhoDuLieu.dungChung.caiDat.danhSachLoaiTabTheoThuTu
        let tapHienThi = Set(thuTuHienThi)

        var ketQua: [LoaiTabUngDung] = []
        var chiSoHienThi = 0

        for loaiGoc in thuTuGoc {
            if tapHienThi.contains(loaiGoc) {
                if chiSoHienThi < thuTuHienThi.count {
                    ketQua.append(thuTuHienThi[chiSoHienThi])
                    chiSoHienThi += 1
                }
            } else {
                ketQua.append(loaiGoc)
            }
        }

        while chiSoHienThi < thuTuHienThi.count {
            let conLai = thuTuHienThi[chiSoHienThi]
            if !ketQua.contains(conLai) {
                ketQua.append(conLai)
            }
            chiSoHienThi += 1
        }

        KhoDuLieu.dungChung.luuThuTuTab(ketQua.map(\.rawValue))
    }

    // MARK: - Huy hiệu trạng thái đồng bộ góc trên bên phải

    private func taoHuyHieuDongBo() {
        huyHieuDongBo.layer.cornerRadius = 12
        huyHieuDongBo.layer.borderWidth = 1
        huyHieuDongBo.isHidden = true
        huyHieuDongBo.translatesAutoresizingMaskIntoConstraints = false

        bieuTuongDongBo.contentMode = .scaleAspectFit
        bieuTuongDongBo.translatesAutoresizingMaskIntoConstraints = false

        nhanDongBo.font = .systemFont(ofSize: 10, weight: .semibold)
        nhanDongBo.translatesAutoresizingMaskIntoConstraints = false

        let hang = UIStackView(arrangedSubviews: [bieuTuongDongBo, nhanDongBo])
        hang.axis = .horizontal
        hang.spacing = 4
        hang.alignment = .center
        hang.translatesAutoresizingMaskIntoConstraints = false

        huyHieuDongBo.addSubview(hang)
        view.addSubview(huyHieuDongBo)

        NSLayoutConstraint.activate([
            bieuTuongDongBo.widthAnchor.constraint(equalToConstant: 12),
            bieuTuongDongBo.heightAnchor.constraint(equalToConstant: 12),
            hang.topAnchor.constraint(equalTo: huyHieuDongBo.topAnchor, constant: 4),
            hang.bottomAnchor.constraint(equalTo: huyHieuDongBo.bottomAnchor, constant: -4),
            hang.leadingAnchor.constraint(equalTo: huyHieuDongBo.leadingAnchor, constant: 8),
            hang.trailingAnchor.constraint(equalTo: huyHieuDongBo.trailingAnchor, constant: -8),
            huyHieuDongBo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            huyHieuDongBo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    @objc private func khiTrangThaiDongBoThayDoi(_ note: Notification) {
        guard let tt = note.object as? TrangThaiDongBo else { return }
        let mau = KhoDuLieu.dungChung.mauSac
        switch tt {
        case .ranh:
            UIView.animate(withDuration: 0.25) { self.huyHieuDongBo.alpha = 0 } completion: { _ in
                self.huyHieuDongBo.isHidden = true
            }
        case .dangDongBo:
            huyHieuDongBo.isHidden = false
            huyHieuDongBo.alpha = 1
            bieuTuongDongBo.image = UIImage(systemName: "arrow.triangle.2.circlepath.icloud.fill")
            bieuTuongDongBo.tintColor = mau.primary
            nhanDongBo.text = "Đồng bộ..."
        case .dangTaiVe:
            huyHieuDongBo.isHidden = false
            huyHieuDongBo.alpha = 1
            bieuTuongDongBo.image = UIImage(systemName: "icloud.and.arrow.down.fill")
            bieuTuongDongBo.tintColor = mau.primary
            nhanDongBo.text = "Đang tải..."
        case .thanhCong:
            huyHieuDongBo.isHidden = false
            huyHieuDongBo.alpha = 1
            bieuTuongDongBo.image = UIImage(systemName: "checkmark.icloud.fill")
            bieuTuongDongBo.tintColor = mau.success
            nhanDongBo.text = "Đã lưu mây"
        case .loi:
            huyHieuDongBo.isHidden = false
            huyHieuDongBo.alpha = 1
            bieuTuongDongBo.image = UIImage(systemName: "exclamationmark.icloud.fill")
            bieuTuongDongBo.tintColor = mau.error
            nhanDongBo.text = "Lưu máy"
        }
    }
}
