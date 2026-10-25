import UIKit

final class ManHinhCaiDat: UIViewController {
    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    // Bản nháp cài đặt: Mọi thay đổi trên màn hình chỉ lưu vào biến tạm này,
    // KHÔNG tự động reload hay chuyển tab. Chỉ khi bấm nút "Lưu" mới áp dụng!
    private var banNhap: CaiDatUngDung = KhoDuLieu.dungChung.caiDat
    private let oGemini = UITextField()
    private let nhanChuKy = UILabel()
    private let nganGioThongBao = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Cài Đặt"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Lưu",
            style: .done,
            target: self,
            action: #selector(bamLuuCaiDat)
        )

        cuon.keyboardDismissMode = .interactive
        cuon.alwaysBounceVertical = true
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 10
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 10),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -28),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        banNhap = KhoDuLieu.dungChung.caiDat
        veGiaoDien()
        NotificationCenter.default.addObserver(self, selector: #selector(khiDongBoXong), name: .duLieuDongBoXong, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func khiDongBoXong() {
        banNhap = KhoDuLieu.dungChung.caiDat
        veGiaoDien()
    }

    @objc private func bamLuuCaiDat() {
        view.endEditing(true)
        banNhap.geminiApiKey = oGemini.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        KhoDuLieu.dungChung.luuCaiDat(banNhap, thongBao: true)
        veGiaoDien()
        hienThongBao("Đã lưu cài đặt", "Các thay đổi của bạn đã được áp dụng!")
    }

    private func veGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        nganChinh.arrangedSubviews.forEach {
            nganChinh.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        // 1. Tài khoản & Đồng bộ Supabase (Gọn gàng trên 2 dòng)
        nganChinh.addArrangedSubview(taoTieuDeMuc("☁️ ĐỒNG BỘ SUPABASE"))
        let theDongBo = taoThe()
        let nganDongBo = taoNganBenTrong(theDongBo)

        if DichVuSupabase.dungChung.daDangNhap {
            let lbEmail = UILabel()
            lbEmail.text = "● \(DichVuSupabase.dungChung.emailNguoiDung ?? "")"
            lbEmail.font = .systemFont(ofSize: 13, weight: .semibold)
            lbEmail.textColor = mau.success
            lbEmail.lineBreakMode = .byTruncatingTail

            let nutDangXuat = taoNutNho("Đăng xuất", mau: mau.error) { [weak self] in
                DichVuSupabase.dungChung.dangXuat()
                self?.veGiaoDien()
            }
            nutDangXuat.widthAnchor.constraint(equalToConstant: 86).isActive = true

            let hangTaiKhoan = UIStackView(arrangedSubviews: [lbEmail, nutDangXuat])
            hangTaiKhoan.axis = .horizontal
            hangTaiKhoan.spacing = 8
            hangTaiKhoan.alignment = .center

            let hangNutDongBo = UIStackView(arrangedSubviews: [
                taoNutNho("☁️ Sao lưu lên mây", mau: mau.primary) { [weak self] in
                    DichVuSupabase.dungChung.saoLuuTatCaLenMay { ok, msg in
                        self?.hienThongBao(ok ? "Thành công" : "Lỗi", msg)
                    }
                },
                taoNutNho("📥 Khôi phục về máy", mau: mau.success) { [weak self] in
                    DichVuSupabase.dungChung.khoiPhucTuMay { ok, msg in
                        self?.hienThongBao(ok ? "Thành công" : "Lỗi", msg)
                    }
                }
            ])
            hangNutDongBo.distribution = .fillEqually
            hangNutDongBo.spacing = 8

            nganDongBo.addArrangedSubview(hangTaiKhoan)
            nganDongBo.addArrangedSubview(hangNutDongBo)
        } else {
            let nutDN = taoNutNho("🔑 Đăng nhập / Đăng ký Supabase", mau: mau.primary) { [weak self] in
                self?.hienHopThoaiDangNhap()
            }
            nganDongBo.addArrangedSubview(nutDN)
        }
        nganChinh.addArrangedSubview(theDongBo)

        // 2. Google Drive & Bộ nhớ đệm ảnh (Gọn gàng 1 hàng thông tin + 1 hàng 2 nút ngang)
        nganChinh.addArrangedSubview(taoTieuDeMuc("🗂️ GOOGLE DRIVE & BỘ NHỚ ĐỆM ẢNH"))
        let theDrive = taoThe()
        let nganDrive = taoNganBenTrong(theDrive)

        let daKetNoiDrive = !banNhap.driveRefreshToken.isEmpty
        let lbCache = UILabel()
        lbCache.text = "Cache ảnh: \(BoNhoDemAnh.dungChung.dungLuongBoNhoDemChuoi()) • Drive OAuth: \(daKetNoiDrive ? "Đã kết nối" : "Chưa kết nối")"
        lbCache.font = .systemFont(ofSize: 12.5)
        lbCache.textColor = mau.subText

        let hangNutDrive = UIStackView(arrangedSubviews: [
            taoNutNho("⚙️ Kết nối Drive", mau: mau.primary) { [weak self] in
                let vc = ManHinhCauHinhDriveXuongCan()
                self?.present(UINavigationController(rootViewController: vc), animated: true)
            },
            taoNutNho("🧹 Dọn Cache", mau: mau.error) { [weak self] in
                BoNhoDemAnh.dungChung.xoaBoNhoDem()
                self?.veGiaoDien()
            }
        ])
        hangNutDrive.distribution = .fillEqually
        hangNutDrive.spacing = 8

        nganDrive.addArrangedSubview(lbCache)
        nganDrive.addArrangedSubview(hangNutDrive)
        nganChinh.addArrangedSubview(theDrive)

        // 3. Giao diện & Quản lý Tab (Gộp gọn, chỉ thay đổi biến tạm banNhap, bấm Lưu mới áp dụng)
        nganChinh.addArrangedSubview(taoTieuDeMuc("🎨 GIAO DIỆN & CÁC TAB HIỂN THỊ (BẤM LƯU ĐỂ ÁP DỤNG)"))
        let theTab = taoThe()
        let nganTab = taoNganBenTrong(theTab)

        nganTab.addArrangedSubview(taoHangCongTac(ten: "Chế độ Tối (Dark Mode)", dangBat: banNhap.giaoDienToi) { [weak self] bat in
            self?.banNhap.giaoDienToi = bat
        })
        nganTab.addArrangedSubview(taoVachNgan())
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Xưởng Cán (Đầu tiên)", dangBat: banNhap.trangThaiTab.xuongCan) { [weak self] bat in
            self?.banNhap.trangThaiTab.xuongCan = bat
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Lịch làm việc", dangBat: banNhap.trangThaiTab.calendar) { [weak self] bat in
            self?.banNhap.trangThaiTab.calendar = bat
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Ghi chú", dangBat: banNhap.trangThaiTab.notes) { [weak self] bat in
            self?.banNhap.trangThaiTab.notes = bat
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Trang tính (Sheets)", dangBat: banNhap.trangThaiTab.sheets) { [weak self] bat in
            self?.banNhap.trangThaiTab.sheets = bat
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Media AI", dangBat: banNhap.trangThaiTab.media) { [weak self] bat in
            self?.banNhap.trangThaiTab.media = bat
        })
        nganTab.addArrangedSubview(taoHangCongTac(ten: "Tab Nhắc nhở", dangBat: banNhap.trangThaiTab.reminders) { [weak self] bat in
            self?.banNhap.trangThaiTab.reminders = bat
        })
        nganChinh.addArrangedSubview(theTab)

        // 4. Chu kỳ ca làm việc & Thông báo
        nganChinh.addArrangedSubview(taoTieuDeMuc("⚙️ CHU KỲ CA & THÔNG BÁO"))
        let theChuKy = taoThe()
        let nganChuKy = taoNganBenTrong(theChuKy)

        nhanChuKy.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nhanChuKy.textColor = mau.text
        nhanChuKy.numberOfLines = 0
        capNhatTextChuKy()
        nganChuKy.addArrangedSubview(nhanChuKy)

        let hangThemCa = UIStackView(arrangedSubviews: [
            taoNutNho("+ Ngày", mau: .systemOrange) { [weak self] in
                self?.banNhap.chuKyLamViec.append("ngay")
                self?.capNhatTextChuKy()
            },
            taoNutNho("+ Đêm", mau: .systemIndigo) { [weak self] in
                self?.banNhap.chuKyLamViec.append("dem")
                self?.capNhatTextChuKy()
            },
            taoNutNho("+ Nghỉ", mau: mau.success) { [weak self] in
                self?.banNhap.chuKyLamViec.append("nghi")
                self?.capNhatTextChuKy()
            },
            taoNutNho("Xóa cuối", mau: mau.error) { [weak self] in
                guard let self, self.banNhap.chuKyLamViec.count > 1 else { return }
                self.banNhap.chuKyLamViec.removeLast()
                self.capNhatTextChuKy()
            }
        ])
        hangThemCa.distribution = .fillEqually
        hangThemCa.spacing = 5
        nganChuKy.addArrangedSubview(hangThemCa)

        let chonNgayBD = UIDatePicker()
        chonNgayBD.datePickerMode = .date
        chonNgayBD.preferredDatePickerStyle = .compact
        chonNgayBD.locale = Locale(identifier: "vi_VN")
        chonNgayBD.date = banNhap.ngayBatDauChuKy
        chonNgayBD.addAction(UIAction { [weak self, weak chonNgayBD] _ in
            guard let d = chonNgayBD?.date else { return }
            self?.banNhap.ngayBatDauChuKy = d
            self?.banNhap.daChonNgayBatDau = true
        }, for: .valueChanged)

        let lbBD = UILabel()
        lbBD.text = "Ngày bắt đầu Bước 1:"
        lbBD.font = .systemFont(ofSize: 13.5, weight: .medium)
        lbBD.textColor = mau.text

        let hangNgayBD = UIStackView(arrangedSubviews: [lbBD, chonNgayBD])
        hangNgayBD.distribution = .equalSpacing
        hangNgayBD.alignment = .center
        nganChuKy.addArrangedSubview(hangNgayBD)

        nganChuKy.addArrangedSubview(taoVachNgan())
        nganChuKy.addArrangedSubview(taoHangCongTac(ten: "Bật thông báo nhắc ca", dangBat: banNhap.batThongBao) { [weak self] bat in
            self?.banNhap.batThongBao = bat
            self?.nganGioThongBao.isHidden = !bat
        })

        nganGioThongBao.axis = .vertical
        nganGioThongBao.spacing = 6
        nganGioThongBao.arrangedSubviews.forEach {
            nganGioThongBao.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        nganGioThongBao.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ca Ngày ☀️", gio: banNhap.gioCaNgay) { [weak self] d in
            self?.banNhap.gioCaNgay = d
        })
        nganGioThongBao.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ca Đêm 🌙", gio: banNhap.gioCaDem) { [weak self] d in
            self?.banNhap.gioCaDem = d
        })
        nganGioThongBao.addArrangedSubview(taoHangGioNhac("Giờ nhắc Ngày Nghỉ ☕", gio: banNhap.gioNgayNghi) { [weak self] d in
            self?.banNhap.gioNgayNghi = d
        })
        nganGioThongBao.isHidden = !banNhap.batThongBao
        nganChuKy.addArrangedSubview(nganGioThongBao)
        nganChinh.addArrangedSubview(theChuKy)

        // 5. Gemini API Key
        nganChinh.addArrangedSubview(taoTieuDeMuc("🤖 GEMINI API KEY"))
        let theGemini = taoThe()
        let nganGemini = taoNganBenTrong(theGemini)
        oGemini.borderStyle = .roundedRect
        oGemini.placeholder = "AIzaSy..."
        oGemini.font = .systemFont(ofSize: 13)
        oGemini.text = banNhap.geminiApiKey
        oGemini.isSecureTextEntry = true
        nganGemini.addArrangedSubview(oGemini)
        nganChinh.addArrangedSubview(theGemini)

        // 6. Nút Lưu Cài Đặt nổi bật ở cuối trang
        let nutLuuCuoi = UIButton(type: .system)
        var chLuu = UIButton.Configuration.filled()
        chLuu.title = "💾 LƯU CÀI ĐẶT"
        chLuu.baseBackgroundColor = mau.primary
        chLuu.cornerStyle = .medium
        nutLuuCuoi.configuration = chLuu
        nutLuuCuoi.heightAnchor.constraint(equalToConstant: 42).isActive = true
        nutLuuCuoi.addTarget(self, action: #selector(bamLuuCaiDat), for: .touchUpInside)
        nganChinh.addArrangedSubview(nutLuuCuoi)
    }

    private func capNhatTextChuKy() {
        let chuoi = banNhap.chuKyLamViec.enumerated().map { idx, loai -> String in
            switch loai {
            case "ngay": return "\(idx + 1).☀️Ngày"
            case "dem": return "\(idx + 1).🌙Đêm"
            default: return "\(idx + 1).☕Nghỉ"
            }
        }.joined(separator: " → ")
        nhanChuKy.text = "Chu kỳ: \(chuoi)"
    }

    private func taoTieuDeMuc(_ chu: String) -> UILabel {
        let lb = UILabel()
        lb.text = chu
        lb.font = .systemFont(ofSize: 11, weight: .bold)
        lb.textColor = KhoDuLieu.dungChung.mauSac.subText
        return lb
    }

    private func taoThe() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let v = UIView()
        v.backgroundColor = mau.card
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = mau.border.cgColor
        return v
    }

    private func taoNganBenTrong(_ the: UIView) -> UIStackView {
        let st = UIStackView()
        st.axis = .vertical
        st.spacing = 8
        st.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(st)
        NSLayoutConstraint.activate([
            st.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
            st.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
            st.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            st.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])
        return st
    }

    private func taoVachNgan() -> UIView {
        let v = UIView()
        v.backgroundColor = KhoDuLieu.dungChung.mauSac.border
        v.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
        return v
    }

    private func taoNutNho(_ tieuDe: String, mau: UIColor, hanhDong: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(tieuDe, for: .normal)
        b.setTitleColor(mau, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        b.titleLabel?.numberOfLines = 1
        b.titleLabel?.lineBreakMode = .byTruncatingTail
        b.backgroundColor = mau.withAlphaComponent(0.12)
        b.layer.cornerRadius = 8
        b.heightAnchor.constraint(equalToConstant: 32).isActive = true
        b.addAction(UIAction { _ in hanhDong() }, for: .touchUpInside)
        return b
    }

    private func taoHangCongTac(ten: String, dangBat: Bool, khiDoi: @escaping (Bool) -> Void) -> UIStackView {
        let lb = UILabel()
        lb.text = ten
        lb.font = .systemFont(ofSize: 13.5, weight: .medium)
        lb.textColor = KhoDuLieu.dungChung.mauSac.text

        let sw = UISwitch()
        sw.isOn = dangBat
        sw.onTintColor = KhoDuLieu.dungChung.mauSac.primary
        sw.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        sw.addAction(UIAction { [weak sw] _ in
            khiDoi(sw?.isOn ?? false)
        }, for: .valueChanged)

        let h = UIStackView(arrangedSubviews: [lb, sw])
        h.distribution = .equalSpacing
        h.alignment = .center
        h.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return h
    }

    private func taoHangGioNhac(_ ten: String, gio: Date, khiDoi: @escaping (Date) -> Void) -> UIStackView {
        let lb = UILabel()
        lb.text = ten
        lb.font = .systemFont(ofSize: 13)
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
        let alert = UIAlertController(title: "Tài khoản Supabase", message: "Nhập Email và Mật khẩu", preferredStyle: .alert)
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
                    self?.banNhap = KhoDuLieu.dungChung.caiDat
                    self?.veGiaoDien()
                    self?.hienThongBao("Thành công", "Đã đăng nhập và khôi phục dữ liệu!")
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
