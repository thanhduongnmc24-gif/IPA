import UIKit
import UserNotifications

@main
final class UyQuyenUngDung: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var cuaSo: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        TienIchLich.xinQuyenThongBao()
        TienIchLich.capNhatTatCaThongBaoLich()
        TienIchLich.capNhatTatCaThongBaoThucDon()
        TienIchLich.capNhatTatCaThongBaoLenhSX()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiUngDungTamDungHoacThoat),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiUngDungTamDungHoacThoat),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        let w = UIWindow(frame: UIScreen.main.bounds)
        let manHinhGoc = ManHinhGocTabBar()
        w.rootViewController = manHinhGoc
        w.overrideUserInterfaceStyle = KhoDuLieu.dungChung.caiDat.giaoDienToi ? .dark : .light
        w.tintColor = KhoDuLieu.dungChung.mauSac.primary
        w.makeKeyAndVisible()
        cuaSo = w

        DichVuSupabase.dungChung.tuDongKhoiPhucGhiChuNeuCan()

        return true
    }

    @objc private func khiUngDungTamDungHoacThoat() {
        KhoDuLieu.dungChung.sapXepTatCaBangXuongCanAZ(dongBoSupabase: false)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
