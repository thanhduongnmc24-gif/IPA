import UIKit

final class ManHinhGocTabBar: UITabBarController, UITabBarControllerDelegate {
    private let huyHieuDongBo = UIView()
    private let bieuTuongDongBo = UIImageView()
    private let nhanDongBo = UILabel()
    private var boNhoTab: [LoaiTabUngDung: UINavigationController] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        taoHuyHieuDongBo()
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

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = mau.card
        appearance.shadowColor = mau.border
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = mau.primary
        tabBar.unselectedItemTintColor = mau.subText

        moreNavigationController.navigationBar.tintColor = mau.primary

        huyHieuDongBo.backgroundColor = mau.card
        huyHieuDongBo.layer.borderColor = mau.border.cgColor
        nhanDongBo.textColor = mau.text
    }

    private func taoHoacLayNavigationController(cho loai: LoaiTabUngDung) -> UINavigationController {
        if let daCo = boNhoTab[loai] {
            daCo.tabBarItem = taoTabBarItem(cho: loai)
            return daCo
        }

        let rootVC: UIViewController
        switch loai {
        case .xuongCan:
            rootVC = ManHinhXuongCan()
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

        let nav = UINavigationController(rootViewController: rootVC)
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
        for loai in thuTu {
            if tt.dangBat(loai) {
                let nav = taoHoacLayNavigationController(cho: loai)
                danhSach.append(nav)
            }
        }

        setViewControllers(danhSach, animated: false)
        customizableViewControllers = danhSach

        if giuTabCaiDat {
            if let idx = danhSach.firstIndex(where: { xacDinhLoaiTab(cua: $0) == .caiDat }) {
                selectedIndex = idx
            }
        } else if let loaiDangChon,
                  let idx = danhSach.firstIndex(where: { xacDinhLoaiTab(cua: $0) == loaiDangChon }) {
            selectedIndex = idx
        }
    }

    // MARK: - Lưu thứ tự Tab khi người dùng sắp xếp trong TabBar (More -> Edit)

    func tabBarController(
        _ tabBarController: UITabBarController,
        willEndCustomizing viewControllers: [UIViewController],
        changed: Bool
    ) {
        luuThuTuTabTuDanhSachVC(viewControllers)
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didEndCustomizing viewControllers: [UIViewController],
        changed: Bool
    ) {
        luuThuTuTabTuDanhSachVC(viewControllers)
    }

    @objc private func luuThuTuTabHienTaiKhiTamDung() {
        guard let vcs = viewControllers, !vcs.isEmpty else { return }
        luuThuTuTabTuDanhSachVC(vcs)
    }

    private func luuThuTuTabTuDanhSachVC(_ vcs: [UIViewController]) {
        let thuTuHienThi = vcs.compactMap { xacDinhLoaiTab(cua: $0) }
        guard !thuTuHienThi.isEmpty else { return }

        let thuTuGoc = KhoDuLieu.dungChung.caiDat.danhSachLoaiTabTheoThuTu
        let tapHienThi = Set(thuTuHienThi)

        // Ghép thứ tự mới của các tab đang hiển thị với vị trí của các tab đang ẩn (nếu có)
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
