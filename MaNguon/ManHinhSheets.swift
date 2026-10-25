import UIKit

final class ManHinhSheets: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var danhSachChu: [MucChuSheet] = [MucChuSheet()]
    private var danhSachAnh: [MucAnhSheet] = [MucAnhSheet()]
    private var hinhAnhTam: [String: UIImage] = [:]
    private var idAnhDangChon: String?
    private var dangGui = false

    private let cuon = UIScrollView()
    private let nganChinh = UIStackView()
    private let nganChu = UIStackView()
    private let nganAnh = UIStackView()
    private let nutGui = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Sheets"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(moCauHinhUrl)
        )

        taoGiaoDien()
        veDanhSach()

        NotificationCenter.default.addObserver(self, selector: #selector(veDanhSach), name: .caiDatThayDoi, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func taoGiaoDien() {
        cuon.keyboardDismissMode = .interactive
        cuon.alwaysBounceVertical = true
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganChinh.axis = .vertical
        nganChinh.spacing = 14
        nganChinh.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganChinh)

        var chGui = UIButton.Configuration.filled()
        chGui.title = "GỬI NGAY LÊN GOOGLE SHEETS"
        chGui.image = UIImage(systemName: "icloud.and.arrow.up.fill")
        chGui.imagePadding = 8
        chGui.cornerStyle = .medium
        nutGui.configuration = chGui
        nutGui.heightAnchor.constraint(equalToConstant: 46).isActive = true
        nutGui.addTarget(self, action: #selector(guiDuLieu), for: .touchUpInside)

        let lbChu = UILabel()
        lbChu.text = "📝 NỘI DUNG CHỮ"
        lbChu.font = .systemFont(ofSize: 14, weight: .bold)

        nganChu.axis = .vertical
        nganChu.spacing = 10

        let nutThemChu = UIButton(type: .system)
        var chThemChu = UIButton.Configuration.tinted()
        chThemChu.title = "＋ Thêm ô Text mới"
        nutThemChu.configuration = chThemChu
        nutThemChu.addTarget(self, action: #selector(themOChu), for: .touchUpInside)

        let lbAnh = UILabel()
        lbAnh.text = "📸 HÌNH ẢNH"
        lbAnh.font = .systemFont(ofSize: 14, weight: .bold)

        nganAnh.axis = .vertical
        nganAnh.spacing = 10

        let nutThemAnh = UIButton(type: .system)
        var chThemAnh = UIButton.Configuration.tinted()
        chThemAnh.title = "＋ Thêm ô Ảnh mới"
        nutThemAnh.configuration = chThemAnh
        nutThemAnh.addTarget(self, action: #selector(themOAnh), for: .touchUpInside)

        [nutGui, lbChu, nganChu, nutThemChu, lbAnh, nganAnh, nutThemAnh].forEach {
            nganChinh.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganChinh.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 14),
            nganChinh.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -30),
            nganChinh.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            nganChinh.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    @objc private func veDanhSach() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        nganChu.arrangedSubviews.forEach {
            nganChu.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (idx, muc) in danhSachChu.enumerated() {
            nganChu.addArrangedSubview(taoTheChu(muc: muc, chiSo: idx))
        }

        nganAnh.arrangedSubviews.forEach {
            nganAnh.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (idx, muc) in danhSachAnh.enumerated() {
            nganAnh.addArrangedSubview(taoTheAnh(muc: muc, chiSo: idx))
        }
    }

    private func taoTheChu(muc: MucChuSheet, chiSo: Int) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let the = UIView()
        the.backgroundColor = mau.card
        the.layer.cornerRadius = 12
        the.layer.borderWidth = 1
        the.layer.borderColor = mau.border.cgColor

        let lbViTri = UILabel()
        lbViTri.text = "Vị trí ô:"
        lbViTri.font = .systemFont(ofSize: 13, weight: .bold)
        lbViTri.textColor = mau.subText

        let oViTri = UITextField()
        oViTri.borderStyle = .roundedRect
        oViTri.placeholder = "A1"
        oViTri.textAlignment = .center
        oViTri.font = .systemFont(ofSize: 15, weight: .bold)
        oViTri.text = muc.cell
        oViTri.widthAnchor.constraint(equalToConstant: 80).isActive = true
        oViTri.addAction(UIAction { [weak self, weak oViTri] _ in
            guard let self, chiSo < self.danhSachChu.count else { return }
            self.danhSachChu[chiSo].cell = (oViTri?.text ?? "").uppercased()
        }, for: .editingChanged)

        let nutXoa = UIButton(type: .system)
        nutXoa.setImage(UIImage(systemName: "trash"), for: .normal)
        nutXoa.tintColor = mau.error
        nutXoa.addAction(UIAction { [weak self] _ in
            guard let self, self.danhSachChu.count > 1 else { return }
            self.danhSachChu.remove(at: chiSo)
            self.veDanhSach()
        }, for: .touchUpInside)

        let hangTren = UIStackView(arrangedSubviews: [lbViTri, oViTri, UIView(), nutXoa])
        hangTren.axis = .horizontal
        hangTren.spacing = 8
        hangTren.alignment = .center

        let oNoiDung = UITextField()
        oNoiDung.borderStyle = .roundedRect
        oNoiDung.placeholder = "Nhập nội dung chi tiết..."
        oNoiDung.text = muc.content
        oNoiDung.addAction(UIAction { [weak self, weak oNoiDung] _ in
            guard let self, chiSo < self.danhSachChu.count else { return }
            self.danhSachChu[chiSo].content = oNoiDung?.text ?? ""
        }, for: .editingChanged)

        let ngan = UIStackView(arrangedSubviews: [hangTren, oNoiDung])
        ngan.axis = .vertical
        ngan.spacing = 8
        ngan.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(ngan)

        NSLayoutConstraint.activate([
            ngan.topAnchor.constraint(equalTo: the.topAnchor, constant: 12),
            ngan.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -12),
            ngan.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            ngan.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])
        return the
    }

    private func taoTheAnh(muc: MucAnhSheet, chiSo: Int) -> UIView {
        let mau = KhoDuLieu.dungChung.mauSac
        let the = UIView()
        the.backgroundColor = mau.card
        the.layer.cornerRadius = 12
        the.layer.borderWidth = 1
        the.layer.borderColor = mau.border.cgColor

        let lbViTri = UILabel()
        lbViTri.text = "Vị trí ô:"
        lbViTri.font = .systemFont(ofSize: 13, weight: .bold)
        lbViTri.textColor = mau.subText

        let oViTri = UITextField()
        oViTri.borderStyle = .roundedRect
        oViTri.placeholder = "B2"
        oViTri.textAlignment = .center
        oViTri.font = .systemFont(ofSize: 15, weight: .bold)
        oViTri.text = muc.cell
        oViTri.widthAnchor.constraint(equalToConstant: 80).isActive = true
        oViTri.addAction(UIAction { [weak self, weak oViTri] _ in
            guard let self, chiSo < self.danhSachAnh.count else { return }
            self.danhSachAnh[chiSo].cell = (oViTri?.text ?? "").uppercased()
        }, for: .editingChanged)

        let nutXoa = UIButton(type: .system)
        nutXoa.setImage(UIImage(systemName: "trash"), for: .normal)
        nutXoa.tintColor = mau.error
        nutXoa.addAction(UIAction { [weak self] _ in
            guard let self, self.danhSachAnh.count > 1 else { return }
            self.danhSachAnh.remove(at: chiSo)
            self.veDanhSach()
        }, for: .touchUpInside)

        let hangTren = UIStackView(arrangedSubviews: [lbViTri, oViTri, UIView(), nutXoa])
        hangTren.axis = .horizontal
        hangTren.spacing = 8
        hangTren.alignment = .center

        let nutAnh = UIButton(type: .system)
        nutAnh.backgroundColor = mau.iconBg
        nutAnh.layer.cornerRadius = 8
        nutAnh.clipsToBounds = true
        nutAnh.heightAnchor.constraint(equalToConstant: 140).isActive = true

        if let img = hinhAnhTam[muc.id] {
            let iv = UIImageView(image: img)
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            nutAnh.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: nutAnh.topAnchor),
                iv.bottomAnchor.constraint(equalTo: nutAnh.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: nutAnh.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: nutAnh.trailingAnchor)
            ])
        } else {
            nutAnh.setTitle("📸 Chạm để chọn hoặc chụp ảnh", for: .normal)
        }

        nutAnh.addAction(UIAction { [weak self] _ in
            self?.idAnhDangChon = muc.id
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            self?.present(picker, animated: true)
        }, for: .touchUpInside)

        let ngan = UIStackView(arrangedSubviews: [hangTren, nutAnh])
        ngan.axis = .vertical
        ngan.spacing = 8
        ngan.translatesAutoresizingMaskIntoConstraints = false
        the.addSubview(ngan)

        NSLayoutConstraint.activate([
            ngan.topAnchor.constraint(equalTo: the.topAnchor, constant: 12),
            ngan.bottomAnchor.constraint(equalTo: the.bottomAnchor, constant: -12),
            ngan.leadingAnchor.constraint(equalTo: the.leadingAnchor, constant: 12),
            ngan.trailingAnchor.constraint(equalTo: the.trailingAnchor, constant: -12)
        ])
        return the
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage,
              let id = idAnhDangChon,
              let idx = danhSachAnh.firstIndex(where: { $0.id == id }) else { return }
        hinhAnhTam[id] = img
        danhSachAnh[idx].base64 = img.jpegData(compressionQuality: 0.75)?.base64EncodedString()
        veDanhSach()
    }

    @objc private func themOChu() {
        danhSachChu.append(MucChuSheet())
        veDanhSach()
    }

    @objc private func themOAnh() {
        danhSachAnh.append(MucAnhSheet())
        veDanhSach()
    }

    @objc private func moCauHinhUrl() {
        let alert = UIAlertController(title: "Cấu hình Google Script URL", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = KhoDuLieu.dungChung.caiDat.sheetWebhookUrl
            tf.placeholder = "https://script.google.com/macros/s/.../exec"
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { _ in
            var cd = KhoDuLieu.dungChung.caiDat
            cd.sheetWebhookUrl = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            KhoDuLieu.dungChung.luuCaiDat(cd)
        })
        present(alert, animated: true)
    }

    @objc private func guiDuLieu() {
        view.endEditing(true)
        let urlStr = KhoDuLieu.dungChung.caiDat.sheetWebhookUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlStr), !urlStr.isEmpty else {
            hienThongBao("Lỗi", "Chưa có Link Script!")
            return
        }

        let chuHopLe = danhSachChu.filter { !$0.cell.isEmpty && !$0.content.isEmpty }
        let anhHopLe = danhSachAnh.filter { !$0.cell.isEmpty && ($0.base64?.isEmpty == false) }
        guard !chuHopLe.isEmpty || !anhHopLe.isEmpty else {
            hienThongBao("Trống trơn", "Bạn chưa nhập vị trí ô và nội dung!")
            return
        }

        nutGui.isEnabled = false
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "texts": chuHopLe.map { ["id": $0.id, "cell": $0.cell, "content": $0.content] },
            "images": anhHopLe.map { ["id": $0.id, "cell": $0.cell, "base64": $0.base64 ?? ""] }
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] _, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.nutGui.isEnabled = true
                if let error {
                    self.hienThongBao("Lỗi gửi", error.localizedDescription)
                    return
                }
                self.hienThongBao("Thành công! 🚀", "Đã gửi dữ liệu lên Google Sheets!")
                self.danhSachChu = [MucChuSheet()]
                self.danhSachAnh = [MucAnhSheet()]
                self.hinhAnhTam.removeAll()
                self.veDanhSach()
            }
        }.resume()
    }

    private func hienThongBao(_ tieuDe: String, _ noiDung: String) {
        let alert = UIAlertController(title: tieuDe, message: noiDung, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}
