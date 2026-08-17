import UIKit

/// The reading guide, as a collapsible drawer over the page.
///
/// The guide (why this paper, what to look for, the rep's target) has always
/// lived in the vault on the other device, which is the entire reason it gets
/// skipped. Splitting attention across two machines is not a workflow.
///
/// It slides in from the trailing edge and overlays rather than reflowing the
/// PDF, because reflowing would change the page layout mid-read -- and page
/// layout is the thing the readability test said to protect.
final class GuideDrawer: UIView {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let handle = UIButton(type: .system)

    private var widthConstraint: NSLayoutConstraint!
    private(set) var isOpen = false

    private var guideMarkdown = ""
    private var deepMarkdown: String?
    private var paperTitle = ""
    private var deepAvailable = false
    private var deepIsOn = false
    private var onDeepChange: ((Bool) -> Void)?
    private let deepButton = UIButton(type: .system)

    /// Drawer width: wide enough for prose, narrow enough to leave a usable
    /// column of the paper visible on a 7.9" screen in portrait.
    private let openWidth: CGFloat = 260

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 0.97)
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.85, alpha: 1).cgColor
        clipsToBounds = true

        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalToConstant: openWidth - 32)
        ])
    }

    /// Must be called once after the drawer is added to its parent.
    func install(in parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        widthConstraint = widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            widthConstraint
        ])
    }

    func toggle() {
        isOpen ? close() : open()
    }

    func open() {
        isOpen = true
        widthConstraint.constant = openWidth
        animate()
    }

    func close() {
        isOpen = false
        widthConstraint.constant = 0
        animate()
    }

    private func animate() {
        UIView.animate(withDuration: 0.24, delay: 0,
                       options: [.curveEaseOut], animations: {
            self.superview?.layoutIfNeeded()
        }, completion: nil)
    }

    // MARK: - Content

    /// Renders the guide. Deliberately handles only headings, bullets and
    /// paragraphs -- the guide is a short prose brief, not a document, and a
    /// Markdown dependency for three block types would not earn itself.
    func setGuide(_ markdown: String, paperTitle: String) {
        guideMarkdown = markdown
        self.paperTitle = paperTitle
        rebuild()
    }

    /// Attach the deep-read toggle. Called with the paper so the drawer can
    /// report the change; `onChange` lets the reader persist it.
    func setDeepRead(available: Bool, isOn: Bool,
                     onChange: @escaping (Bool) -> Void) {
        deepAvailable = available
        deepIsOn = isOn
        onDeepChange = onChange
        rebuild()
    }

    /// Pass 3's chunks, appended when the checkbox is on. Held rather than
    /// fetched so the toggle works with no network -- the call to go deeper
    /// happens mid-paper, which is when the laptop is least likely to answer.
    func setDeepGuide(_ markdown: String?) {
        deepMarkdown = markdown
        rebuild()
    }

    @objc private func deepTapped() {
        deepIsOn.toggle()
        onDeepChange?(deepIsOn)
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stack.addArrangedSubview(makeLabel(paperTitle, size: 15, weight: .semibold,
                                           color: UIColor(white: 0.15, alpha: 1)))

        let markdown = deepIsOn && !(deepMarkdown ?? "").isEmpty
            ? guideMarkdown + "\n\n" + (deepMarkdown ?? "")
            : guideMarkdown

        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            stack.addArrangedSubview(makeLabel(
                "No reading guide for this paper. It is not queued as a rep.",
                size: 13, weight: .regular, color: UIColor(white: 0.5, alpha: 1)))
            return
        }

        // The toggle sits above the guide, not buried at the end after pass 2:
        // the decision is made at the close of triage, and a control you have
        // to scroll four chunks to reach is one you won't use.
        if deepAvailable {
            stack.addArrangedSubview(makeDeepToggle())
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#") {
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                stack.addArrangedSubview(makeLabel(text.uppercased(), size: 11,
                                                   weight: .semibold,
                                                   color: UIColor(white: 0.45, alpha: 1)))
            } else if line.hasPrefix("-") || line.hasPrefix("*") {
                let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                stack.addArrangedSubview(makeLabel("•  " + text, size: 14,
                                                   weight: .regular,
                                                   color: UIColor(white: 0.2, alpha: 1)))
            } else {
                stack.addArrangedSubview(makeLabel(line, size: 14, weight: .regular,
                                                   color: UIColor(white: 0.2, alpha: 1)))
            }
        }
    }

    /// A checkbox drawn with text rather than an image set: at this size a
    /// filled box glyph reads as well as an asset would, and the app ships no
    /// image catalogue to put one in.
    private func makeDeepToggle() -> UIView {
        let b = UIButton(type: .system)
        b.setTitle((deepIsOn ? "☑︎" : "☐") + "  Deep read — adds pass 3",
                   for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        b.titleLabel?.numberOfLines = 0
        b.contentHorizontalAlignment = .leading
        b.setTitleColor(deepIsOn ? UIColor(red: 0.18, green: 0.43, blue: 0.31, alpha: 1)
                                 : UIColor(white: 0.4, alpha: 1), for: .normal)
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        b.backgroundColor = deepIsOn
            ? UIColor(red: 0.90, green: 0.95, blue: 0.92, alpha: 1)
            : UIColor(white: 0.94, alpha: 1)
        b.layer.cornerRadius = 7
        // 44pt is the documented minimum touch target, and this is a control
        // you reach for with the hand that is holding the iPad.
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.addTarget(self, action: #selector(deepTapped), for: .touchUpInside)
        return b
    }

    private func makeLabel(_ text: String, size: CGFloat,
                           weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = 0
        l.font = UIFont.systemFont(ofSize: size, weight: weight)
        l.textColor = color
        return l
    }
}
