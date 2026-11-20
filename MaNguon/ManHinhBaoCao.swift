import UIKit

final class ManHinhBaoCao: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    // Các ô điều khiển phía trên
    private let nutComboboxKip = UIButton(type: .system)
    private let nhanTrangThaiLich = UILabel()
    private let chonNgay = UIDatePicker()
    private let oNhanVienDiLam = UITextField()
    private let oTongSoNhanVien = UITextField()

    // Ô kết quả bản text phía dưới
    private let oVanBanBaoCao = UITextView()
    private let nhanTrangThaiLuu = UILabel()

    private var ngayHienTai: Date = Date()
    private var kipHienTai: String = "1A"

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Báo Cáo TBM"

        let nutSaoChepNav = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(bamSaoChep)
        )
        let nutAnBanPhimNav = UIBarButtonItem(
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            style: .plain,
            target: self,
            action: #selector(anBanPhim)
        )
        navigationItem.rightBarButtonItems = [nutSaoChepNav, nutAnBanPhimNav]

        taoGiaoDien()
        napDuLieuBanDau()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capNhatMauGiaoDien),
            name: .caiDatThayDoi,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiDongBoXong),
            name: .duLieuDongBoXong,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiBanPhimHien(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(khiBanPhimAn(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capNhatMauGiaoDien()
        capNhatThongTinTheoLich(tuDongDoiKip: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        luuTrangThaiHienTai()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Khởi tạo Giao diện

    private func taoGiaoDien() {
        cuon.keyboardDismissMode = .interactive
        cuon.alwaysBounceVertical = true
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
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -28),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        let chamNgoai = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        chamNgoai.cancelsTouchesInView = false
        view.addGestureRecognizer(chamNgoai)

        // 1. Thẻ thông số đầu vào (Kíp, Ngày, Nhân sự đi làm / Tổng số nhân viên)
        let theThongSo = taoKhungThe()
        let nganThongSo = UIStackView()
        nganThongSo.axis = .vertical
        nganThongSo.spacing = 12
        nganThongSo.translatesAutoresizingMaskIntoConstraints = false
        theThongSo.addSubview(nganThongSo)

        NSLayoutConstraint.activate([
            nganThongSo.topAnchor.constraint(equalTo: theThongSo.topAnchor, constant: 12),
            nganThongSo.bottomAnchor.constraint(equalTo: theThongSo.bottomAnchor, constant: -12),
            nganThongSo.leadingAnchor.constraint(equalTo: theThongSo.leadingAnchor, constant: 12),
            nganThongSo.trailingAnchor.constraint(equalTo: theThongSo.trailingAnchor, constant: -12)
        ])

        // Hàng 1: Ô chọn Kíp (Combobox 1A / 2A)
        let lbKip = taoNhanTieuDe("Chọn Kíp:")
        lbKip.setContentHuggingPriority(.required, for: .horizontal)

        nutComboboxKip.showsMenuAsPrimaryAction = true
        nutComboboxKip.layer.cornerRadius = 8
        nutComboboxKip.layer.borderWidth = 1
        nutComboboxKip.contentHorizontalAlignment = .fill
        nutComboboxKip.heightAnchor.constraint(equalToConstant: 38).isActive = true

        nhanTrangThaiLich.font = .systemFont(ofSize: 12, weight: .medium)
        nhanTrangThaiLich.textAlignment = .right
        nhanTrangThaiLich.numberOfLines = 1

        let hangKip = UIStackView(arrangedSubviews: [lbKip, nutComboboxKip])
        hangKip.axis = .horizontal
        hangKip.spacing = 10
        hangKip.alignment = .center

        // Hàng 2: Ô chọn Ngày (Mặc định là ngày hiện tại)
        let lbNgay = taoNhanTieuDe("Chọn Ngày:")
        chonNgay.datePickerMode = .date
        chonNgay.preferredDatePickerStyle = .compact
        chonNgay.locale = Locale(identifier: "vi_VN")
        chonNgay.calendar = TienIchLich.lich
        chonNgay.date = Date()
        chonNgay.addTarget(self, action: #selector(khiDoiNgay(_:)), for: .valueChanged)

        let nutHomNay = UIButton(type: .system)
        var chHomNay = UIButton.Configuration.tinted()
        chHomNay.title = "Hôm nay"
        chHomNay.cornerStyle = .medium
        chHomNay.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        nutHomNay.configuration = chHomNay
        nutHomNay.addTarget(self, action: #selector(bamChonHomNay), for: .touchUpInside)

        let nhomNgayPhai = UIStackView(arrangedSubviews: [chonNgay, nutHomNay])
        nhomNgayPhai.axis = .horizontal
        nhomNgayPhai.spacing = 8
        nhomNgayPhai.alignment = .center

        let hangNgay = UIStackView(arrangedSubviews: [lbNgay, nhomNgayPhai])
        hangNgay.axis = .horizontal
        hangNgay.distribution = .equalSpacing
        hangNgay.alignment = .center

        // Hàng 3: Textbox nhân viên đi làm & Textbox tổng số nhân viên (Mặc định 9/9)
        let lbNhanSu = taoNhanTieuDe("Nhân sự (x/y):")
        lbNhanSu.setContentHuggingPriority(.required, for: .horizontal)

        cauHinhOTextNhanSu(oNhanVienDiLam, placeholder: "Đi làm")
        cauHinhOTextNhanSu(oTongSoNhanVien, placeholder: "Tổng số")

        let lbGachCheo = UILabel()
        lbGachCheo.text = "/"
        lbGachCheo.font = .systemFont(ofSize: 18, weight: .bold)
        lbGachCheo.textAlignment = .center
        lbGachCheo.setContentHuggingPriority(.required, for: .horizontal)

        let lbDonViNV = UILabel()
        lbDonViNV.text = "nhân viên"
        lbDonViNV.font = .systemFont(ofSize: 13.5, weight: .medium)
        lbDonViNV.setContentHuggingPriority(.required, for: .horizontal)

        let nhomONhanSu = UIStackView(arrangedSubviews: [oNhanVienDiLam, lbGachCheo, oTongSoNhanVien, lbDonViNV])
        nhomONhanSu.axis = .horizontal
        nhomONhanSu.spacing = 6
        nhomONhanSu.alignment = .center

        oNhanVienDiLam.widthAnchor.constraint(equalToConstant: 58).isActive = true
        oTongSoNhanVien.widthAnchor.constraint(equalToConstant: 58).isActive = true

        let hangNhanSu = UIStackView(arrangedSubviews: [lbNhanSu, nhomONhanSu])
        hangNhanSu.axis = .horizontal
        hangNhanSu.distribution = .equalSpacing
        hangNhanSu.alignment = .center

        nganThongSo.addArrangedSubview(hangKip)
        nganThongSo.addArrangedSubview(nhanTrangThaiLich)
        nganThongSo.addArrangedSubview(taoVachNgan())
        nganThongSo.addArrangedSubview(hangNgay)
        nganThongSo.addArrangedSubview(taoVachNgan())
        nganThongSo.addArrangedSubview(hangNhanSu)

        nganChinh.addArrangedSubview(theThongSo)

        // 2. Thẻ Kết quả bản text báo cáo TBM (Cho phép chỉnh sửa và tự động lưu mẫu)
        let theKetQua = taoKhungThe()
        let nganKetQua = UIStackView()
        nganKetQua.axis = .vertical
        nganKetQua.spacing = 10
        nganKetQua.translatesAutoresizingMaskIntoConstraints = false
        theKetQua.addSubview(nganKetQua)

        NSLayoutConstraint.activate([
            nganKetQua.topAnchor.constraint(equalTo: theKetQua.topAnchor, constant: 12),
            nganKetQua.bottomAnchor.constraint(equalTo: theKetQua.bottomAnchor, constant: -12),
            nganKetQua.leadingAnchor.constraint(equalTo: theKetQua.leadingAnchor, constant: 12),
            nganKetQua.trailingAnchor.constraint(equalTo: theKetQua.trailingAnchor, constant: -12)
        ])

        let lbTieuDeKetQua = UILabel()
        lbTieuDeKetQua.text = "📝 NỘI DUNG BÁO CÁO TBM (TỰ ĐỘNG LƯU MẪU)"
        lbTieuDeKetQua.font = .systemFont(ofSize: 12, weight: .bold)

        nhanTrangThaiLuu.text = "✓ Đã lưu"
        nhanTrangThaiLuu.font = .systemFont(ofSize: 11.5, weight: .semibold)
        nhanTrangThaiLuu.textAlignment = .right

        let hangTieuDeKetQua = UIStackView(arrangedSubviews: [lbTieuDeKetQua, nhanTrangThaiLuu])
        hangTieuDeKetQua.axis = .horizontal
        hangTieuDeKetQua.distribution = .equalSpacing
        hangTieuDeKetQua.alignment = .center

        oVanBanBaoCao.font = .systemFont(ofSize: 15, weight: .regular)
        oVanBanBaoCao.layer.cornerRadius = 10
        oVanBanBaoCao.layer.borderWidth = 1
        oVanBanBaoCao.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        oVanBanBaoCao.isScrollEnabled = false
        oVanBanBaoCao.delegate = self
        oVanBanBaoCao.inputAccessoryView = taoThanhCongCuBanPhim()
        oVanBanBaoCao.heightAnchor.constraint(greaterThanOrEqualToConstant: 290).isActive = true

        // Hàng nút thao tác nhanh (Sao chép bản text / Khôi phục mẫu mặc định)
        let nutSaoChep = UIButton(type: .system)
        var chCopy = UIButton.Configuration.filled()
        chCopy.title = "📋 Sao chép nội dung"
        chCopy.cornerStyle = .medium
        nutSaoChep.configuration = chCopy
        nutSaoChep.heightAnchor.constraint(equalToConstant: 40).isActive = true
        nutSaoChep.addTarget(self, action: #selector(bamSaoChep), for: .touchUpInside)

        let nutKhoiPhucMau = UIButton(type: .system)
        var chReset = UIButton.Configuration.tinted()
        chReset.title = "🔄 Mẫu gốc"
        chReset.cornerStyle = .medium
        nutKhoiPhucMau.configuration = chReset
        nutKhoiPhucMau.heightAnchor.constraint(equalToConstant: 40).isActive = true
        nutKhoiPhucMau.widthAnchor.constraint(equalToConstant: 115).isActive = true
        nutKhoiPhucMau.addTarget(self, action: #selector(bamKhoiPhucMauGoc), for: .touchUpInside)

        let hangNutThaoTac = UIStackView(arrangedSubviews: [nutSaoChep, nutKhoiPhucMau])
        hangNutThaoTac.axis = .horizontal
        hangNutThaoTac.spacing = 8
        hangNutThaoTac.alignment = .fill

        nganKetQua.addArrangedSubview(hangTieuDeKetQua)
        nganKetQua.addArrangedSubview(oVanBanBaoCao)
        nganKetQua.addArrangedSubview(hangNutThaoTac)

        nganChinh.addArrangedSubview(theKetQua)
    }

    private func cauHinhOTextNhanSu(_ tf: UITextField, placeholder: String) {
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 15, weight: .bold)
        tf.textAlignment = .center
        tf.placeholder = placeholder
        tf.keyboardType = .numberPad
        tf.delegate = self
        tf.inputAccessoryView = taoThanhCongCuBanPhim()
        tf.heightAnchor.constraint(equalToConstant: 36).isActive = true
        tf.addTarget(self, action: #selector(khiDoiNhanSu), for: .editingChanged)
    }

    private func taoThanhCongCuBanPhim() -> UIToolbar {
        let thanh = UIToolbar()
        thanh.sizeToFit()
        let khoangTrong = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let nutXong = UIBarButtonItem(title: "Xong", style: .done, target: self, action: #selector(anBanPhim))
        thanh.items = [khoangTrong, nutXong]
        return thanh
    }

    // MARK: - Nạp & Đồng bộ dữ liệu

    private func napDuLieuBanDau() {
        let duLieu = KhoDuLieu.dungChung.duLieuBaoCao
        let homNay = Date()
        ngayHienTai = homNay
        chonNgay.date = homNay

        let diLam = duLieu.soNhanVienDiLam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "9" : duLieu.soNhanVienDiLam
        let tongSo = duLieu.tongSoNhanVien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "9" : duLieu.tongSoNhanVien
        oNhanVienDiLam.text = diLam
        oTongSoNhanVien.text = tongSo

        let khoaHomNay = TienIchLich.dinhDangKhoaNgay.string(from: homNay)
        let goiYLich = TienIchLich.xacDinhKipTheoLich(cho: homNay)

        if duLieu.khoaNgayLuu == khoaHomNay, (duLieu.kip == "1A" || duLieu.kip == "2A") {
            kipHienTai = duLieu.kip
        } else {
            kipHienTai = goiYLich.kip
        }

        nhanTrangThaiLich.text = goiYLich.moTaLich
        capNhatMenuComboboxKip()

        // Nếu đã có bản mẫu lưu từ lần trước thì nạp y hệt và đồng bộ thông số Kíp/Ngày/Nhân sự
        let vanBanDaLuu = duLieu.noiDungMau.trimmingCharacters(in: .whitespacesAndNewlines)
        if vanBanDaLuu.isEmpty {
            oVanBanBaoCao.text = DuLieuBaoCaoTBM.taoVanBanMacDinh(
                kip: kipHienTai,
                ngay: ngayHienTai,
                diLam: diLam,
                tongSo: tongSo
            )
        } else {
            oVanBanBaoCao.text = duLieu.noiDungMau
            dongBoThongSoVaoVanBan()
        }

        luuTrangThaiHienTai()
        capNhatMauGiaoDien()
    }

    @objc private func khiDongBoXong() {
        let duLieu = KhoDuLieu.dungChung.duLieuBaoCao
        oNhanVienDiLam.text = duLieu.soNhanVienDiLam.isEmpty ? "9" : duLieu.soNhanVienDiLam
        oTongSoNhanVien.text = duLieu.tongSoNhanVien.isEmpty ? "9" : duLieu.tongSoNhanVien
        if duLieu.kip == "1A" || duLieu.kip == "2A" {
            kipHienTai = duLieu.kip
        }
        if !duLieu.noiDungMau.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            oVanBanBaoCao.text = duLieu.noiDungMau
        }
        capNhatMenuComboboxKip()
        capNhatMauGiaoDien()
    }

    private func capNhatThongTinTheoLich(tuDongDoiKip: Bool) {
        let thongTin = TienIchLich.xacDinhKipTheoLich(cho: ngayHienTai)
        nhanTrangThaiLich.text = thongTin.moTaLich
        if tuDongDoiKip {
            kipHienTai = thongTin.kip
        }
        capNhatMenuComboboxKip()
    }

    private func capNhatMenuComboboxKip() {
        let mau = KhoDuLieu.dungChung.mauSac
        let thongTinLich = TienIchLich.xacDinhKipTheoLich(cho: ngayHienTai)

        let hanhDong1A = UIAction(
            title: "1A — Ca Ngày ☀️",
            subtitle: (thongTinLich.kip == "1A") ? "Khớp với lịch ngày đang chọn" : nil,
            state: (kipHienTai == "1A") ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.kipHienTai = "1A"
            self.capNhatMenuComboboxKip()
            self.dongBoThongSoVaoVanBan()
        }

        let hanhDong2A = UIAction(
            title: "2A — Ca Đêm 🌙",
            subtitle: (thongTinLich.kip == "2A") ? "Khớp với lịch ngày đang chọn" : nil,
            state: (kipHienTai == "2A") ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.kipHienTai = "2A"
            self.capNhatMenuComboboxKip()
            self.dongBoThongSoVaoVanBan()
        }

        let hanhDongTheoLich = UIAction(
            title: "📅 Tự động theo lịch (\(thongTinLich.kip))",
            image: UIImage(systemName: "calendar.badge.clock")
        ) { [weak self] _ in
            guard let self else { return }
            self.kipHienTai = thongTinLich.kip
            self.capNhatMenuComboboxKip()
            self.dongBoThongSoVaoVanBan()
        }

        nutComboboxKip.menu = UIMenu(title: "Chọn Kíp (1A: Ca ngày • 2A: Ca đêm)", children: [hanhDong1A, hanhDong2A, hanhDongTheoLich])

        let moTaCa = (kipHienTai == "1A") ? "1A (Ca ngày ☀️)" : "2A (Ca đêm 🌙)"
        var config = UIButton.Configuration.plain()
        config.title = "\(moTaCa)  ▾"
        config.baseForegroundColor = mau.text
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        nutComboboxKip.configuration = config
        nutComboboxKip.backgroundColor = mau.iconBg
        nutComboboxKip.layer.borderColor = mau.border.cgColor
    }

    // MARK: - Cập nhật bản text theo lựa chọn của các ô điều khiển

    private func dongBoThongSoVaoVanBan() {
        let diLam = (oNhanVienDiLam.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "9"
        let tongSo = (oTongSoNhanVien.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "9"

        let hienTai = oVanBanBaoCao.text ?? ""
        let capNhat = DuLieuBaoCaoTBM.capNhatThongSoTrongVanBan(
            vanBanGoc: hienTai,
            kip: kipHienTai,
            ngay: ngayHienTai,
            diLam: diLam,
            tongSo: tongSo
        )
        oVanBanBaoCao.text = capNhat
        luuTrangThaiHienTai()
    }

    private func luuTrangThaiHienTai() {
        let diLam = (oNhanVienDiLam.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "9"
        let tongSo = (oTongSoNhanVien.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "9"
        let vanBan = oVanBanBaoCao.text ?? ""
        let khoaNgay = TienIchLich.dinhDangKhoaNgay.string(from: ngayHienTai)

        let moi = DuLieuBaoCaoTBM(
            kip: kipHienTai,
            khoaNgayLuu: khoaNgay,
            soNhanVienDiLam: diLam,
            tongSoNhanVien: tongSo,
            noiDungMau: vanBan
        )
        KhoDuLieu.dungChung.luuDuLieuBaoCao(moi)
        nhanTrangThaiLuu.text = "✓ Đã lưu mẫu"
    }

    // MARK: - Sự kiện người dùng

    @objc private func khiDoiNgay(_ sender: UIDatePicker) {
        ngayHienTai = sender.date
        capNhatThongTinTheoLich(tuDongDoiKip: true)
        dongBoThongSoVaoVanBan()
    }

    @objc private func bamChonHomNay() {
        ngayHienTai = Date()
        chonNgay.setDate(ngayHienTai, animated: true)
        capNhatThongTinTheoLich(tuDongDoiKip: true)
        dongBoThongSoVaoVanBan()
    }

    @objc private func khiDoiNhanSu() {
        dongBoThongSoVaoVanBan()
    }

    func textViewDidChange(_ textView: UITextView) {
        luuTrangThaiHienTai()
    }

    @objc private func bamSaoChep() {
        view.endEditing(true)
        let vanBan = oVanBanBaoCao.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !vanBan.isEmpty else { return }
        UIPasteboard.general.string = vanBan
        luuTrangThaiHienTai()

        let alert = UIAlertController(
            title: "Đã sao chép! 📋",
            message: "Nội dung báo cáo TBM đã được sao chép vào bộ nhớ tạm.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    @objc private func bamKhoiPhucMauGoc() {
        view.endEditing(true)
        let alert = UIAlertController(
            title: "Khôi phục mẫu gốc?",
            message: "Đặt lại nhân sự 9/9, ngày hiện tại và khôi phục nội dung văn bản về mẫu TBM mặc định?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Khôi phục", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.ngayHienTai = Date()
            self.chonNgay.date = self.ngayHienTai
            self.oNhanVienDiLam.text = "9"
            self.oTongSoNhanVien.text = "9"
            self.capNhatThongTinTheoLich(tuDongDoiKip: true)
            self.oVanBanBaoCao.text = DuLieuBaoCaoTBM.taoVanBanMacDinh(
                kip: self.kipHienTai,
                ngay: self.ngayHienTai,
                diLam: "9",
                tongSo: "9"
            )
            self.luuTrangThaiHienTai()
        })
        present(alert, animated: true)
    }

    @objc private func anBanPhim() {
        view.endEditing(true)
    }

    @objc private func khiBanPhimHien(_ notif: Notification) {
        guard let userInfo = notif.userInfo,
              let kbFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        cuon.contentInset.bottom = kbFrame.height + 24
        cuon.verticalScrollIndicatorInsets.bottom = kbFrame.height
    }

    @objc private func khiBanPhimAn(_ notif: Notification) {
        cuon.contentInset.bottom = 0
        cuon.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - Giao diện & Màu sắc

    @objc private func capNhatMauGiaoDien() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        for the in nganChinh.arrangedSubviews {
            the.backgroundColor = mau.card
            the.layer.borderColor = mau.border.cgColor
        }

        oNhanVienDiLam.backgroundColor = mau.iconBg
        oNhanVienDiLam.textColor = mau.text
        oTongSoNhanVien.backgroundColor = mau.iconBg
        oTongSoNhanVien.textColor = mau.text

        oVanBanBaoCao.backgroundColor = mau.iconBg
        oVanBanBaoCao.textColor = mau.text
        oVanBanBaoCao.layer.borderColor = mau.border.cgColor

        nhanTrangThaiLich.textColor = mau.primary
        nhanTrangThaiLuu.textColor = mau.success
        capNhatMenuComboboxKip()
    }

    private func taoKhungThe() -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let v = UIView()
        v.backgroundColor = mau.card
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = mau.border.cgColor
        return v
    }

    private func taoNhanTieuDe(_ chu: String) -> UILabel {
        let lb = UILabel()
        lb.text = chu
        lb.font = .systemFont(ofSize: 14, weight: .semibold)
        lb.textColor = KhoDuLieu.dungChung.mauSac.text
        return lb
    }

    private func taoVachNgan() -> UIView {
        let v = UIView()
        v.backgroundColor = KhoDuLieu.dungChung.mauSac.border
        v.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
        return v
    }
}
