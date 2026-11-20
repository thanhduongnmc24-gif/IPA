import UIKit

final class ManHinhBaoCao: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()

    // Các ô điều khiển phía trên
    private let nutComboboxKip = UIButton(type: .system)
    private let nhanHienThiNgay = UILabel()
    private let chonNgay = UIDatePicker()
    private let oNhanVienDiLam = UITextField()
    private let oTongSoNhanVien = UITextField()

    // Ô kết quả bản text phía dưới
    private let oVanBanBaoCao = UITextView()
    private let nhanTrangThaiLuu = UILabel()
    private let nutSaoChep = UIButton(type: .system)
    private let nutKhoiPhucMau = UIButton(type: .system)

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
        capNhatMenuComboboxKip()
        // Tự động cập nhật lại số nhân viên đi làm dựa trên số người nghỉ ở tab Lịch làm việc của ngày đang chọn
        capNhatNhanVienDiLamTuLich()
        dongBoThongSoVaoVanBan()
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
        nganChinh.spacing = 10
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 10),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -24),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 12),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -12)
        ])

        let chamNgoai = UITapGestureRecognizer(target: self, action: #selector(anBanPhim))
        chamNgoai.cancelsTouchesInView = false
        view.addGestureRecognizer(chamNgoai)

        // 1. Thẻ thông số đầu vào phân bố đều, cân đối thẩm mỹ
        let theThongSo = taoKhungThe()
        let nganThongSo = UIStackView()
        nganThongSo.axis = .vertical
        nganThongSo.spacing = 10
        nganThongSo.translatesAutoresizingMaskIntoConstraints = false
        theThongSo.addSubview(nganThongSo)

        NSLayoutConstraint.activate([
            nganThongSo.topAnchor.constraint(equalTo: theThongSo.topAnchor, constant: 12),
            nganThongSo.bottomAnchor.constraint(equalTo: theThongSo.bottomAnchor, constant: -12),
            nganThongSo.leadingAnchor.constraint(equalTo: theThongSo.leadingAnchor, constant: 14),
            nganThongSo.trailingAnchor.constraint(equalTo: theThongSo.trailingAnchor, constant: -14)
        ])

        // Hàng 1: Kíp và Ngày nằm cùng 1 hàng, phân bố cân xứng 2 bên, không bị khoảng trống lệch
        let lbKip = taoNhanTieuDe("Kíp:")
        lbKip.setContentHuggingPriority(.required, for: .horizontal)

        nutComboboxKip.showsMenuAsPrimaryAction = true
        nutComboboxKip.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        nutComboboxKip.layer.cornerRadius = 8
        nutComboboxKip.layer.borderWidth = 1
        nutComboboxKip.widthAnchor.constraint(equalToConstant: 82).isActive = true
        nutComboboxKip.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let nhomKip = UIStackView(arrangedSubviews: [lbKip, nutComboboxKip])
        nhomKip.axis = .horizontal
        nhomKip.spacing = 8
        nhomKip.alignment = .center

        let lbNgay = taoNhanTieuDe("Ngày:")
        lbNgay.setContentHuggingPriority(.required, for: .horizontal)

        // Khung hiển thị ngày đồng bộ kích thước & kiểu dáng với ô Kíp và ô Nhân sự
        let khungNgay = UIView()
        khungNgay.translatesAutoresizingMaskIntoConstraints = false
        khungNgay.widthAnchor.constraint(equalToConstant: 118).isActive = true
        khungNgay.heightAnchor.constraint(equalToConstant: 36).isActive = true

        nhanHienThiNgay.font = .systemFont(ofSize: 15, weight: .bold)
        nhanHienThiNgay.textAlignment = .center
        nhanHienThiNgay.layer.cornerRadius = 8
        nhanHienThiNgay.layer.borderWidth = 1
        nhanHienThiNgay.layer.masksToBounds = true
        nhanHienThiNgay.translatesAutoresizingMaskIntoConstraints = false
        khungNgay.addSubview(nhanHienThiNgay)

        chonNgay.datePickerMode = .date
        chonNgay.preferredDatePickerStyle = .compact
        chonNgay.locale = Locale(identifier: "vi_VN")
        chonNgay.calendar = TienIchLich.lich
        chonNgay.date = Date()
        chonNgay.alpha = 0.02
        chonNgay.translatesAutoresizingMaskIntoConstraints = false
        chonNgay.addTarget(self, action: #selector(khiDoiNgay(_:)), for: .valueChanged)
        khungNgay.addSubview(chonNgay)

        NSLayoutConstraint.activate([
            nhanHienThiNgay.topAnchor.constraint(equalTo: khungNgay.topAnchor),
            nhanHienThiNgay.bottomAnchor.constraint(equalTo: khungNgay.bottomAnchor),
            nhanHienThiNgay.leadingAnchor.constraint(equalTo: khungNgay.leadingAnchor),
            nhanHienThiNgay.trailingAnchor.constraint(equalTo: khungNgay.trailingAnchor),

            chonNgay.centerXAnchor.constraint(equalTo: khungNgay.centerXAnchor),
            chonNgay.centerYAnchor.constraint(equalTo: khungNgay.centerYAnchor),
            chonNgay.widthAnchor.constraint(equalTo: khungNgay.widthAnchor),
            chonNgay.heightAnchor.constraint(equalTo: khungNgay.heightAnchor)
        ])

        let nhomNgay = UIStackView(arrangedSubviews: [lbNgay, khungNgay])
        nhomNgay.axis = .horizontal
        nhomNgay.spacing = 8
        nhomNgay.alignment = .center

        let hangKipVaNgay = UIStackView(arrangedSubviews: [nhomKip, nhomNgay])
        hangKipVaNgay.axis = .horizontal
        hangKipVaNgay.distribution = .equalSpacing
        hangKipVaNgay.alignment = .center

        // Hàng 2: Nhân sự (tự động trừ số người nghỉ ở tab Lịch làm việc)
        let lbNhanSu = taoNhanTieuDe("Nhân sự:")
        lbNhanSu.setContentHuggingPriority(.required, for: .horizontal)

        cauHinhOTextNhanSu(oNhanVienDiLam, placeholder: "9", action: #selector(khiDoiNhanVienDiLam))
        cauHinhOTextNhanSu(oTongSoNhanVien, placeholder: "9", action: #selector(khiDoiTongSoNhanVien))

        let lbGachCheo = UILabel()
        lbGachCheo.text = "/"
        lbGachCheo.font = .systemFont(ofSize: 17, weight: .bold)
        lbGachCheo.textAlignment = .center
        lbGachCheo.setContentHuggingPriority(.required, for: .horizontal)

        let lbDonViNV = UILabel()
        lbDonViNV.text = "nhân viên"
        lbDonViNV.font = .systemFont(ofSize: 14, weight: .medium)
        lbDonViNV.setContentHuggingPriority(.required, for: .horizontal)

        let nhomONhanSu = UIStackView(arrangedSubviews: [oNhanVienDiLam, lbGachCheo, oTongSoNhanVien, lbDonViNV])
        nhomONhanSu.axis = .horizontal
        nhomONhanSu.spacing = 8
        nhomONhanSu.alignment = .center

        oNhanVienDiLam.widthAnchor.constraint(equalToConstant: 62).isActive = true
        oTongSoNhanVien.widthAnchor.constraint(equalToConstant: 62).isActive = true

        let hangNhanSu = UIStackView(arrangedSubviews: [lbNhanSu, nhomONhanSu])
        hangNhanSu.axis = .horizontal
        hangNhanSu.distribution = .equalSpacing
        hangNhanSu.alignment = .center

        nganThongSo.addArrangedSubview(hangKipVaNgay)
        nganThongSo.addArrangedSubview(taoVachNgan())
        nganThongSo.addArrangedSubview(hangNhanSu)

        nganChinh.addArrangedSubview(theThongSo)

        // 2. Thẻ Kết quả bản text báo cáo TBM
        let theKetQua = taoKhungThe()
        let nganKetQua = UIStackView()
        nganKetQua.axis = .vertical
        nganKetQua.spacing = 10
        nganKetQua.translatesAutoresizingMaskIntoConstraints = false
        theKetQua.addSubview(nganKetQua)

        NSLayoutConstraint.activate([
            nganKetQua.topAnchor.constraint(equalTo: theKetQua.topAnchor, constant: 10),
            nganKetQua.bottomAnchor.constraint(equalTo: theKetQua.bottomAnchor, constant: -10),
            nganKetQua.leadingAnchor.constraint(equalTo: theKetQua.leadingAnchor, constant: 12),
            nganKetQua.trailingAnchor.constraint(equalTo: theKetQua.trailingAnchor, constant: -12)
        ])

        let lbTieuDeKetQua = UILabel()
        lbTieuDeKetQua.text = "📝 NỘI DUNG BÁO CÁO"
        lbTieuDeKetQua.font = .systemFont(ofSize: 12, weight: .bold)

        nhanTrangThaiLuu.text = "✓ Đã lưu"
        nhanTrangThaiLuu.font = .systemFont(ofSize: 12, weight: .semibold)
        nhanTrangThaiLuu.textAlignment = .right
        nhanTrangThaiLuu.setContentCompressionResistancePriority(.required, for: .horizontal)

        let hangTieuDeKetQua = UIStackView(arrangedSubviews: [lbTieuDeKetQua, nhanTrangThaiLuu])
        hangTieuDeKetQua.axis = .horizontal
        hangTieuDeKetQua.distribution = .equalSpacing
        hangTieuDeKetQua.alignment = .center

        oVanBanBaoCao.font = .systemFont(ofSize: 15, weight: .regular)
        oVanBanBaoCao.layer.cornerRadius = 10
        oVanBanBaoCao.layer.borderWidth = 1
        oVanBanBaoCao.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        oVanBanBaoCao.isScrollEnabled = false
        oVanBanBaoCao.delegate = self
        oVanBanBaoCao.inputAccessoryView = taoThanhCongCuBanPhim()
        oVanBanBaoCao.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        // Hàng nút thao tác nhanh
        nutSaoChep.setTitle("📋 Sao chép nội dung", for: .normal)
        nutSaoChep.setTitleColor(.white, for: .normal)
        nutSaoChep.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        nutSaoChep.titleLabel?.numberOfLines = 1
        nutSaoChep.layer.cornerRadius = 10
        nutSaoChep.heightAnchor.constraint(equalToConstant: 40).isActive = true
        nutSaoChep.addTarget(self, action: #selector(bamSaoChep), for: .touchUpInside)

        nutKhoiPhucMau.setTitle("🔄 Mẫu gốc", for: .normal)
        nutKhoiPhucMau.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
        nutKhoiPhucMau.titleLabel?.numberOfLines = 1
        nutKhoiPhucMau.layer.cornerRadius = 10
        nutKhoiPhucMau.heightAnchor.constraint(equalToConstant: 40).isActive = true
        nutKhoiPhucMau.widthAnchor.constraint(equalToConstant: 112).isActive = true
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

    private func cauHinhOTextNhanSu(_ tf: UITextField, placeholder: String, action: Selector) {
        tf.borderStyle = .none
        tf.font = .systemFont(ofSize: 15, weight: .bold)
        tf.textAlignment = .center
        tf.placeholder = placeholder
        tf.keyboardType = .numberPad
        tf.layer.cornerRadius = 8
        tf.layer.borderWidth = 1
        tf.delegate = self
        tf.inputAccessoryView = taoThanhCongCuBanPhim()
        tf.heightAnchor.constraint(equalToConstant: 36).isActive = true
        tf.addTarget(self, action: action, for: .editingChanged)
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

    private func capNhatNhanNgay() {
        nhanHienThiNgay.text = TienIchLich.dinhDangNgayViet.string(from: ngayHienTai)
    }

    /// Tự động tính số nhân viên đi làm = Tổng số nhân viên - Số người nghỉ trong tab Lịch làm việc của ngày đang chọn
    private func capNhatNhanVienDiLamTuLich() {
        let chuoiTong = oTongSoNhanVien.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tongSo = Int(chuoiTong) ?? 9
        let soNguoiNghi = TienIchLich.demSoNguoiNghiTrongLich(cho: ngayHienTai)
        let diLam = max(0, tongSo - soNguoiNghi)
        oNhanVienDiLam.text = "\(diLam)"
    }

    private func napDuLieuBanDau() {
        let duLieu = KhoDuLieu.dungChung.duLieuBaoCao
        let homNay = Date()
        ngayHienTai = homNay
        chonNgay.date = homNay
        capNhatNhanNgay()

        let tongSo = duLieu.tongSoNhanVien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "9" : duLieu.tongSoNhanVien
        oTongSoNhanVien.text = tongSo
        capNhatNhanVienDiLamTuLich()
        let diLam = oNhanVienDiLam.text ?? "9"

        let khoaHomNay = TienIchLich.dinhDangKhoaNgay.string(from: homNay)
        let goiYLich = TienIchLich.xacDinhKipTheoLich(cho: homNay)

        if duLieu.khoaNgayLuu == khoaHomNay, (duLieu.kip == "1A" || duLieu.kip == "2A") {
            kipHienTai = duLieu.kip
        } else {
            kipHienTai = goiYLich.kip
        }

        capNhatMenuComboboxKip()

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
        oTongSoNhanVien.text = duLieu.tongSoNhanVien.isEmpty ? "9" : duLieu.tongSoNhanVien
        capNhatNhanVienDiLamTuLich()
        if duLieu.kip == "1A" || duLieu.kip == "2A" {
            kipHienTai = duLieu.kip
        }
        if !duLieu.noiDungMau.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            oVanBanBaoCao.text = duLieu.noiDungMau
        }
        dongBoThongSoVaoVanBan()
        capNhatMenuComboboxKip()
        capNhatMauGiaoDien()
    }

    private func capNhatThongTinTheoLich(tuDongDoiKip: Bool) {
        let thongTin = TienIchLich.xacDinhKipTheoLich(cho: ngayHienTai)
        if tuDongDoiKip {
            kipHienTai = thongTin.kip
        }
        capNhatMenuComboboxKip()
    }

    private func capNhatMenuComboboxKip() {
        let mau = KhoDuLieu.dungChung.mauSac

        let hanhDong1A = UIAction(
            title: "1A",
            state: (kipHienTai == "1A") ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.kipHienTai = "1A"
            self.capNhatMenuComboboxKip()
            self.dongBoThongSoVaoVanBan()
        }

        let hanhDong2A = UIAction(
            title: "2A",
            state: (kipHienTai == "2A") ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.kipHienTai = "2A"
            self.capNhatMenuComboboxKip()
            self.dongBoThongSoVaoVanBan()
        }

        nutComboboxKip.menu = UIMenu(children: [hanhDong1A, hanhDong2A])
        nutComboboxKip.setTitle("\(kipHienTai) ▾", for: .normal)
        nutComboboxKip.setTitleColor(mau.text, for: .normal)
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
        nhanTrangThaiLuu.text = "✓ Đã lưu"
    }

    // MARK: - Sự kiện người dùng

    @objc private func khiDoiNgay(_ sender: UIDatePicker) {
        ngayHienTai = sender.date
        capNhatNhanNgay()
        capNhatThongTinTheoLich(tuDongDoiKip: true)
        capNhatNhanVienDiLamTuLich()
        dongBoThongSoVaoVanBan()
        if let presented = presentedViewController {
            presented.dismiss(animated: true)
        }
    }

    @objc private func khiDoiNhanVienDiLam() {
        dongBoThongSoVaoVanBan()
    }

    @objc private func khiDoiTongSoNhanVien() {
        capNhatNhanVienDiLamTuLich()
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
            message: "Đặt lại tổng nhân sự 9 người (trừ số người nghỉ trên lịch), ngày hiện tại và khôi phục văn bản về mẫu TBM mặc định?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Khôi phục", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.ngayHienTai = Date()
            self.chonNgay.date = self.ngayHienTai
            self.capNhatNhanNgay()
            self.oTongSoNhanVien.text = "9"
            self.capNhatNhanVienDiLamTuLich()
            self.capNhatThongTinTheoLich(tuDongDoiKip: true)
            let diLam = self.oNhanVienDiLam.text ?? "9"
            self.oVanBanBaoCao.text = DuLieuBaoCaoTBM.taoVanBanMacDinh(
                kip: self.kipHienTai,
                ngay: self.ngayHienTai,
                diLam: diLam,
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

        nhanHienThiNgay.backgroundColor = mau.iconBg
        nhanHienThiNgay.textColor = mau.text
        nhanHienThiNgay.layer.borderColor = mau.border.cgColor

        oNhanVienDiLam.backgroundColor = mau.iconBg
        oNhanVienDiLam.textColor = mau.text
        oNhanVienDiLam.layer.borderColor = mau.border.cgColor

        oTongSoNhanVien.backgroundColor = mau.iconBg
        oTongSoNhanVien.textColor = mau.text
        oTongSoNhanVien.layer.borderColor = mau.border.cgColor

        oVanBanBaoCao.backgroundColor = mau.iconBg
        oVanBanBaoCao.textColor = mau.text
        oVanBanBaoCao.layer.borderColor = mau.border.cgColor

        nutSaoChep.backgroundColor = mau.primary
        nutSaoChep.setTitleColor(.white, for: .normal)

        nutKhoiPhucMau.backgroundColor = mau.primary.withAlphaComponent(0.14)
        nutKhoiPhucMau.setTitleColor(mau.primary, for: .normal)

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
