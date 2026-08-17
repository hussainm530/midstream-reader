import UIKit

/// The annotation composer — the part GoodReader gets worst.
///
/// Three fixes to three separate complaints:
///
/// 1. **The keyboard no longer covers it.** The composer is pinned to the
///    keyboard's top edge and moves with it, using the real keyboard frame from
///    the will-change-frame notification. GoodReader's popup does not reflow,
///    so half the field is occluded on a 7.9" screen.
/// 2. **Most annotations need no typing at all.** Category chips are one tap,
///    and a highlight with no comment is General by default — the same rule the
///    vault's pull already uses. Typing is for when there is something to say.
/// 3. **Speaking is a first-class input.** Hold to record; the audio syncs and
///    is transcribed by Moonshine on the laptop.
///
/// It cannot fix swipe typing — third-party keyboards are an OS-level feature
/// and iOS 12 predates QuickPath. It can make typing rarer, which is the part
/// actually within reach.
final class CommentComposer: UIView, UITextViewDelegate {

    private let quoteLabel = UILabel()
    private let textView = UITextView()
    private let chipRow = UIStackView()
    private let micButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let recordingLabel = UILabel()

    private let recorder = VoiceRecorder()
    private var recordingTimer: Timer?

    private var selectedCategory: AnnotationCategory?
    private var bottomConstraint: NSLayoutConstraint!

    /// Called with the comment, chosen category, and voice-note filename.
    /// Any of them may be empty — a bare highlight is a valid annotation.
    var onSave: ((String, AnnotationCategory?, String?) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1)
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.86, alpha: 1).cgColor

        // The selected passage, shown so it is obvious what is being annotated.
        // Truncated to two lines: this is confirmation, not re-reading.
        quoteLabel.numberOfLines = 2
        quoteLabel.font = UIFont(name: "Georgia", size: 13) ?? UIFont.systemFont(ofSize: 13)
        quoteLabel.textColor = UIColor(white: 0.42, alpha: 1)
        quoteLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(quoteLabel)

        chipRow.axis = .horizontal
        chipRow.spacing = 6
        chipRow.distribution = .fillProportionally
        chipRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chipRow)
        for category in AnnotationCategory.allCases {
            chipRow.addArrangedSubview(makeChip(category))
        }

        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .white
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor(white: 0.88, alpha: 1).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        micButton.setTitle("🎤  Hold to speak", for: .normal)
        micButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(micButton)
        // Press-and-hold rather than tap-to-toggle: a recording left running
        // by accident is worse than one cut short.
        micButton.addTarget(self, action: #selector(micDown), for: .touchDown)
        micButton.addTarget(self, action: #selector(micUp),
                            for: [.touchUpInside, .touchUpOutside, .touchCancel])

        recordingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        recordingLabel.textColor = UIColor(red: 0.7, green: 0.2, blue: 0.15, alpha: 1)
        recordingLabel.isHidden = true
        recordingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recordingLabel)

        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        addSubview(saveButton)

        NSLayoutConstraint.activate([
            quoteLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            quoteLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            quoteLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            chipRow.topAnchor.constraint(equalTo: quoteLabel.bottomAnchor, constant: 9),
            chipRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            chipRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chipRow.heightAnchor.constraint(equalToConstant: 30),

            textView.topAnchor.constraint(equalTo: chipRow.bottomAnchor, constant: 9),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textView.heightAnchor.constraint(equalToConstant: 78),

            micButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            micButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            micButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            recordingLabel.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
            recordingLabel.leadingAnchor.constraint(equalTo: micButton.trailingAnchor,
                                                    constant: 10),

            saveButton.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])

        observeKeyboard()
    }

    private func makeChip(_ category: AnnotationCategory) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(category.chipLabel, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        b.tag = AnnotationCategory.allCases.firstIndex(of: category) ?? 0
        b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return b
    }

    @objc private func chipTapped(_ sender: UIButton) {
        let category = AnnotationCategory.allCases[sender.tag]
        // Tapping the selected chip clears it, so a mis-tap is one tap to undo
        // rather than a wrong category shipped to the vault.
        selectedCategory = (selectedCategory == category) ? nil : category
        refreshChips()
    }

    private func refreshChips() {
        for (i, view) in chipRow.arrangedSubviews.enumerated() {
            guard let b = view as? UIButton else { continue }
            let on = selectedCategory == AnnotationCategory.allCases[i]
            b.backgroundColor = on
                ? UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1) : .clear
            b.setTitleColor(on ? .white : UIColor(white: 0.3, alpha: 1), for: .normal)
        }
    }

    // MARK: - Keyboard avoidance

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    /// Pins the composer above the keyboard using its actual frame, and matches
    /// the system's own animation curve so it moves *with* the keyboard rather
    /// than chasing it.
    @objc private func keyboardWillChange(_ note: Notification) {
        guard let info = note.userInfo,
              let frame = (info[UIResponder.keyboardFrameEndUserInfoKey]
                            as? NSValue)?.cgRectValue,
              let window = window else { return }

        let overlap = max(0, window.bounds.maxY - frame.origin.y)
        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey]
                        as? Double) ?? 0.25
        let curveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey]
                        as? UInt) ?? 7

        bottomConstraint?.constant = -overlap
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16),
                       animations: { self.superview?.layoutIfNeeded() },
                       completion: nil)
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        bottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.25) { self.superview?.layoutIfNeeded() }
    }

    // MARK: - Presentation

    func install(in parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        bottomConstraint = bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            bottomConstraint
        ])
        isHidden = true
    }

    func present(quote: String) {
        quoteLabel.text = "“" + quote.trimmingCharacters(in: .whitespacesAndNewlines) + "”"
        textView.text = ""
        selectedCategory = nil
        refreshChips()
        isHidden = false
        // Note: the keyboard is *not* raised automatically. Most annotations
        // are a chip tap or a voice note, and forcing the keyboard up would
        // impose the very friction this is meant to remove.
    }

    func dismiss() {
        textView.resignFirstResponder()
        recorder.cancel()
        stopRecordingUI()
        isHidden = true
    }

    // MARK: - Voice

    @objc private func micDown() {
        recorder.start(paperKey: currentPaperKey) { started in
            guard started else {
                self.recordingLabel.text = "no mic access"
                self.recordingLabel.isHidden = false
                return
            }
            self.recordingLabel.isHidden = false
            self.recordingTimer = Timer.scheduledTimer(
                timeInterval: 0.2, target: self, selector: #selector(self.tickRecording),
                userInfo: nil, repeats: true)
        }
    }

    @objc private func tickRecording() {
        recordingLabel.text = String(format: "● %.1fs", recorder.duration)
    }

    @objc private func micUp() {
        guard recorder.isRecording else { return }
        pendingVoiceNote = recorder.stop()
        stopRecordingUI()
        if let name = pendingVoiceNote {
            recordingLabel.isHidden = false
            recordingLabel.textColor = UIColor(white: 0.4, alpha: 1)
            recordingLabel.text = "voice note attached"
            _ = name
        }
    }

    private func stopRecordingUI() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Save

    var currentPaperKey: String = ""
    private var pendingVoiceNote: String?

    @objc private func save() {
        let comment = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(comment, selectedCategory, pendingVoiceNote)
        pendingVoiceNote = nil
        recordingLabel.isHidden = true
        dismiss()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
