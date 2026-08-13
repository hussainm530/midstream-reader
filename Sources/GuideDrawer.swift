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
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stack.addArrangedSubview(makeLabel(paperTitle, size: 15, weight: .semibold,
                                           color: UIColor(white: 0.15, alpha: 1)))

        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            stack.addArrangedSubview(makeLabel(
                "No reading guide for this paper. It is not queued as a rep.",
                size: 13, weight: .regular, color: UIColor(white: 0.5, alpha: 1)))
            return
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
