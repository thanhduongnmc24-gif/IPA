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
    private let nganGioThongBaoThucDon = UIStackView()
    private let nganGioThongBaoLenhSX = UIStackView()

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
            cuon.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 10),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -50),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        // Thêm khoảng đệm cuộn 60pt ở đáy để người dùng luôn kéo thấy hết nội dung
        cuon.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0)

        // Đăng ký thông báo bàn phím để tự động cuộn lên khi bàn phím xuất hiện
        NotificationCenter.default.addObserver(self, selector: #selector(khiBanPhimHien(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(khiBanPhimAn(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Chạm ra ngoài để ẩn bàn phím
        let cham = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        cham.cancelsTouchesInView = false
        view.addGestureRecognizer(cham)

        banNhap = KhoDuLieu.dungChung.caiDat
        veGiaoDien()
        NotificationCenter.default.addObserver(self, selector: #selector(khiDongBoXong), name: .duLieuDongBoXong, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func anBanPhim() {
        view.endEditing(true)
    }

    @objc private func khiBanPhimHien(_ notif: Notification) {
        guard let userInfo = notif.userInfo,
              let kbFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let kbHeight = kbFrame.height
        cuon.contentInset.bottom = kbHeight + 40
        cuon.verticalScrollIndicatorInsets.bottom = kbHeight

        if oGemini.isFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                let khung = self.oGemini.convert(self.oGemini.bounds, to: self.cuon)
                self.cuon.scrollRectToVisible(khung.insetBy(dx: 0, dy: -60), animated: true)
            }
        }
    }

    @objc private func khiBanPhimAn(_ notif: Notification) {
        cuon.contentInset.bottom = 60
        cuon.verticalScrollIndicatorInsets.bottom = 0
    }

    @objc private func khiDongBoXong() {
        banNhap = KhoDuLieu.dungChung.caiDat
        veGiaoDien()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let hienTai = KhoDuLieu.dungChung.caiDat
        banNhap.driveClientId = hienTai.driveClientId
        banNhap.driveClientSecret = hienTai.driveClientSecret
        banNhap.driveRefreshToken = hienTai.driveRefreshToken
        banNhap.driveFolderId = hienTai.driveFolderId
        if banNhap.thuTuTab != hienTai.thuTuTab {
            banNhap.thuTuTab = hienTai.thuTuTab
            veGiaoDien()
        }
    }

    @objc private func bamLuuCaiDat() {
        view.endEditing(true)
        let hienTai = KhoDuLieu.dungChung.caiDat
        banNhap.driveClientId = hienTai.driveClientId
        banNhap.driveClientSecret = hienTai.driveClientSecret
        banNhap.driveRefreshToken = hienTai.driveRefreshToken
        banNhap.driveFolderId = hienTai.driveFolderId
        banNhap.geminiApiKey = oGemini.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        KhoDuLieu.dungChung.luuCaiDat(banNhap, thongBao: true)
        veGiaoDien()
        hienThongBao("Đã lưu cài đặt", "Thứ tự sắp xếp các Tab, cài đặt hiển thị và lịch hẹn giờ thông báo đã được lưu lại!")
    }

    private func diChuyenTab(tai chiSo: Int, lenTren: Bool) {
        var ds = banNhap.danhSachLoaiTabTheoThuTu
        let dich = lenTren ? (chiSo - 1) : (chiSo + 1)
        guard chiSo >= 0, chiSo < ds.count, dich >= 0, dich < ds.count else { return }
        ds.swapAt(chiSo, dich)
        banNhap.thuTuTab = ds.map(\.rawValue)
        veGiaoDien()
    }

    private func veGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        nganChinh.arrangedSubviews.forEach {
            nganChinh.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        // 1. Tài khoản & Đồng bộ Supabase
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

        // 2. Google Drive & Bộ nhớ đệm ảnh
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

        // 3. Giao diện, Ẩn/Hiện & Sắp xếp thứ tự Tab
        nganChinh.addArrangedSubview(taoTieuDeMuc("🎨 GIAO DIỆN & SẮP XẾP THỨ TỰ CÁC TAB (BẤM LƯU ĐỂ ÁP DỤNG)"))
        let theTab = taoThe()
        let nganTab = taoNganBenTrong(theTab)

        nganTab.addArrangedSubview(taoHangCongTac(ten: "Chế độ Tối (Dark Mode)", dangBat: banNhap.giaoDienToi) { [weak self] bat in
            self?.banNhap.giaoDienToi = bat
        })
        nganTab.addArrangedSubview(taoVachNgan())

        let lbHuongDanTab = UILabel()
        lbHuongDanTab.text = "Mẹo: Bạn có thể bấm ▲ / ▼ bên dưới hoặc vào mục Thêm (...) -> Sửa trên thanh Tab để đổi thứ tự. Thứ tự sẽ tự động lưu lại cho lần mở sau."
        lbHuongDanTab.font = .systemFont(ofSize: 11.5)
        lbHuongDanTab.textColor = mau.subText
        lbHuongDanTab.numberOfLines = 0
        nganTab.addArrangedSubview(lbHuongDanTab)

        let danhSachTab = banNhap.danhSachLoaiTabTheoThuTu
        for (idx, loai) in danhSachTab.enumerated() {
            let hang = taoHangQuanLyTab(
                loai: loai,
                viTri: idx,
                tongSo: danhSachTab.count,
                dangBat: banNhap.trangThaiTab.dangBat(loai)
            )
            nganTab.addArrangedSubview(hang)
        }

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

        // 4A. Thông báo nhắc ca / nghỉ luân phiên
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

        // 4B. Thông báo Thực đơn theo 4 khung giờ: Sáng - Trưa - Chiều - Đêm
        nganChuKy.addArrangedSubview(taoVachNgan())
        nganChuKy.addArrangedSubview(taoHangCongTac(ten: "Bật thông báo Thực đơn 🍱", dangBat: banNhap.batThongBaoThucDon) { [weak self] bat in
            self?.banNhap.batThongBaoThucDon = bat
            self?.nganGioThongBaoThucDon.isHidden = !bat
        })

        nganGioThongBaoThucDon.axis = .vertical
        nganGioThongBaoThucDon.spacing = 6
        nganGioThongBaoThucDon.arrangedSubviews.forEach {
            nganGioThongBaoThucDon.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        nganGioThongBaoThucDon.addArrangedSubview(taoHangGioNhac("Giờ báo thực đơn Sáng 🥖", gio: banNhap.gioThongBaoThucDonSang) { [weak self] d in
            self?.banNhap.gioThongBaoThucDonSang = d
        })
        nganGioThongBaoThucDon.addArrangedSubview(taoHangGioNhac("Giờ báo thực đơn Trưa 🍱", gio: banNhap.gioThongBaoThucDonTrua) { [weak self] d in
            self?.banNhap.gioThongBaoThucDonTrua = d
        })
        nganGioThongBaoThucDon.addArrangedSubview(taoHangGioNhac("Giờ báo thực đơn Chiều 🍲", gio: banNhap.gioThongBaoThucDonChieu) { [weak self] d in
            self?.banNhap.gioThongBaoThucDonChieu = d
        })
        nganGioThongBaoThucDon.addArrangedSubview(taoHangGioNhac("Giờ báo thực đơn Đêm 🌙", gio: banNhap.gioThongBaoThucDonDem) { [weak self] d in
            self?.banNhap.gioThongBaoThucDonDem = d
        })
        nganGioThongBaoThucDon.isHidden = !banNhap.batThongBaoThucDon
        nganChuKy.addArrangedSubview(nganGioThongBaoThucDon)

        // 4C. Thông báo Lệnh sản xuất vào khung giờ bắt đầu ca (Ca Ngày & Ca Đêm)
        nganChuKy.addArrangedSubview(taoVachNgan())
        nganChuKy.addArrangedSubview(taoHangCongTac(ten: "Bật thông báo Lệnh sản xuất 🏭", dangBat: banNhap.batThongBaoLenhSX) { [weak self] bat in
            self?.banNhap.batThongBaoLenhSX = bat
            self?.nganGioThongBaoLenhSX.isHidden = !bat
        })

        nganGioThongBaoLenhSX.axis = .vertical
        nganGioThongBaoLenhSX.spacing = 6
        nganGioThongBaoLenhSX.arrangedSubviews.forEach {
            nganGioThongBaoLenhSX.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        nganGioThongBaoLenhSX.addArrangedSubview(taoHangGioNhac("Giờ báo bắt đầu Ca Ngày ☀️", gio: banNhap.gioThongBaoLenhSXCaNgay) { [weak self] d in
            self?.banNhap.gioThongBaoLenhSXCaNgay = d
        })
        nganGioThongBaoLenhSX.addArrangedSubview(taoHangGioNhac("Giờ báo bắt đầu Ca Đêm 🌙", gio: banNhap.gioThongBaoLenhSXCaDem) { [weak self] d in
            self?.banNhap.gioThongBaoLenhSXCaDem = d
        })
        nganGioThongBaoLenhSX.isHidden = !banNhap.batThongBaoLenhSX
        nganChuKy.addArrangedSubview(nganGioThongBaoLenhSX)

        nganChinh.addArrangedSubview(theChuKy)

        // 5. Gemini API Key & Chọn Model AI (3.5 Flash Lite / 3.1 Flash Lite)
        nganChinh.addArrangedSubview(taoTieuDeMuc("🤖 GEMINI API KEY & MODEL AI QUÉT LỆNH SX"))
        let theGemini = taoThe()
        let nganGemini = taoNganBenTrong(theGemini)

        let lbHuongDan = UILabel()
        lbHuongDan.text = "Nhập Gemini API Key và chọn Model ưu tiên để quét Lệnh Sản Xuất chính xác 100% (tự động chuyển đổi dự phòng 3.5 Flash Lite ↔ 3.1 Flash Lite khi hết quota):"
        lbHuongDan.font = .systemFont(ofSize: 12)
        lbHuongDan.textColor = mau.subText
        lbHuongDan.numberOfLines = 0
        nganGemini.addArrangedSubview(lbHuongDan)

        let chonModel = UISegmentedControl(items: ["⚡ 3.5 Flash Lite", "🚀 3.1 Flash Lite"])
        chonModel.selectedSegmentIndex = banNhap.geminiModel.contains("3.1") ? 1 : 0
        chonModel.selectedSegmentTintColor = mau.primary
        chonModel.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 12.5, weight: .bold)], for: .selected)
        chonModel.setTitleTextAttributes([.foregroundColor: mau.text, .font: UIFont.systemFont(ofSize: 12.5, weight: .medium)], for: .normal)
        chonModel.addAction(UIAction { [weak self, weak chonModel] _ in
            guard let self = self, let chonModel = chonModel else { return }
            let modelMoi = (chonModel.selectedSegmentIndex == 1) ? "gemini-3.1-flash-lite" : "gemini-3.5-flash-lite"
            self.banNhap.geminiModel = modelMoi
            var cd = KhoDuLieu.dungChung.caiDat
            cd.geminiModel = modelMoi
            if let txtKey = self.oGemini.text?.trimmingCharacters(in: .whitespacesAndNewlines), !txtKey.isEmpty {
                cd.geminiApiKey = txtKey
                self.banNhap.geminiApiKey = txtKey
            }
            KhoDuLieu.dungChung.luuCaiDat(cd, thongBao: true)
        }, for: .valueChanged)
        nganGemini.addArrangedSubview(chonModel)

        oGemini.borderStyle = .roundedRect
        oGemini.placeholder = "Dán key AIzaSy... vào đây"
        oGemini.font = .systemFont(ofSize: 13)
        oGemini.text = banNhap.geminiApiKey
        oGemini.isSecureTextEntry = true
        oGemini.autocorrectionType = .no
        oGemini.autocapitalizationType = .none
        oGemini.clearButtonMode = .whileEditing
        oGemini.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let k = self.oGemini.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.banNhap.geminiApiKey = k
            var cd = KhoDuLieu.dungChung.caiDat
            cd.geminiApiKey = k
            cd.geminiModel = self.banNhap.geminiModel
            KhoDuLieu.dungChung.luuCaiDat(cd, thongBao: false)
        }, for: .editingChanged)

        // Nút Hiện/Ẩn Key (icon con mắt)
        let nutHienAn = UIButton(type: .system)
        nutHienAn.setImage(UIImage(systemName: "eye"), for: .normal)
        nutHienAn.tintColor = mau.subText
        nutHienAn.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        nutHienAn.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.oGemini.isSecureTextEntry.toggle()
            let icon = self.oGemini.isSecureTextEntry ? "eye" : "eye.slash"
            nutHienAn.setImage(UIImage(systemName: icon), for: .normal)
        }, for: .touchUpInside)
        oGemini.rightView = nutHienAn
        oGemini.rightViewMode = .always

        // Toolbar phụ trên bàn phím có nút "Xong"
        let thanhPhu = UIToolbar()
        thanhPhu.sizeToFit()
        let nutCach = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let nutXong = UIBarButtonItem(title: "Xong", style: .done, target: self, action: #selector(anBanPhim))
        thanhPhu.items = [nutCach, nutXong]
        oGemini.inputAccessoryView = thanhPhu

        // Hàng nút: Dán Key từ Clipboard (Tự động lưu ngay lập tức)
        let nutDanKey = UIButton(type: .system)
        var chDan = UIButton.Configuration.tinted()
        chDan.title = "📋 Dán Key từ bộ nhớ tạm & Lưu ngay"
        chDan.baseForegroundColor = mau.primary
        chDan.cornerStyle = .medium
        nutDanKey.configuration = chDan
        nutDanKey.heightAnchor.constraint(equalToConstant: 38).isActive = true
        nutDanKey.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            if let chuoiDan = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !chuoiDan.isEmpty {
                self.oGemini.text = chuoiDan
                self.banNhap.geminiApiKey = chuoiDan
                var cd = KhoDuLieu.dungChung.caiDat
                cd.geminiApiKey = chuoiDan
                cd.geminiModel = self.banNhap.geminiModel
                KhoDuLieu.dungChung.luuCaiDat(cd, thongBao: true)
                self.hienThongBao("Đã dán & Lưu Key! ✅", "Gemini API Key và model \(cd.tenHienThiModelGemini) đã được kích hoạt để quét Lệnh Sản Xuất.")
            } else {
                self.hienThongBao("Chưa copy Key", "Hãy copy Gemini API Key vào bộ nhớ tạm trước khi bấm dán.")
            }
        }, for: .touchUpInside)

        let hangGemini = UIStackView(arrangedSubviews: [oGemini, nutDanKey])
        hangGemini.axis = .vertical
        hangGemini.spacing = 8
        nganGemini.addArrangedSubview(hangGemini)
        nganChinh.addArrangedSubview(theGemini)


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

    private func taoHangQuanLyTab(loai: LoaiTabUngDung, viTri: Int, tongSo: Int, dangBat: Bool) -> UIStackView {
        let mau = KhoDuLieu.dungChung.mauSac

        let lb = UILabel()
        lb.text = "\(viTri + 1). \(loai.tenCaiDat)"
        lb.font = .systemFont(ofSize: 13.5, weight: .medium)
        lb.textColor = mau.text
        lb.lineBreakMode = .byTruncatingTail

        let nutLen = UIButton(type: .system)
        nutLen.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        nutLen.tintColor = mau.primary
        nutLen.backgroundColor = mau.iconBg
        nutLen.layer.cornerRadius = 6
        nutLen.isEnabled = (viTri > 0)
        nutLen.alpha = (viTri > 0) ? 1.0 : 0.35
        nutLen.widthAnchor.constraint(equalToConstant: 28).isActive = true
        nutLen.heightAnchor.constraint(equalToConstant: 26).isActive = true
        nutLen.addAction(UIAction { [weak self] _ in
            self?.diChuyenTab(tai: viTri, lenTren: true)
        }, for: .touchUpInside)

        let nutXuong = UIButton(type: .system)
        nutXuong.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        nutXuong.tintColor = mau.primary
        nutXuong.backgroundColor = mau.iconBg
        nutXuong.layer.cornerRadius = 6
        nutXuong.isEnabled = (viTri < tongSo - 1)
        nutXuong.alpha = (viTri < tongSo - 1) ? 1.0 : 0.35
        nutXuong.widthAnchor.constraint(equalToConstant: 28).isActive = true
        nutXuong.heightAnchor.constraint(equalToConstant: 26).isActive = true
        nutXuong.addAction(UIAction { [weak self] _ in
            self?.diChuyenTab(tai: viTri, lenTren: false)
        }, for: .touchUpInside)

        let sw = UISwitch()
        sw.isOn = dangBat
        sw.onTintColor = mau.primary
        sw.transform = CGAffineTransform(scaleX: 0.80, y: 0.80)
        sw.isEnabled = (loai != .caiDat)
        sw.addAction(UIAction { [weak self, weak sw] _ in
            self?.banNhap.trangThaiTab.datTrangThai(loai, bat: sw?.isOn ?? true)
        }, for: .valueChanged)

        let nhomPhai = UIStackView(arrangedSubviews: [nutLen, nutXuong, sw])
        nhomPhai.axis = .horizontal
        nhomPhai.spacing = 6
        nhomPhai.alignment = .center

        let h = UIStackView(arrangedSubviews: [lb, nhomPhai])
        h.distribution = .equalSpacing
        h.alignment = .center
        h.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return h
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
