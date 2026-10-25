import UIKit

final class ManHinhMedia: UIViewController {
    private let chonCheDo = UISegmentedControl(items: ["Video", "Ảnh", "Tiêu đề", "Nhạc"])
    private let cuon = UIScrollView()
    private let nganNoiDung = UIStackView()

    private let oMaxNV = UITextField()
    private let oMaxVideo = UITextField()
    private let oCotTruyen = UITextView()
    private let oNhapChung = UITextView()
    private let chonNenTangTieuDe = UISegmentedControl(items: ["Video Dài", "Shorts"])
    private let oYTuongNhac = UITextView()
    private var chuDeNhacHienTai: (title: String, genre: String, prompt: String, chord: String)?
    private var tenBaiHatHienTai: String = ""

    private let hopKetQua = UITextView()
    private let nutSaoChep = UIButton(type: .system)
    private let nganStudioNhac = UIStackView()
    private let vongXoay = UIActivityIndicatorView(style: .medium)

    private let cacChuDeMau: [(title: String, genre: String, prompt: String, chord: String)] = [
        ("Tiếng Mưa Mái Tôn", "Lofi / Acoustic", "Ngày mưa bão, ấm áp trong nhà, tiếng mưa ồn ào nhưng bình yên.", "Cmaj7 - Am7 - Fmaj7 - G7"),
        ("Đôi Giày Cũ", "Ballad / Country", "Đôi giày mòn gót của cha, hành trình vất vả và tình yêu thầm lặng.", "G - D/F# - Em - C"),
        ("Cơm Chiều", "Pop / Swing", "Tiếng bát đũa, mùi thức ăn, chờ bố về ăn cơm.", "F - G - Em - Am"),
        ("Chủ Nhật Lười", "Reggae", "Không báo thức, chỉ có tiếng quạt và mèo kêu. Niềm vui không làm gì.", "Dm7 - G7 - Cmaj7"),
        ("Kẹt Xe", "Rap / Hip-hop", "Hỗn loạn giờ tan tầm, tiếng còi xe và mong muốn về nhà.", "Bm - G - A - F#")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Media AI"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(xoaTrang)
        )

        taoGiaoDien()
        doiCheDo()
        NotificationCenter.default.addObserver(self, selector: #selector(doiCheDo), name: .caiDatThayDoi, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func taoGiaoDien() {
        cuon.keyboardDismissMode = .interactive
        cuon.alwaysBounceVertical = true
        cuon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cuon)

        nganNoiDung.axis = .vertical
        nganNoiDung.spacing = 12
        nganNoiDung.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(nganNoiDung)

        chonCheDo.selectedSegmentIndex = 0
        chonCheDo.addTarget(self, action: #selector(doiCheDo), for: .valueChanged)

        oMaxNV.text = "200"
        oMaxNV.borderStyle = .roundedRect
        oMaxNV.keyboardType = .numberPad

        oMaxVideo.text = "800"
        oMaxVideo.borderStyle = .roundedRect
        oMaxVideo.keyboardType = .numberPad

        [oCotTruyen, oNhapChung, oYTuongNhac].forEach {
            $0.font = .systemFont(ofSize: 15)
            $0.layer.cornerRadius = 10
            $0.layer.borderWidth = 1
            $0.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        chonNenTangTieuDe.selectedSegmentIndex = 0

        hopKetQua.isEditable = false
        hopKetQua.font = .systemFont(ofSize: 14)
        hopKetQua.layer.cornerRadius = 12
        hopKetQua.layer.borderWidth = 1
        hopKetQua.heightAnchor.constraint(equalToConstant: 240).isActive = true

        var chCopy = UIButton.Configuration.tinted()
        chCopy.title = "📋 Copy Kết Quả"
        nutSaoChep.configuration = chCopy
        nutSaoChep.addTarget(self, action: #selector(saoChepKetQua), for: .touchUpInside)

        nganStudioNhac.axis = .vertical
        nganStudioNhac.spacing = 8

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cuon.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cuon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            nganNoiDung.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor, constant: 14),
            nganNoiDung.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor, constant: -30),
            nganNoiDung.leadingAnchor.constraint(equalTo: cuon.frameLayoutGuide.leadingAnchor, constant: 16),
            nganNoiDung.trailingAnchor.constraint(equalTo: cuon.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    @objc private func doiCheDo() {
        let mau = KhoDuLieu.dungChung.mauSac
        view.backgroundColor = mau.bg

        [oCotTruyen, oNhapChung, oYTuongNhac, hopKetQua].forEach {
            $0.backgroundColor = mau.card
            $0.textColor = mau.text
            $0.layer.borderColor = mau.border.cgColor
        }

        nganNoiDung.arrangedSubviews.forEach {
            nganNoiDung.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        nganNoiDung.addArrangedSubview(chonCheDo)

        switch chonCheDo.selectedSegmentIndex {
        case 0:
            let hangMax = UIStackView(arrangedSubviews: [
                taoCapNhan("Max ký tự NV:", oMaxNV),
                taoCapNhan("Max ký tự Video:", oMaxVideo)
            ])
            hangMax.distribution = .fillEqually
            hangMax.spacing = 10
            nganNoiDung.addArrangedSubview(hangMax)
            nganNoiDung.addArrangedSubview(taoNhan("Nội dung / Câu chuyện (8s):"))
            nganNoiDung.addArrangedSubview(oCotTruyen)
            nganNoiDung.addArrangedSubview(taoNutChinh("✨ Phân tích & Tạo Prompt VEO3", hanhDong: #selector(taoPromptVideo)))

        case 1:
            nganNoiDung.addArrangedSubview(taoNhan("Ý tưởng ảnh:"))
            nganNoiDung.addArrangedSubview(oNhapChung)
            nganNoiDung.addArrangedSubview(taoNutChinh("✨ Tạo Prompt Ảnh", hanhDong: #selector(taoPromptAnh)))

        case 2:
            nganNoiDung.addArrangedSubview(taoNhan("Nội dung video:"))
            nganNoiDung.addArrangedSubview(oNhapChung)
            nganNoiDung.addArrangedSubview(chonNenTangTieuDe)
            nganNoiDung.addArrangedSubview(taoNutChinh("✨ Tạo 5 Tiêu Đề YouTube", hanhDong: #selector(taoTieuDe)))

        default:
            let hangNgauNhien = UIStackView(arrangedSubviews: [
                taoNutChinh("🎲 Chủ đề ngẫu nhiên", hanhDong: #selector(chonChuDeNgauNhien)),
                taoNutChinh("✨ Tạo chủ đề từ ý tưởng", hanhDong: #selector(taoChuDeTuYTuong))
            ])
            hangNgauNhien.distribution = .fillEqually
            hangNgauNhien.spacing = 8
            nganNoiDung.addArrangedSubview(taoNhan("Ý tưởng bài hát:"))
            nganNoiDung.addArrangedSubview(oYTuongNhac)
            nganNoiDung.addArrangedSubview(hangNgauNhien)
            nganNoiDung.addArrangedSubview(taoNutChinh("🎵 Viết Nhạc, Lời & Hợp Âm (AI)", hanhDong: #selector(vietNhacDayDu)))
            taoNutStudioNhac()
            nganNoiDung.addArrangedSubview(nganStudioNhac)
        }

        nganNoiDung.addArrangedSubview(vongXoay)
        nganNoiDung.addArrangedSubview(taoNhan("Kết quả AI:"))
        nganNoiDung.addArrangedSubview(hopKetQua)
        nganNoiDung.addArrangedSubview(nutSaoChep)
    }

    private func taoNhan(_ chu: String) -> UILabel {
        let lb = UILabel()
        lb.text = chu
        lb.font = .systemFont(ofSize: 13, weight: .bold)
        lb.textColor = KhoDuLieu.dungChung.mauSac.subText
        return lb
    }

    private func taoCapNhan(_ chu: String, _ v: UIView) -> UIStackView {
        let st = UIStackView(arrangedSubviews: [taoNhan(chu), v])
        st.axis = .vertical
        st.spacing = 4
        return st
    }

    private func taoNutChinh(_ tieuDe: String, hanhDong: Selector) -> UIButton {
        let nut = UIButton(type: .system)
        var ch = UIButton.Configuration.filled()
        ch.title = tieuDe
        ch.baseBackgroundColor = KhoDuLieu.dungChung.mauSac.primary
        ch.cornerStyle = .medium
        nut.configuration = ch
        nut.heightAnchor.constraint(equalToConstant: 40).isActive = true
        nut.addTarget(self, action: hanhDong, for: .touchUpInside)
        return nut
    }

    private func taoNutStudioNhac() {
        nganStudioNhac.arrangedSubviews.forEach {
            nganStudioNhac.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        nganStudioNhac.addArrangedSubview(taoNhan("✨ STUDIO SÁNG TẠO AI:"))

        let cacMuc: [(String, String)] = [
            ("🎹 Hòa Âm", "arrange"),
            ("🇬🇧 Dịch Anh", "translate"),
            ("🖼️ Ảnh Bìa", "art"),
            ("⭐ Phê Bình", "critic"),
            ("🎬 Kịch Bản MV", "mv"),
            ("🎼 Nhạc Lý", "theory")
        ]
        for i in stride(from: 0, to: cacMuc.count, by: 2) {
            let h = UIStackView()
            h.distribution = .fillEqually
            h.spacing = 8
            for j in i..<min(i + 2, cacMuc.count) {
                let m = cacMuc[j]
                let b = UIButton(type: .system)
                var ch = UIButton.Configuration.tinted()
                ch.title = m.0
                b.configuration = ch
                b.addAction(UIAction { [weak self] _ in
                    self?.goiStudioNhac(loai: m.1)
                }, for: .touchUpInside)
                h.addArrangedSubview(b)
            }
            nganStudioNhac.addArrangedSubview(h)
        }
    }

    @objc private func xoaTrang() {
        oCotTruyen.text = ""
        oNhapChung.text = ""
        oYTuongNhac.text = ""
        hopKetQua.text = ""
    }

    @objc private func saoChepKetQua() {
        guard !hopKetQua.text.isEmpty else { return }
        UIPasteboard.general.string = hopKetQua.text
        let alert = UIAlertController(title: "Đã Copy!", message: "Đã lưu nội dung vào bộ nhớ tạm.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    @objc private func taoPromptVideo() {
        let story = oCotTruyen.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !story.isEmpty else { return }
        let prompt = """
        Role: Expert Video Prompt Engineer for VEO3 (8-second videos).
        Input Story: "\(story)"
        Constraints: Character Limit \(oMaxNV.text ?? "200"), Main Prompt Limit \(oMaxVideo.text ?? "800").
        CRITICAL: KEEP DIALOGUE IN VIETNAMESE inside "".
        Format clearly with sections:
        1. NHÂN VẬT (Characters)
        2. PROMPT VIDEO (English)
        3. NỘI DUNG VIỆT (Vietnamese)
        """
        goiAI(prompt)
    }

    @objc private func taoPromptAnh() {
        let idea = oNhapChung.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idea.isEmpty else { return }
        goiAI("Describe image idea in detailed English prompt for AI image generation: \"\(idea)\". Then provide Vietnamese translation.")
    }

    @objc private func taoTieuDe() {
        let idea = oNhapChung.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idea.isEmpty else { return }
        let nenTang = chonNenTangTieuDe.selectedSegmentIndex == 0 ? "YouTube Long Video" : "YouTube Shorts"
        goiAI("Generate 5 catchy YouTube titles in Vietnamese for \"\(idea)\" (\(nenTang)). Output titles only.")
    }

    @objc private func chonChuDeNgauNhien() {
        guard let ngauNhien = cacChuDeMau.randomElement() else { return }
        chuDeNhacHienTai = ngauNhien
        tenBaiHatHienTai = ngauNhien.title
        hopKetQua.text = """
        🎵 Chủ đề: \(ngauNhien.title)
        • Thể loại: \(ngauNhien.genre)
        • Ý tưởng: \(ngauNhien.prompt)
        • Vòng hợp âm gợi ý: \(ngauNhien.chord)
        """
    }

    @objc private func taoChuDeTuYTuong() {
        let idea = oYTuongNhac.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idea.isEmpty else { return }
        tenBaiHatHienTai = idea
        goiAI("Dựa trên ý tưởng sơ khai: \"\(idea)\", hãy tạo chủ đề bài hát sáng tạo bằng tiếng Việt gồm: Tên bài hát, Thể loại, Ý tưởng chủ đạo và Vòng hợp âm gợi ý.")
    }

    @objc private func vietNhacDayDu() {
        let chuDe = chuDeNhacHienTai?.title ?? oYTuongNhac.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chuDe.isEmpty else { return }
        tenBaiHatHienTai = chuDe
        let prompt = """
        Hãy đóng vai nhạc sĩ chuyên nghiệp. Viết một bài hát hoàn chỉnh bằng tiếng Việt dựa trên chủ đề: "\(chuDe)".
        Trình bày rõ:
        - Tên bài hát, Thể loại, Nhịp độ, Nhạc cụ
        - Lời bài hát kèm [Hợp âm] đặt ngay trong dòng
        - Đoạn mã ABC Notation đơn giản cho giai điệu chính.
        """
        goiAI(prompt)
    }

    private func goiStudioNhac(loai: String) {
        let bai = tenBaiHatHienTai.isEmpty ? "Bài hát hiện tại" : tenBaiHatHienTai
        let query: String
        switch loai {
        case "arrange": query = "Phân tích bài hát '\(bai)' và gợi ý hướng dẫn hòa âm phối khí ngắn gọn bằng tiếng Việt."
        case "translate": query = "Dịch lời bài hát sau sang tiếng Anh sao cho hát được theo nhịp:\n\(hopKetQua.text ?? "")"
        case "art": query = "Tạo Midjourney prompt chất lượng cao bằng tiếng Anh cho ảnh bìa album của bài hát '\(bai)'."
        case "critic": query = "Đánh giá bài hát '\(bai)' (1-5 sao), viết lời bình dí dỏm và gợi ý 3 nghệ sĩ có phong cách tương tự."
        case "mv": query = "Viết kịch bản MV ngắn gọn gồm 3 phân cảnh ấn tượng cho bài hát '\(bai)' bằng tiếng Việt."
        default: query = "Giải thích vòng hợp âm và phong cách nhạc lý của bài hát '\(bai)' dễ hiểu cho người mới bắt đầu."
        }
        goiAI(query)
    }

    private func goiAI(_ prompt: String) {
        view.endEditing(true)
        vongXoay.startAnimating()
        DichVuGemini.dungChung.goiGemini(prompt: prompt) { [weak self] ketQua in
            guard let self else { return }
            self.vongXoay.stopAnimating()
            switch ketQua {
            case .success(let text):
                self.hopKetQua.text = text
            case .failure(let err):
                let alert = UIAlertController(title: "Lỗi AI", message: err.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Đóng", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}
