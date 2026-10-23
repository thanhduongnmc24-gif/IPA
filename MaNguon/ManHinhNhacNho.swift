import UIKit
import AVFoundation

final class ManHinhNhacNho: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let bang = UITableView(frame: .zero, style: .plain)
    private let boDocGiongNoi = AVSpeechSynthesizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Nhắc Nhở"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(themMoi)
        )

        bang.dataSource = self
        bang.delegate = self
        bang.backgroundColor = .clear
        bang.separatorStyle = .singleLine
        bang.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bang)

        NSLayoutConstraint.activate([
            bang.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bang.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bang.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bang.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        capNhatGiaoDien()
        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .caiDatThayDoi, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(capNhatGiaoDien), name: .duLieuDongBoXong, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capNhatGiaoDien()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func capNhatGiaoDien() {
        view.backgroundColor = KhoDuLieu.dungChung.mauSac.bg
        bang.reloadData()
    }

    @objc private func themMoi() {
        moTrinhSua(suKien: nil)
    }

    private func moTrinhSua(suKien: SuKienNhacNho?) {
        let vc = ManHinhSoanNhacNho(suKien: suKien) { [weak self] in
            self?.bang.reloadData()
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func docBangGiongNoi(_ suKien: SuKienNhacNho) {
        boDocGiongNoi.stopSpeaking(at: .immediate)
        let vanBan = suKien.content.isEmpty ? suKien.title : "\(suKien.title). \(suKien.content)"
        let loiDoc = AVSpeechUtterance(string: vanBan)
        loiDoc.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        boDocGiongNoi.speak(loiDoc)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        KhoDuLieu.dungChung.nhacNho.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let ma = "ONhacNho"
        let cell = tableView.dequeueReusableCell(withIdentifier: ma) ?? UITableViewCell(style: .subtitle, reuseIdentifier: ma)
        let item = KhoDuLieu.dungChung.nhacNho[indexPath.row]
        let mau = KhoDuLieu.dungChung.mauSac

        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "HH:mm - dd/MM/yyyy"

        cell.backgroundColor = mau.card
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        cell.textLabel?.textColor = mau.text

        let phuDe = item.content.isEmpty ? "⏰ \(df.string(from: item.dateTime))" : "⏰ \(df.string(from: item.dateTime)) • \(item.content)"
        cell.detailTextLabel?.text = phuDe
        cell.detailTextLabel?.textColor = mau.subText
        cell.detailTextLabel?.numberOfLines = 2

        let nutLoa = UIButton(type: .system)
        nutLoa.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        nutLoa.tintColor = mau.primary
        nutLoa.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        nutLoa.addAction(UIAction { [weak self] _ in
            self?.docBangGiongNoi(item)
        }, for: .touchUpInside)
        cell.accessoryView = nutLoa

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        moTrinhSua(suKien: KhoDuLieu.dungChung.nhacNho[indexPath.row])
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let item = KhoDuLieu.dungChung.nhacNho[indexPath.row]
        let xoa = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            var ds = KhoDuLieu.dungChung.nhacNho
            ds.removeAll { $0.id == item.id }
            KhoDuLieu.dungChung.luuNhacNho(ds)
            self?.bang.reloadData()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [xoa])
    }
}

final class ManHinhSoanNhacNho: UIViewController {
    private let suKienCu: SuKienNhacNho?
    private let khiLuu: () -> Void
    private let oTieuDe = UITextField()
    private let oNoiDung = UITextView()
    private let chonThoiGian = UIDatePicker()

    init(suKien: SuKienNhacNho?, khiLuu: @escaping () -> Void) {
        self.suKienCu = suKien
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
        navigationItem.title = suKienCu == nil ? "Tạo nhắc nhở" : "Sửa nhắc nhở"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Hủy", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu & Hẹn giờ", style: .done, target: self, action: #selector(luu))

        oTieuDe.borderStyle = .roundedRect
        oTieuDe.placeholder = "VD: Kiểm tra lô cán thép..."
        oTieuDe.text = suKienCu?.title ?? ""

        oNoiDung.backgroundColor = mau.iconBg
        oNoiDung.textColor = mau.text
        oNoiDung.font = .systemFont(ofSize: 15)
        oNoiDung.layer.cornerRadius = 10
        oNoiDung.layer.borderWidth = 1
        oNoiDung.layer.borderColor = mau.border.cgColor
        oNoiDung.text = suKienCu?.content ?? ""
        oNoiDung.heightAnchor.constraint(equalToConstant: 100).isActive = true

        chonThoiGian.datePickerMode = .dateAndTime
        chonThoiGian.preferredDatePickerStyle = .inline
        chonThoiGian.locale = Locale(identifier: "vi_VN")
        chonThoiGian.date = suKienCu?.dateTime ?? Date()

        let cuon = UIScrollView()
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        let ngan = UIStackView(arrangedSubviews: [oTieuDe, oNoiDung, chonThoiGian])
        ngan.axis = .vertical
        ngan.spacing = 12
        ngan.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(ngan)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            ngan.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 16),
            ngan.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -24),
            ngan.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            ngan.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        let t = oTieuDe.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return }
        let c = oNoiDung.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var ds = KhoDuLieu.dungChung.nhacNho
        let suKienMoi: SuKienNhacNho
        if let cu = suKienCu, let idx = ds.firstIndex(where: { $0.id == cu.id }) {
            suKienMoi = SuKienNhacNho(id: cu.id, title: t, content: c, dateTime: chonThoiGian.date)
            ds[idx] = suKienMoi
        } else {
            suKienMoi = SuKienNhacNho(title: t, content: c, dateTime: chonThoiGian.date)
            ds.insert(suKienMoi, at: 0)
        }
        KhoDuLieu.dungChung.luuNhacNho(ds)
        TienIchLich.datThongBaoNhacNho(suKienMoi)
        dismiss(animated: true, completion: khiLuu)
    }
}
