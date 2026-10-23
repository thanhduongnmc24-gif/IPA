import UIKit

final class ManHinhCaiDat: UIViewController {
    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cài Đặt ⚙️"
        navigationItem.leftBarButtonItem = taoNutChuyenSangXuongCan()

        cuon.keyboardDismissMode = .interactive
        cuon.alwaysBounceVertical = true
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 14
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 14),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -36),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])

        veGiaoDien()
        NotificationCenter.default.addObserver(self, selector: #selector(veGiaoDien), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(veGiaoDien), name: .duLieuDongBoXong, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        veGiaoDien()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func veGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        let cd = KhoDuLieu.dungChung.caiDat
        view.backgroundColor = mau.bg

        nganChinh.arrangedSubviews.forEach {
            nganChinh.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        // 0. Nút mở nhanh Xưởng Cán
        let nutMoXuongCan = UIButton(type: .system)
        var chXC = UIButton.Configuration.filled()
        chXC.title = "🏭 Mở Xưởng Cán (Quản lý Bảng, Ảnh Drive & Supabase)"
        chXC.baseBackgroundColor = mau.xuongCanAccent
        chXC.cornerStyle = .medium
        nutMoXuongCan.configuration = chXC
        nutMoXuongCan.heightAnchor.constraint(equalToConstant: 44).isActive = true
        nutMoXuongCan.addAction(UIAction { [weak self] _ in
            (self?.tabBarController as? ManHinhGocTabBar)?.chuyenSangXuongCan()
        }, for: .touchUpInside)
        nganChinh.addArrangedSubview(nutMoXuongCan)

        // 1. Tài khoản & Đồng bộ Supabase
        nganChinh.addArrangedSubview(taoTieuDeMuc("☁️ TÀI KHOẢN & ĐỒNG BỘ SUPABASE"))
        let theDongBo = taoThe()
        let nganDongBo = taoNganBenTrong(theDongBo)

        if DichVuSupabase.dungChung.daDangNhap {
            let lbEmail = UILabel()
            lbEmail.text = "● Đang đăng nhập: \(DichVuSupabase.dungChung.emailNguoiDung ?? "")"
            lbEmail.font = .systemFont(ofSize: 14, weight: .bold)
            lbEmail.textColor = mau.success

            let nutSaoLuu = taoNutHanhDong("☁️ Sao lưu ngay (Đẩy toàn bộ & Xưởng Cán lên mây)", mau: mau.primary) { [weak self] in
                DichVuSupabase.dungChung.saoLuuTatCaLenMay { ok, msg in
                    self?.hienThongBao(ok ? "Thành công" : "Lỗi", msg)
                }
            }
            let nutKhoiPhuc = taoNutHanhDong("📥 Khôi phục dữ liệu (Tải từ Supabase về máy)", mau: mau.success) { [weak self] in
                DichVuSupabase.dungChung.khoiPhucTuMay { ok, msg in
                    self?.hienThongBao(ok ? "Thành công" : "Lỗi", msg)
                }
            }
            let nutDangXuat = taoNutHanhDong("Đăng xuất tài khoản", mau: mau.error) { [weak self] in
                DichVuSupabase.dungChung.dangXuat()
                self?.veGiaoDien()
            }
            [lbEmail, nutSaoLuu, nutKhoiPhuc, nutDangXuat].forEach { nganDongBo.addArrangedSubview($0) }
        } else {
            let lbChuaDN = UILabel()
            lbChuaDN.text = "Đăng nhập Supabase để sao lưu Lịch, Ghi chú và Xưởng Cán."
            lbChuaDN.font = .systemFont(ofSize: 13)
            lbChuaDN.textColor = mau.subText
            lbChuaDN.numberOfLines = 0

            let nutDN = taoNutHanhDong("🔑 Đăng nhập / Đăng ký Supabase", mau: mau.primary) { [weak self] in
                self?.hienHopThoaiDangNhap()
            }
            [lbChuaDN, nutDN].forEach { nganDongBo.addArrangedSubview($0) }
        }
        nganChinh.addArrangedSubview(theDongBo)

        // 2. Cấu hình Google Drive & Bộ nhớ đệm ảnh (Xưởng Cán)
        nganChinh.addArrangedSubview(taoTieuDeMuc("🗂️ GOOGLE DRIVE & BỘ NHỚ ĐỆM ẢNH (XƯỞNG CÁN)"))
        let theDrive = taoThe()
        let nganDrive = taoNganBenTrong(theDrive)

        let lbCache = UILabel()
        lbCache.text = "Dung lượng bộ nhớ đệm ảnh hiện tại: \(BoNhoDemAnh.dungChung.dungLuongBoNhoDemChuoi())\nKey Drive hiện tại: \(cd.driveKey.prefix(18))..."
        lbCache.font = .systemFont(ofSize: 13)
        lbCache.textColor = mau.text
        lbCache.numberOfLines = 0

        let nutCauHinhDrive = taoNutHanhDong("⚙️ Cấu hình Key Google Drive & Xem hướng dẫn lấy Key", mau: mau.primary) { [weak self] in
            let vc = ManHinhCauHinhDriveXuongCan()
            self?.present(UINavigationController(rootViewController: vc), animated: true)
        }

        let nutXoaCache = taoNutHanhDong("🧹 Dọn bộ nhớ đệm ảnh (Giữ nguyên ảnh trên Drive)", mau: mau.error) { [weak self] in
            BoNhoDemAnh.dungChung.xoaBoNhoDem()
            self?.veGiaoDien()
            self?.hienThongBao("Đã dọn bộ nhớ đệm", "Bộ nhớ đệm ảnh trên máy đã được làm sạch.")
        }
        [lbCache, nutCauHinhDrive, nutXoaCache].forEach { nganDrive.addArrangedSubview($0) }
        nganChinh.addArrangedSubview(theDrive)

        // 3. Giao diện Sáng / Tối
        nganChinh.addArrangedSubview(taoTieuDeMuc("🎨 GIAO DIỆN"))
        let theGiaoDien = taoThe()
        let nganGD = taoNganBenTrong(theGiaoDien)
        nganGD.addArrangedSubview(taoHangCongTac(ten: cd.giaoDienToi ? "Chế độ Tối 🌙" : "Chế độ Sáng ☀️", dangBat: cd.giaoDienToi) { bat in
            var moi = KhoDuLieu.dungChung.caiDat
            moi.giaoDienToi = bat
            KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganChinh.addArrangedSubview(theGiaoDien)

        // 4. Quản lý Tab
        nganChinh.addArrangedSubview(taoTieuDeMuc("👁️ QUẢN LÝ TAB HIỂN THỊ"))
        let theTab = taoThe()
        let nganTab = taoNganBenTrong(theTab)
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Lịch làm việc", dangBat: cd.trangThaiTab.calendar) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.calendar = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Xưởng Cán 🏭", dangBat: cd.trangThaiTab.xuongCan) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.xuongCan = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Ghi chú", dangBat: cd.trangThaiTab.notes) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.notes = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Trang tính (Sheets)", dangBat: cd.trangThaiTab.sheets) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.sheets = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Media AI", dangBat: cd.trangThaiTab.media) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.media = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Nhắc nhở", dangBat: cd.trangThaiTab.reminders) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.trangThaiTab.reminders = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        nganChinh.addArrangedSubview(theTab)

        // 5. Cấu hình AI Gemini
        nganChinh.addArrangedSubview(taoTieuDeMuc("🤖 CẤU HÌNH AI (GEMINI)"))
        let theGemini = taoThe()
        let nganGemini = taoNganBenTrong(theGemini)
        let oGemini = UITextField()
        oGemini.borderStyle = .roundedRect
        oGemini.placeholder = "AIzaSy..."
        oGemini.text = cd.geminiApiKey
        oGemini.isSecureTextEntry = true
        let nutLuuGemini = taoNutHanhDong("Lưu Key Gemini", mau: mau.primary) { [weak self, weak oGemini] in
            var moi = KhoDuLieu.dungChung.caiDat
            moi.geminiApiKey = oGemini?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            KhoDuLieu.dungChung.luuCaiDat(moi)
            self?.hienThongBao("Đã lưu", "Key Gemini đã được cập nhật!")
        }
        nganGemini.addArrangedSubview(oGemini)
        nganGemini.addArrangedSubview(nutLuuGemini)
        nganChinh.addArrangedSubview(theGemini)

        // 6. Tùy chỉnh chu kỳ & Ngày bắt đầu
        nganChinh.addArrangedSubview(taoTieuDeMuc("⚙️ TÙY CHỈNH CHU KỲ CA LÀM VIỆC"))
        let theChuKy = taoThe()
        let nganChuKy = taoNganBenTrong(theChuKy)

        let chuoiChuKy = cd.chuKyLamViec.enumerated().map { idx, loai -> String in
            switch loai {
            case "ngay": return "\(idx + 1).☀️Ngày"
            case "dem": return "\(idx + 1).🌙Đêm"
            default: return "\(idx + 1).☕Nghỉ"
            }
        }.joined(separator: " → ")

        let lbChuKy = UILabel()
        lbChuKy.text = "Thứ tự hiện tại: \(chuoiChuKy)"
        lbChuKy.font = .systemFont(ofSize: 13, weight: .semibold)
        lbChuKy.textColor = mau.text
        lbChuKy.numberOfLines = 0
        nganChuKy.addArrangedSubview(lbChuKy)

        let hangThemCa = UIStackView(arrangedSubviews: [
            taoNutHanhDong("+ Ngày", mau: .systemOrange) {
                var moi = KhoDuLieu.dungChung.caiDat; moi.chuKyLamViec.append("ngay"); KhoDuLieu.dungChung.luuCaiDat(moi)
            },
            taoNutHanhDong("+ Đêm", mau: .systemIndigo) {
                var moi = KhoDuLieu.dungChung.caiDat; moi.chuKyLamViec.append("dem"); KhoDuLieu.dungChung.luuCaiDat(moi)
            },
            taoNutHanhDong("+ Nghỉ", mau: mau.success) {
                var moi = KhoDuLieu.dungChung.caiDat; moi.chuKyLamViec.append("nghi"); KhoDuLieu.dungChung.luuCaiDat(moi)
            }
        ])
        hangThemCa.distribution = .fillEqually
        hangThemCa.spacing = 6
        nganChuKy.addArrangedSubview(hangThemCa)

        let hangXoaReset = UIStackView(arrangedSubviews: [
            taoNutHanhDong("Xóa bước cuối", mau: mau.error) {
                var moi = KhoDuLieu.dungChung.caiDat
                if moi.chuKyLamViec.count > 1 { moi.chuKyLamViec.removeLast(); KhoDuLieu.dungChung.luuCaiDat(moi) }
            },
            taoNutHanhDong("Về mặc định", mau: mau.primary) {
                var moi = KhoDuLieu.dungChung.caiDat
                moi.chuKyLamViec = ["ngay", "dem", "nghi"]
                KhoDuLieu.dungChung.luuCaiDat(moi)
            }
        ])
        hangXoaReset.distribution = .fillEqually
        hangXoaReset.spacing = 6
        nganChuKy.addArrangedSubview(hangXoaReset)

        // Ngày bắt đầu Bước 1
        let chonNgayBD = UIDatePicker()
        chonNgayBD.datePickerMode = .date
        chonNgayBD.preferredDatePickerStyle = .compact
        chonNgayBD.locale = Locale(identifier: "vi_VN")
        chonNgayBD.date = cd.ngayBatDauChuKy
        chonNgayBD.addAction(UIAction { [weak chonNgayBD] _ in
            guard let d = chonNgayBD?.date else { return }
            var moi = KhoDuLieu.dungChung.caiDat
            moi.ngayBatDauChuKy = d
            moi.daChonNgayBatDau = true
            KhoDuLieu.dungChung.luuCaiDat(moi)
        }, for: .valueChanged)

        let lbBD = UILabel()
        lbBD.text = "Ngày bắt đầu BƯỚC 1:"
        lbBD.font = .systemFont(ofSize: 14, weight: .medium)
        lbBD.textColor = mau.text

        let hangNgayBD = UIStackView(arrangedSubviews: [lbBD, chonNgayBD])
        hangNgayBD.distribution = .equalSpacing
        hangNgayBD.alignment = .center
        nganChuKy.addArrangedSubview(hangNgayBD)
        nganChinh.addArrangedSubview(theChuKy)

        // 7. Cấu hình thông báo
        nganChinh.addArrangedSubview(taoTieuDeMuc("🔔 CẤU HÌNH THÔNG BÁO"))
        let theTB = taoThe()
        let nganTB = taoNganBenTrong(theTB)
        nganTB.addArrangedSubview(taoHangCongTac(ten: "Bật thông báo nhắc nhở ca", dangBat: cd.batThongBao) { bat in
            var moi = KhoDuLieu.dungChung.caiDat; moi.batThongBao = bat; KhoDuLieu.dungChung.luuCaiDat(moi)
        })
        if cd.batThongBao {
            nganTB.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ca Ngày ☀️", gio: cd.gioCaNgay) { d in
                var moi = KhoDuLieu.dungChung.caiDat; moi.gioCaNgay = d; KhoDuLieu.dungChung.luuCaiDat(moi, thongBao: false)
            })
            nganTB.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ca Đêm 🌙", gio: cd.gioCaDem) { d in
                var moi = KhoDuLieu.dungChung.caiDat; moi.gioCaDem = d; KhoDuLieu.dungChung.luuCaiDat(moi, thongBao: false)
            })
            nganTB.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ngày Nghỉ ☕", gio: cd.gioNgayNghi) { d in
                var moi = KhoDuLieu.dungChung.caiDat; moi.gioNgayNghi = d; KhoDuLieu.dungChung.luuCaiDat(moi, thongBao: false)
            })
        }
        nganChinh.addArrangedSubview(theTB)
    }

    private func taoTieuDeMuc(_ chu: String) -> UILabel {
        let lb = UILabel()
        lb.text = chu
        lb.font = .systemFont(ofSize: 12, weight: .bold)
        lb.textColor = KhoDuLieu.dungChung.mauSac.subText
        return lb
    }

    private func taoThe() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let v = UIView()
        v.backgroundColor = mau.card
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = mau.border.cgColor
        return v
    }

    private func taoNganBenTrong(_ the: UIView) -> UIStackView {
        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 10
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

    private func taoNutHanhDong(_ tieuDe: String, mau: UIColor, hanhDong: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var ch = UIButton.Configuration.tinted()
        ch.title = tieuDe
        ch.baseBackgroundColor = mau
        ch.baseForegroundColor = mau
        ch.cornerStyle = .medium
        b.configuration = ch
        b.addAction(UIAction { _ in hanhDong() }, for: .touchUpInside)
        return b
    }

    private func taoHangCongTac(ten: String, dangBat: Bool, khiDoi: @escaping (Bool) -> Void) -> UIStackView {
        let lb = UILabel()
        lb.text = ten
        lb.font = .systemFont(ofSize: 15, weight: .medium)
        lb.textColor = KhoDuLieu.dungChung.mauSac.text

        let sw = UISwitch()
        sw.isOn = dangBat
        sw.onTintColor = KhoDuLieu.dungChung.mauSac.primary
        sw.addAction(UIAction { [weak sw] _ in
            khiDoi(sw?.isOn ?? false)
        }, for: .valueChanged)

        let h = UIStackView(arrangedSubviews: [lb, sw])
        h.distribution = .equalSpacing
        h.alignment = .center
        return h
    }

    private func taoHangGioNhac(_ ten: String, gio: Date, khiDoi: @escaping (Date) -> Void) -> UIStackView {
        let lb = UILabel()
        lb.text = ten
        lb.font = .systemFont(ofSize: 14)
        lb.textColor = KhoDuLieu.dungChung.mauSac.text

        let dp = UIDatePicker()
        dp.datePickerMode = .time
        dp.preferredDatePickerStyle = .compact
        dp.date = gio
        dp.addAction(UIAction { [weak dp] _ in
            if let d = dp?.date { khiDoi(d) }
        }, for: .valueChanged)

        let h = UIStackView(arrangedSubviews: [lb, dp])
        h.distribution = .equalSpacing
        h.alignment = .center
        return h
    }

    private func hienHopThoaiDangNhap() {
        let alert = UIAlertController(title: "Tài khoản Supabase", message: "Nhập Email và Mật khẩu để đăng nhập hoặc đăng ký tài khoản đồng bộ", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "email@example.com"
            tf.keyboardType = .emailAddress
            tf.autocapitalizationType = .none
        }
        alert.addTextField { tf in
            tf.placeholder = "Mật khẩu"
            tf.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Đăng nhập", style: .default) { [weak self] _ in
            let email = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pass = alert.textFields?.last?.text ?? ""
            guard !email.isEmpty, !pass.isEmpty else { return }
            DichVuSupabase.dungChung.dangNhap(email: email, matKhau: pass) { kq in
                switch kq {
                case .success:
                    self?.veGiaoDien()
                    self?.hienThongBao("Thành công", "Đã đăng nhập tài khoản \(email)!")
                case .failure(let err):
                    self?.hienThongBao("Lỗi đăng nhập", err.localizedDescription)
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Đăng ký mới", style: .default) { [weak self] _ in
            let email = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pass = alert.textFields?.last?.text ?? ""
            guard !email.isEmpty, !pass.isEmpty else { return }
            DichVuSupabase.dungChung.dangKy(email: email, matKhau: pass) { kq in
                switch kq {
                case .success(let msg):
                    self?.veGiaoDien()
                    self?.hienThongBao("Thành công", msg)
                case .failure(let err):
                    self?.hienThongBao("Lỗi đăng ký", err.localizedDescription)
                }
            }
        })
        present(alert, animated: true)
    }

    private func hienThongBao(_ tieuDe: String, _ noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}
