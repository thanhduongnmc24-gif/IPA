import UIKit
import SafariServices

final class ManHinhGhiChu: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let thanhTimKiem = UISearchBar()
    private let bang = UITableView(frame: .zero, style: .plain)
    private var tuKhoaTim: String = ""

    private var danhSachLoc: [GhiChuNhanh] {
        let tatCa = KhoDuLieu.dungChung.ghiChuNhanh
        let tk = tuKhoaTim.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tk.isEmpty else { return tatCa }
        return tatCa.filter {
            $0.title.lowercased().contains(tk) || $0.content.lowercased().contains(tk)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Ghi Chú"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(themMoi)
        )

        thanhTimKiem.placeholder = "Tìm tiêu đề hoặc nội dung..."
        thanhTimKiem.delegate = self
        thanhTimKiem.searchBarStyle = .minimal
        thanhTimKiem.translatesAutoresizingMaskIntoConstraints = false

        bang.dataSource = self
        bang.delegate = self
        bang.separatorStyle = .none
        bang.backgroundColor = .clear
        bang.keyboardDismissMode = .onDrag
        bang.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(thanhTimKiem)
        view.addSubview(bang)

        NSLayoutConstraint.activate([
            thanhTimKiem.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            thanhTimKiem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            thanhTimKiem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            bang.topAnchor.constraint(equalTo: thanhTimKiem.bottomAnchor, constant: 4),
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
        moTrinhSua(ghiChu: nil)
    }

    private func moTrinhSua(ghiChu: GhiChuNhanh?) {
        let vc = ManHinhSoanGhiChuNhanh(ghiChu: ghiChu) { [weak self] in
            self?.bang.reloadData()
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        tuKhoaTim = searchText
        bang.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        danhSachLoc.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let ma = "OGhiChuNhanh"
        let cell = tableView.dequeueReusableCell(withIdentifier: ma) ?? UITableViewCell(style: .default, reuseIdentifier: ma)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let item = danhSachLoc[indexPath.row]
        let mau = KhoDuLieu.dungChung.mauSac
        let laLink = item.title.lowercased().hasPrefix("http")

        let the = UIView()
        the.backgroundColor = item.isPinned ? mau.primary.withAlphaComponent(0.12) : mau.card
        the.layer.cornerRadius = 12
        the.layer.borderWidth = 1
        the.layer.borderColor = (item.isPinned ? mau.primary : mau.border).cgColor
        the.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(the)

        let nutTieuDe = UIButton(type: .system)
        let chuTieuDe = item.title.isEmpty ? "(Không tiêu đề)" : (laLink ? "\(item.title) 🔗" : item.title)
        nutTieuDe.setTitle(chuTieuDe, for: .normal)
        nutTieuDe.setTitleColor(laLink ? mau.primary : mau.text, for: .normal)
        nutTieuDe.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        nutTieuDe.contentHorizontalAlignment = .left
        nutTieuDe.addAction(UIAction { [weak self] _ in
            if laLink, let url = URL(string: item.title.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let safari = SFSafariViewController(url: url)
                self?.present(safari, animated: true)
            } else {
                self?.moTrinhSua(ghiChu: item)
            }
        }, for: .touchUpInside)

        let lbNgay = UILabel()
        lbNgay.text = item.date
        lbNgay.font = .systemFont(ofSize: 11)
        lbNgay.textColor = mau.subText

        let nutGhim = UIButton(type: .system)
        nutGhim.setImage(UIImage(systemName: item.isPinned ? "pin.fill" : "pin"), for: .normal)
        nutGhim.tintColor = item.isPinned ? mau.primary : mau.subText
        nutGhim.widthAnchor.constraint(equalToConstant: 30).isActive = true
        nutGhim.addAction(UIAction { [weak self] _ in
            self?.daoGhim(id: item.id)
        }, for: .touchUpInside)

        let hangTren = UIStackView(arrangedSubviews: [nutTieuDe, lbNgay, nutGhim])
        hangTren.axis = .horizontal
        hangTren.spacing = 8
        hangTren.alignment = .center

        let vach = UIView()
        vach.backgroundColor = mau.border
        vach.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let lbNoiDung = UILabel()
        lbNoiDung.text = item.content.isEmpty ? "Chạm vào đây để viết nội dung..." : item.content
        lbNoiDung.font = .systemFont(ofSize: 14)
        lbNoiDung.textColor = mau.subText
        lbNoiDung.numberOfLines = 3

        let ngan = UIStackView(arrangedSubviews: [hangTren, vach, lbNoiDung])
        ngan.axis = .vertical
        ngan.spacing = 8
        ngan.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(ngan)

        NSLayoutConstraint.activate([
            the.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
            the.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
            the.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            the.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),

            ngan.topAnchor.constraint(equalTo: the.topAnchor, constant: 12),
            ngan.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -12),
            ngan.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            ngan.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        moTrinhSua(ghiChu: danhSachLoc[indexPath.row])
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let item = danhSachLoc[indexPath.row]
        let xoa = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            var ds = KhoDuLieu.dungChung.ghiChuNhanh
            ds.removeAll { $0.id == item.id }
            KhoDuLieu.dungChung.luuGhiChuNhanh(ds)
            self?.bang.reloadData()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [xoa])
    }

    private func daoGhim(id: String) {
        var ds = KhoDuLieu.dungChung.ghiChuNhanh
        if let idx = ds.firstIndex(where: { $0.id == id }) {
            ds[idx].isPinned.toggle()
            KhoDuLieu.dungChung.luuGhiChuNhanh(ds)
            bang.reloadData()
        }
    }
}

final class ManHinhSoanGhiChuNhanh: UIViewController {
    private let ghiChuCu: GhiChuNhanh?
    private let khiLuu: () -> Void
    private let oTieuDe = UITextField()
    private let oNoiDung = UITextView()

    init(ghiChu: GhiChuNhanh?, khiLuu: @escaping () -> Void) {
        self.ghiChuCu = ghiChu
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
        navigationItem.title = ghiChuCu == nil ? "Ghi chú mới" : "Sửa ghi chú"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dong))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu lại", style: .done, target: self, action: #selector(luu))

        oTieuDe.borderStyle = .roundedRect
        oTieuDe.backgroundColor = mau.iconBg
        oTieuDe.textColor = mau.text
        oTieuDe.placeholder = "http://... hoặc Tiêu đề"
        oTieuDe.text = ghiChuCu?.title ?? ""

        oNoiDung.backgroundColor = mau.iconBg
        oNoiDung.textColor = mau.text
        oNoiDung.font = .systemFont(ofSize: 15)
        oNoiDung.layer.cornerRadius = 10
        oNoiDung.layer.borderWidth = 1
        oNoiDung.layer.borderColor = mau.border.cgColor
        oNoiDung.text = ghiChuCu?.content ?? ""
        oNoiDung.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let ngan = UIStackView(arrangedSubviews: [oTieuDe, oNoiDung])
        ngan.axis = .vertical
        ngan.spacing = 12
        ngan.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ngan)

        NSLayoutConstraint.activate([
            ngan.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            ngan.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ngan.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    @objc private func dong() {
        dismiss(animated: true)
    }

    @objc private func luu() {
        let t = oTieuDe.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = oNoiDung.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty || !c.isEmpty else {
            dismiss(animated: true)
            return
        }

        var ds = KhoDuLieu.dungChung.ghiChuNhanh
        if let cu = ghiChuCu, let idx = ds.firstIndex(where: { $0.id == cu.id }) {
            ds[idx].title = t
            ds[idx].content = c
        } else {
            let moi = GhiChuNhanh(
                title: t,
                content: c,
                date: TienIchLich.dinhDangNgayViet.string(from: Date()),
                isPinned: false
            )
            ds.insert(moi, at: 0)
        }
        KhoDuLieu.dungChung.luuGhiChuNhanh(ds)
        dismiss(animated: true, completion: khiLuu)
    }
}
