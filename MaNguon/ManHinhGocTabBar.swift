import UIKit

final class ManHinhGocTabBar: UITabBarController {
    private let huyHieuDongBo = UIView()
    private let bieuTuongDongBo = UIImageView()
    private let nhanDongBo = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        taoHuyHieuDongBo()
        capNhatDanhSachTab()
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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func khiCaiDatThayDoi() {
        capNhatGiaoDien()
        capNhatDanhSachTab()
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

        huyHieuDongBo.backgroundColor = mau.card
        huyHieuDongBo.layer.borderColor = mau.border.cgColor
        nhanDongBo.textColor = mau.text
    }

    private func capNhatDanhSachTab() {
        let tt = KhoDuLieu.dungChung.caiDat.trangThaiTab
        var danhSach: [UIViewController] = []

        // 1. Tab Xưởng Cán đặt ở vị trí ĐẦU TIÊN
        if tt.xuongCan {
            let vc = UINavigationController(rootViewController: ManHinhXuongCan())
            vc.tabBarItem = UITabBarItem(title: "Xưởng Cán", image: UIImage(systemName: "tablecells"), tag: 0)
            danhSach.append(vc)
        }

        // 2. Tab Lịch
        if tt.calendar {
            let vc = UINavigationController(rootViewController: ManHinhLich())
            vc.tabBarItem = UITabBarItem(title: "Lịch", image: UIImage(systemName: "calendar"), tag: 1)
            danhSach.append(vc)
        }

        // 3. Tab Ghi chú
        if tt.notes {
            let vc = UINavigationController(rootViewController: ManHinhGhiChu())
            vc.tabBarItem = UITabBarItem(title: "Ghi chú", image: UIImage(systemName: "doc.text"), tag: 2)
            danhSach.append(vc)
        }

        // 4. Tab Sheets
        if tt.sheets {
            let vc = UINavigationController(rootViewController: ManHinhSheets())
            vc.tabBarItem = UITabBarItem(title: "Sheets", image: UIImage(systemName: "square.grid.2x2"), tag: 3)
            danhSach.append(vc)
        }

        // 5. Tab Media
        if tt.media {
            let vc = UINavigationController(rootViewController: ManHinhMedia())
            vc.tabBarItem = UITabBarItem(title: "Media", image: UIImage(systemName: "sparkles.tv"), tag: 4)
            danhSach.append(vc)
        }

        // 6. Tab Nhắc nhở
        if tt.reminders {
            let vc = UINavigationController(rootViewController: ManHinhNhacNho())
            vc.tabBarItem = UITabBarItem(title: "Nhắc nhở", image: UIImage(systemName: "alarm"), tag: 5)
            danhSach.append(vc)
        }

        // 7. Tab Cài đặt luôn hiển thị ở cuối
        let caiDatVC = UINavigationController(rootViewController: ManHinhCaiDat())
        caiDatVC.tabBarItem = UITabBarItem(title: "Cài đặt", image: UIImage(systemName: "gearshape"), tag: 6)
        danhSach.append(caiDatVC)

        setViewControllers(danhSach, animated: false)
    }

    private func taoHuyHieuDongBo() {
        huyHieuDongBo.layer.cornerRadius = 14
        huyHieuDongBo.layer.borderWidth = 1
        huyHieuDongBo.isHidden = true
        huyHieuDongBo.translatesAutoresizingMaskIntoConstraints = false

        bieuTuongDongBo.contentMode = .scaleAspectFit
        bieuTuongDongBo.translatesAutoresizingMaskIntoConstraints = false

        nhanDongBo.font = .systemFont(ofSize: 11, weight: .semibold)
        nhanDongBo.translatesAutoresizingMaskIntoConstraints = false

        let hang = UIStackView(arrangedSubviews: [bieuTuongDongBo, nhanDongBo])
        hang.axis = .horizontal
        hang.spacing = 5
        hang.alignment = .center
        hang.translatesAutoresizingMaskIntoConstraints = false

        huyHieuDongBo.addSubview(hang)
        view.addSubview(huyHieuDongBo)

        NSLayoutConstraint.activate([
            bieuTuongDongBo.widthAnchor.constraint(equalToConstant: 14),
            bieuTuongDongBo.heightAnchor.constraint(equalToConstant: 14),
            hang.topAnchor.constraint(equalTo: huyHieuDongBo.topAnchor, constant: 5),
            hang.bottomAnchor.constraint(equalTo: huyHieuDongBo.bottomAnchor, constant: -5),
            hang.leadingAnchor.constraint(equalTo: huyHieuDongBo.leadingAnchor, constant: 8),
            hang.trailingAnchor.constraint(equalTo: huyHieuDongBo.trailingAnchor, constant: -8),
            huyHieuDongBo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            huyHieuDongBo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
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
            nhanDongBo.text = "Đang đồng bộ..."
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
            nhanDongBo.text = "Đã đồng bộ"
        case .loi:
            huyHieuDongBo.isHidden = false
            huyHieuDongBo.alpha = 1
            bieuTuongDongBo.image = UIImage(systemName: "exclamationmark.icloud.fill")
            bieuTuongDongBo.tintColor = mau.error
            nhanDongBo.text = "Lưu cục bộ"
        }
    }
}
