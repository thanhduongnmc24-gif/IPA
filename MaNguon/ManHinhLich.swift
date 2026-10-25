import UIKit

final class OLichNgay: UICollectionViewCell {
    static let ma = "OLichNgay"

    private let nhanDuong = UILabel()
    private let nhanAm = UILabel()
    private let nhanDong1 = UILabel()
    private let nhanDong2 = UILabel()
    private let nhanDong3 = UILabel()
    private let bieuTuongCa = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true

        nhanDuong.font = .systemFont(ofSize: 14, weight: .bold)
        nhanAm.font = .systemFont(ofSize: 9, weight: .regular)
        nhanAm.textAlignment = .right

        [nhanDong1, nhanDong2, nhanDong3].forEach {
            $0.font = .systemFont(ofSize: 8.5, weight: .medium)
            $0.numberOfLines = 1
        }

        bieuTuongCa.contentMode = .scaleAspectFit
        bieuTuongCa.translatesAutoresizingMaskIntoConstraints = false

        let hangTren = UIStackView(arrangedSubviews: [nhanDuong, nhanAm])
        hangTren.axis = .horizontal
        hangTren.distribution = .equalSpacing

        let danhSachDong = UIStackView(arrangedSubviews: [nhanDong1, nhanDong2, nhanDong3])
        danhSachDong.axis = .vertical
        danhSachDong.spacing = 1

        [hangTren, danhSachDong, bieuTuongCa].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            hangTren.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            hangTren.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            hangTren.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),

            danhSachDong.topAnchor.constraint(equalTo: hangTren.bottomAnchor, constant: 3),
            danhSachDong.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            danhSachDong.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),

            bieuTuongCa.widthAnchor.constraint(equalToConstant: 12),
            bieuTuongCa.heightAnchor.constraint(equalToConstant: 12),
            bieuTuongCa.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            bieuTuongCa.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Khong ho tro coder")
    }

    func cauHinh(ngay: Date, cungThang: Bool, ghiChu: GhiChuNgay?, caTuDong: String?) {
        let mau = KhoDuLieu.dungChung.mauSac
        let lich = TienIchLich.lich
        let homNay = lich.isDateInToday(ngay)

        nhanDuong.text = "\(lich.component(.day, from: ngay))"
        nhanDuong.textColor = cungThang ? mau.text : mau.subText.withAlphaComponent(0.45)

        let am = TienIchLich.thongTinAmLich(ngay)
        nhanAm.text = am.chuoi
        nhanAm.textColor = am.laMungMot ? mau.error : mau.subText
        nhanAm.font = .systemFont(ofSize: 9, weight: am.laMungMot ? .bold : .regular)

        let cacDong = ghiChu?.noteLines ?? []
        let nhanDongs = [nhanDong1, nhanDong2, nhanDong3]
        for i in 0..<3 {
            if i < cacDong.count {
                nhanDongs[i].text = (i == 2 && cacDong.count > 3) ? "\(cacDong[i])..." : cacDong[i]
                nhanDongs[i].textColor = mau.text
            } else {
                nhanDongs[i].text = ""
            }
        }

        let loaiCa = (ghiChu?.type.isEmpty == false) ? ghiChu!.type : (caTuDong ?? "")
        switch loaiCa {
        case "ngay":
            bieuTuongCa.image = UIImage(systemName: "sun.max.fill")
            bieuTuongCa.tintColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        case "dem":
            bieuTuongCa.image = UIImage(systemName: "moon.stars.fill")
            bieuTuongCa.tintColor = UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)
        case "nghi":
            bieuTuongCa.image = UIImage(systemName: "cup.and.saucer.fill")
            bieuTuongCa.tintColor = mau.success
        default:
            bieuTuongCa.image = nil
        }

        if homNay {
            contentView.backgroundColor = KhoDuLieu.dungChung.caiDat.giaoDienToi
                ? UIColor(red: 0.99, green: 0.94, blue: 0.54, alpha: 0.14)
                : UIColor(red: 0.99, green: 0.98, blue: 0.76, alpha: 1)
            contentView.layer.borderColor = UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1).cgColor
            contentView.layer.borderWidth = 1.8
        } else if loaiCa == "nghi" {
            contentView.backgroundColor = mau.iconBg.withAlphaComponent(0.6)
            contentView.layer.borderColor = mau.border.cgColor
            contentView.layer.borderWidth = 0.7
        } else {
            contentView.backgroundColor = mau.card
            contentView.layer.borderColor = mau.border.cgColor
            contentView.layer.borderWidth = 0.7
        }
    }
}

final class ManHinhLich: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var thangHienTai = TienIchLich.dauThang(Date())
    private var cacNgayLuoi: [Date] = []

    private let cuon = UIScrollView()
    private let noiDung = UIStackView()
    private let tieuDeThang = UILabel()
    private let chonKieuTongHop = UISegmentedControl(items: ["Theo Ngày", "Theo Tên"])
    private let danhSachTongHop = UIStackView()
    private var rangBuocCaoLuoi: NSLayoutConstraint!

    private lazy var luoiLich: UICollectionView = {
        let boCuc = UICollectionViewFlowLayout()
        boCuc.minimumLineSpacing = 5
        boCuc.minimumInteritemSpacing = 4
        let cv = UICollectionView(frame: .zero, collectionViewLayout: boCuc)
        cv.dataSource = self
        cv.delegate = self
        cv.register(OLichNgay.self, forCellWithReuseIdentifier: OLichNgay.ma)
        cv.isScrollEnabled = false
        cv.backgroundColor = .clear
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        taoGiaoDien()
        napDuLieu()

        NotificationCenter.default.addObserver(self, selector: #selector(napDuLieu), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(napDuLieu), name: .duLieuDongBoXong, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        napDuLieu()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func taoGiaoDien() {
        cuon.alwaysBounceVertical = true
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        noiDung.axis = .vertical
        noiDung.spacing = 12
        noiDung.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(noiDung)

        // Thanh điều hướng tháng
        let nutTruoc = UIButton(type: .system)
        nutTruoc.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nutTruoc.addTarget(self, action: #selector(thangTruoc), for: .touchUpInside)

        let nutSau = UIButton(type: .system)
        nutSau.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nutSau.addTarget(self, action: #selector(thangSau), for: .touchUpInside)

        tieuDeThang.font = .systemFont(ofSize: 20, weight: .bold)
        tieuDeThang.textAlignment = .center

        let hangThang = UIStackView(arrangedSubviews: [nutTruoc, tieuDeThang, nutSau])
        hangThang.distribution = .equalCentering

        // Hàng tiêu đề thứ (T2 -> CN)
        let hangThu = UIStackView()
        hangThu.distribution = .fillEqually
        hangThu.spacing = 4
        ["T2", "T3", "T4", "T5", "T6", "T7", "CN"].forEach { thu in
            let nhan = UILabel()
            nhan.text = thu
            nhan.font = .systemFont(ofSize: 12, weight: .bold)
            nhan.textAlignment = .center
            nhan.layer.cornerRadius = 6
            nhan.layer.masksToBounds = true
            nhan.heightAnchor.constraint(equalToConstant: 28).isActive = true
            hangThu.addArrangedSubview(nhan)
        }

        rangBuocCaoLuoi = luoiLich.heightAnchor.constraint(equalToConstant: 460)
        rangBuocCaoLuoi.isActive = true

        // Thanh công cụ Tổng hợp ghi chú
        let tieuDeTongHop = UILabel()
        tieuDeTongHop.text = "Tổng Hợp Ghi Chú"
        tieuDeTongHop.font = .systemFont(ofSize: 17, weight: .bold)

        chonKieuTongHop.selectedSegmentIndex = 0
        chonKieuTongHop.addTarget(self, action: #selector(capNhatTongHop), for: .valueChanged)

        let hangCongCu = UIStackView(arrangedSubviews: [tieuDeTongHop, chonKieuTongHop])
        hangCongCu.alignment = .center
        hangCongCu.distribution = .equalSpacing

        danhSachTongHop.axis = .vertical
        danhSachTongHop.spacing = 8

        [hangThang, hangThu, luoiLich, hangCongCu, danhSachTongHop].forEach {
            noiDung.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            noiDung.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 8),
            noiDung.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -30),
            noiDung.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 10),
            noiDung.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -10)
        ])
    }

    @objc private func napDuLieu() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg
        tieuDeThang.textColor = mau.text

        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "'Tháng' MM yyyy"
        tieuDeThang.text = df.string(from: thangHienTai)

        if let hangThu = noiDung.arrangedSubviews.dropFirst(1).first as? UIStackView {
            for (idx, v) in hangThu.arrangedSubviews.enumerated() {
                guard let lb = v as? UILabel else { continue }
                let laCN = (idx == 6)
                lb.textColor = laCN ? mau.error : mau.primary
                lb.backgroundColor = (laCN ? mau.error : mau.primary).withAlphaComponent(0.12)
            }
        }

        cacNgayLuoi = TienIchLich.cacNgayTrongLuoiThang(thangHienTai)
        let soHang = max(1, cacNgayLuoi.count / 7)
        rangBuocCaoLuoi.constant = CGFloat(soHang * 78 + (soHang - 1) * 5)
        luoiLich.collectionViewLayout.invalidateLayout()
        luoiLich.reloadData()
        capNhatTongHop()
    }

    @objc private func thangTruoc() {
        thangHienTai = TienIchLich.lich.date(byAdding: .month, value: -1, to: thangHienTai) ?? thangHienTai
        napDuLieu()
    }

    @objc private func thangSau() {
        thangHienTai = TienIchLich.lich.date(byAdding: .month, value: 1, to: thangHienTai) ?? thangHienTai
        napDuLieu()
    }

    @objc private func capNhatTongHop() {
        let mau = KhoDuLieu.dungChung.mauSac
        danhSachTongHop.arrangedSubviews.forEach {
            danhSachTongHop.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let lich = TienIchLich.lich
        let dThang = TienIchLich.dauThang(thangHienTai)
        guard let phamVi = lich.range(of: .day, in: .month, for: dThang) else { return }

        var danhSachTheoNgay: [(ngay: Date, dong: [String])] = []
        for offset in 0..<phamVi.count {
            guard let ngay = lich.date(byAdding: .day, value: offset, to: dThang) else { continue }
            let khoa = TienIchLich.dinhDangKhoaNgay.string(from: ngay)
            if let gc = KhoDuLieu.dungChung.ghiChuLich[khoa], !gc.noteLines.isEmpty {
                danhSachTheoNgay.append((ngay, gc.noteLines))
            }
        }

        if chonKieuTongHop.selectedSegmentIndex == 0 {
            if danhSachTheoNgay.isEmpty {
                themNhanTrong("Tháng này trống.")
                return
            }
            let dfThu = DateFormatter()
            dfThu.locale = Locale(identifier: "vi_VN")
            dfThu.dateFormat = "EEE"

            for muc in danhSachTheoNgay {
                let the = UIView()
                the.backgroundColor = mau.card
                the.layer.cornerRadius = 14
                the.layer.borderWidth = 1
                the.layer.borderColor = mau.border.cgColor

                let huyHieu = UIView()
                huyHieu.backgroundColor = mau.iconBg
                huyHieu.layer.cornerRadius = 10
                huyHieu.translatesAutoresizingMaskIntoConstraints = false

                let lbNgay = UILabel()
                lbNgay.text = String(format: "%02d", lich.component(.day, from: muc.ngay))
                lbNgay.font = .systemFont(ofSize: 15, weight: .bold)
                lbNgay.textColor = mau.primary
                lbNgay.textAlignment = .center

                let lbThu = UILabel()
                lbThu.text = dfThu.string(from: muc.ngay)
                lbThu.font = .systemFont(ofSize: 10)
                lbThu.textColor = mau.subText
                lbThu.textAlignment = .center

                let cotNgay = UIStackView(arrangedSubviews: [lbNgay, lbThu])
                cotNgay.axis = .vertical
                cotNgay.translatesAutoresizingMaskIntoConstraints = false
                huyHieu.addSubview(cotNgay)

                let lbNoiDung = UILabel()
                lbNoiDung.numberOfLines = 0
                lbNoiDung.font = .systemFont(ofSize: 14)
                lbNoiDung.textColor = mau.text
                lbNoiDung.text = muc.dong.map { "• \($0)" }.joined(separator: "\n")
                lbNoiDung.translatesAutoresizingMaskIntoConstraints = false

                the.addSubview(huyHieu)
                the.addSubview(lbNoiDung)

                NSLayoutConstraint.activate([
                    huyHieu.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 10),
                    huyHieu.centerYAnchor.constraint(equalTo: the.centerYAnchor),
                    huyHieu.widthAnchor.constraint(equalToConstant: 44),
                    huyHieu.heightAnchor.constraint(equalToConstant: 44),
                    cotNgay.centerXAnchor.constraint(equalTo: huyHieu.centerXAnchor),
                    cotNgay.centerYAnchor.constraint(equalTo: huyHieu.centerYAnchor),

                    lbNoiDung.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
                    lbNoiDung.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
                    lbNoiDung.leadingAnchor.constraint(equalTo: huyHieu.trailingAnchor, constant: 12),
                    lbNoiDung.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -10),
                    the.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
                ])
                danhSachTongHop.addArrangedSubview(the)
            }
        } else {
            var gomNhom: [String: [String]] = [:]
            var thuTuKhoa: [String] = []
            for muc in danhSachTheoNgay {
                let chuoiNgay = "\(lich.component(.day, from: muc.ngay))"
                for dong in muc.dong {
                    let cacPhan = dong.components(separatedBy: CharacterSet(charactersIn: ",;"))
                    for phan in cacPhan {
                        let ten = phan.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !ten.isEmpty else { continue }
                        if gomNhom[ten] == nil {
                            gomNhom[ten] = []
                            thuTuKhoa.append(ten)
                        }
                        if !(gomNhom[ten]!.contains(chuoiNgay)) {
                            gomNhom[ten]!.append(chuoiNgay)
                        }
                    }
                }
            }

            if thuTuKhoa.isEmpty {
                themNhanTrong("Không có dữ liệu.")
                return
            }

            for ten in thuTuKhoa {
                let cacNgay = gomNhom[ten]?.joined(separator: ", ") ?? ""
                let the = UIView()
                the.backgroundColor = mau.card
                the.layer.cornerRadius = 10
                the.layer.borderWidth = 1
                the.layer.borderColor = mau.border.cgColor

                let lb = UILabel()
                lb.numberOfLines = 0
                let attr = NSMutableAttributedString(
                    string: "\(ten): ",
                    attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: mau.primary]
                )
                attr.append(NSAttributedString(
                    string: cacNgay,
                    attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: mau.text]
                ))
                lb.attributedText = attr
                lb.translatesAutoresizingMaskIntoConstraints = false
                the.addSubview(lb)

                NSLayoutConstraint.activate([
                    lb.topAnchor.constraint(equalTo: the.topAnchor, constant: 10),
                    lb.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -10),
                    lb.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
                    lb.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
                ])
                danhSachTongHop.addArrangedSubview(the)
            }
        }
    }

    private func themNhanTrong(_ chu: String) {
        let lb = UILabel()
        lb.text = chu
        lb.font = .italicSystemFont(ofSize: 14)
        lb.textColor = KhoDuLieu.dungChung.mauSac.subText
        lb.textAlignment = .center
        lb.heightAnchor.constraint(equalToConstant: 44).isActive = true
        danhSachTongHop.addArrangedSubview(lb)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cacNgayLuoi.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let o = collectionView.dequeueReusableCell(withReuseIdentifier: OLichNgay.ma, for: indexPath) as! OLichNgay
        let ngay = cacNgayLuoi[indexPath.item]
        let cungThang = TienIchLich.lich.isDate(ngay, equalTo: thangHienTai, toGranularity: .month)
        let khoa = TienIchLich.dinhDangKhoaNgay.string(from: ngay)
        let ghiChu = KhoDuLieu.dungChung.ghiChuLich[khoa]
        let caTuDong = TienIchLich.tinhCaTuDong(cho: ngay)
        o.cauHinh(ngay: ngay, cungThang: cungThang, ghiChu: ghiChu, caTuDong: caTuDong)
        return o
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let ngay = cacNgayLuoi[indexPath.item]
        let modal = ManHinhChiTietNgayLich(ngay: ngay) { [weak self] in
            self?.napDuLieu()
        }
        let nav = UINavigationController(rootViewController: modal)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let rong = floor((collectionView.bounds.width - 24) / 7.0)
        return CGSize(width: max(38, rong), height: 78)
    }
}

final class ManHinhChiTietNgayLich: UIViewController {
    private let ngay: Date
    private let khiLuu: () -> Void
    private var loaiCa: String = ""
    private let chonCa = UISegmentedControl(items: ["Tự động", "Ca Ngày ☀️", "Ca Đêm 🌙", "Nghỉ ☕"])
    private let danhSachONhap = UIStackView()

    init(ngay: Date, khiLuu: @escaping () -> Void) {
        self.ngay = ngay
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
        navigationItem.title = TienIchLich.dinhDangNgayViet.string(from: ngay)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu Ghi Chú", style: .done, target: self, action: #selector(luu))

        let khoa = TienIchLich.dinhDangKhoaNgay.string(from: ngay)
        let hienCo = KhoDuLieu.dungChung.ghiChuLich[khoa]
        let caTuDong = TienIchLich.tinhCaTuDong(cho: ngay) ?? ""
        loaiCa = hienCo?.type ?? caTuDong

        switch loaiCa {
        case "ngay": chonCa.selectedSegmentIndex = 1
        case "dem": chonCa.selectedSegmentIndex = 2
        case "nghi": chonCa.selectedSegmentIndex = 3
        default: chonCa.selectedSegmentIndex = 0
        }

        let cuon = UIScrollView()
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        let noiDung = UIStackView()
        noiDung.axis = .vertical
        noiDung.spacing = 12
        noiDung.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(noiDung)

        danhSachONhap.axis = .vertical
        danhSachONhap.spacing = 8

        let cacDong = (hienCo?.noteLines.isEmpty == false) ? hienCo!.noteLines : [""]
        cacDong.forEach { themDongNhap($0) }

        let nutThemDong = UIButton(type: .system)
        var cauHinhThem = UIButton.Configuration.tinted()
        cauHinhThem.title = "Thêm dòng ghi chú"
        cauHinhThem.image = UIImage(systemName: "plus.circle")
        cauHinhThem.imagePadding = 6
        nutThemDong.configuration = cauHinhThem
        nutThemDong.addTarget(self, action: #selector(bamThemDong), for: .touchUpInside)

        [chonCa, danhSachONhap, nutThemDong].forEach { noiDung.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            noiDung.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 16),
            noiDung.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -24),
            noiDung.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            noiDung.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    private func themDongNhap(_ giaTri: String) {
        let mau = KhoDuLieu.dungChung.mauSac
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.backgroundColor = mau.iconBg
        tf.textColor = mau.text
        tf.placeholder = "Nhập ghi chú..."
        tf.text = giaTri

        let nutXoa = UIButton(type: .system)
        nutXoa.setImage(UIImage(systemName: "trash"), for: .normal)
        nutXoa.tintColor = mau.error
        nutXoa.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let hang = UIStackView(arrangedSubviews: [tf, nutXoa])
        hang.axis = .horizontal
        hang.spacing = 8

        nutXoa.addAction(UIAction { [weak self, weak hang] _ in
            guard let self, let hang else { return }
            self.danhSachONhap.removeArrangedSubview(hang)
            hang.removeFromSuperview()
        }, for: .touchUpInside)

        danhSachONhap.addArrangedSubview(hang)
    }

    @objc private func bamThemDong() {
        themDongNhap("")
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        view.endEditing(true)
        let cacDong: [String] = danhSachONhap.arrangedSubviews.compactMap { v in
            guard let hang = v as? UIStackView,
                  let tf = hang.arrangedSubviews.first as? UITextField else { return nil }
            let chu = tf.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return chu.isEmpty ? nil : chu
        }

        let caChon: String
        switch chonCa.selectedSegmentIndex {
        case 1: caChon = "ngay"
        case 2: caChon = "dem"
        case 3: caChon = "nghi"
        default: caChon = TienIchLich.tinhCaTuDong(cho: ngay) ?? ""
        }

        let khoa = TienIchLich.dinhDangKhoaNgay.string(from: ngay)
        var tatCa = KhoDuLieu.dungChung.ghiChuLich
        if cacDong.isEmpty && chonCa.selectedSegmentIndex == 0 {
            tatCa.removeValue(forKey: khoa)
        } else {
            tatCa[khoa] = GhiChuNgay(type: caChon, noteLines: cacDong)
        }
        KhoDuLieu.dungChung.luuGhiChuLich(tatCa)
        if !cacDong.isEmpty {
            TienIchLich.datThongBaoLich(ngay: ngay, dongGhiChu: cacDong, loaiCa: caChon)
        }
        dismiss(animated: true, completion: khiLuu)
    }
}
