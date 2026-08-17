import UIKit

/// The reading timer, in the reader, where the reading happens.
///
/// Reps are time-boxed (20/45/90 minutes in the training tracker) but the clock
/// has always lived on another device, so reps went untimed or were reconstructed
/// afterwards from memory. This runs against the rep's target and writes the
/// real elapsed minutes into the Rep Log at the end.
///
/// Design constraint: it must be readable at a glance and invisible the rest of
/// the time. A prominent countdown turns reading into clock-watching, which is
/// the opposite of the point.
final class RepTimerView: UIView {
    private let label = UILabel()
    private let progress = UIView()
    private var progressWidth: NSLayoutConstraint!

    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    /// Target duration in seconds; nil for an untimed read (still counts up).
    var target: TimeInterval?

    /// Fired once when the target is reached. The rep does not stop -- running
    /// over is a legitimate choice, and being ejected from a paper mid-argument
    /// would be worse than the overrun.
    var onTargetReached: (() -> Void)?

    /// Fired every second with the elapsed time, so other views (the guide's
    /// chunk bar) can render against this clock instead of running their own.
    /// Two timers would drift, and the one thing worse than an invisible timer
    /// is two visible ones disagreeing.
    var onTick: ((TimeInterval) -> Void)?

    private var isRunning: Bool { return startedAt != nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = UIColor(white: 0, alpha: 0.06)
        layer.cornerRadius = 13
        clipsToBounds = true

        // A thin fill behind the digits shows progress toward the target
        // without a second number to read.
        progress.backgroundColor = UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 0.16)
        progress.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)

        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.25, alpha: 1)
        label.textAlignment = .center
        label.text = "0:00"
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        progressWidth = progress.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: leadingAnchor),
            progress.topAnchor.constraint(equalTo: topAnchor),
            progress.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressWidth,
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    // MARK: - Control

    /// Starts counting. Called automatically when a paper opens, because a rep
    /// you have to remember to start is a rep that goes untimed.
    func start() {
        guard !isRunning else { return }
        startedAt = Date()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self,
                                     selector: #selector(tick),
                                     userInfo: nil, repeats: true)
        // Keep ticking while the PDF is being scrolled, or the timer freezes
        // during exactly the moments you are actually reading.
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }

    func pause() {
        guard let started = startedAt else { return }
        accumulated += Date().timeIntervalSince(started)
        startedAt = nil
        timer?.invalidate()
        timer = nil
        updateLabel()
    }

    @objc private func toggle() {
        isRunning ? pause() : start()
    }

    var elapsed: TimeInterval {
        guard let started = startedAt else { return accumulated }
        return accumulated + Date().timeIntervalSince(started)
    }

    var elapsedMinutes: Int { return Int((elapsed / 60).rounded()) }

    // MARK: - Display

    private var announced = false

    @objc private func tick() {
        updateLabel()
        onTick?(elapsed)
        guard let target = target, target > 0 else { return }
        let fraction = min(1, elapsed / target)
        progressWidth.constant = bounds.width * CGFloat(fraction)
        if fraction >= 1 && !announced {
            announced = true
            onTargetReached?()
        }
    }

    private func updateLabel() {
        let total = Int(elapsed)
        let text = String(format: "%d:%02d", total / 60, total % 60)
        // Paused state has to be visible, or a timer stopped by accident
        // silently under-reports the rep.
        label.text = isRunning ? text : "❙❙ " + text
        label.alpha = isRunning ? 1 : 0.5
    }
}
