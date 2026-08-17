import UIKit

/// The rep clock, drawn as the reading plan rather than as a number.
///
/// Two things the digits could not do. It shows *which chunk you are meant to
/// be in*, because the arc is a sequence of goals and a bare elapsed time
/// doesn't say which one is current. And it **depletes** rather than counts up:
/// the Time Timer's disappearing disc renders remaining time as a shrinking
/// quantity instead of a number you have to subtract, which is the whole point
/// when the failure being designed against is time blindness rather than
/// ignorance of the clock.
///
/// Segment widths are proportional to each chunk's minutes, so triage really
/// does look like the short one.
final class ChunkTimerBar: UIView {

    private let track = UIStackView()
    private let caption = UILabel()
    private var segments: [UIView] = []
    private var fills: [UIView] = []
    private var fillWidths: [NSLayoutConstraint] = []
    private var minutes: [Int] = []

    private let spent = UIColor(white: 0.80, alpha: 1)
    private let pending = UIColor(white: 0.88, alpha: 1)
    private let live = UIColor(red: 0.91, green: 0.69, blue: 0.29, alpha: 1)
    private let over = UIColor(red: 0.78, green: 0.35, blue: 0.28, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        track.axis = .horizontal
        track.spacing = 3
        track.distribution = .fill
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)

        caption.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        caption.textColor = UIColor(white: 0.35, alpha: 1)
        caption.numberOfLines = 2
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)

        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: 12),

            caption.topAnchor.constraint(equalTo: track.bottomAnchor, constant: 6),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor),
            caption.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// Rebuild the track for a given arc.
    func setChunks(_ chunks: [GuideChunk]) {
        segments.forEach { $0.removeFromSuperview() }
        segments = []; fills = []; fillWidths = []
        minutes = chunks.map { max(1, $0.minutes) }

        let total = CGFloat(minutes.reduce(0, +))
        for m in minutes {
            let seg = UIView()
            seg.backgroundColor = pending
            seg.layer.cornerRadius = 3
            seg.clipsToBounds = true
            seg.translatesAutoresizingMaskIntoConstraints = false

            // The depleting part. Anchored to the *leading* edge and shrunk as
            // time runs out, so the colour visibly drains away.
            let fill = UIView()
            fill.backgroundColor = live
            fill.translatesAutoresizingMaskIntoConstraints = false
            seg.addSubview(fill)
            let w = fill.widthAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: seg.leadingAnchor),
                fill.topAnchor.constraint(equalTo: seg.topAnchor),
                fill.bottomAnchor.constraint(equalTo: seg.bottomAnchor),
                w
            ])

            track.addArrangedSubview(seg)
            // Proportional widths, so a 10-minute triage is visibly shorter
            // than a 15-minute chunk rather than an equal-sized lie.
            seg.widthAnchor.constraint(
                equalTo: track.widthAnchor,
                multiplier: CGFloat(m) / total,
                constant: -3).isActive = true

            segments.append(seg); fills.append(fill); fillWidths.append(w)
        }
        update(elapsed: 0)
    }

    /// Advance the bar. `elapsed` is seconds since the rep began.
    func update(elapsed: TimeInterval) {
        guard !minutes.isEmpty else { return }

        var remaining = elapsed / 60
        var current = -1
        for (i, m) in minutes.enumerated() {
            let span = Double(m)
            if remaining >= span {
                // Chunk fully spent.
                remaining -= span
                segments[i].backgroundColor = spent
                fillWidths[i].constant = 0
            } else {
                if current < 0 { current = i }
                let left = span - max(0, remaining)
                let fraction = CGFloat(left / span)
                segments[i].backgroundColor = pending
                fills[i].backgroundColor = current == i ? live : pending
                fillWidths[i].constant = current == i
                    ? segments[i].bounds.width * fraction : 0
                remaining = 0
            }
        }
        layoutIfNeeded()

        if current < 0 {
            let overBy = Int(elapsed / 60) - minutes.reduce(0, +)
            caption.textColor = over
            caption.text = "Arc complete · \(overBy) min over"
            return
        }

        // Minutes left in the current chunk, rounded up: "0 min left" while a
        // chunk is still running would be a lie, and the number exists to be
        // glanced at rather than trusted to the second.
        let intoArc = elapsed / 60
        let startOfCurrent = Double(minutes[0..<current].reduce(0, +))
        let leftMin = Double(minutes[current]) - (intoArc - startOfCurrent)
        caption.textColor = UIColor(white: 0.35, alpha: 1)
        caption.text = String(format: "Chunk %d of %d · %d min left",
                              current + 1, minutes.count,
                              max(0, Int(leftMin.rounded(.up))))
    }

    /// Index of the chunk the clock is currently in, or nil once past the end.
    func currentIndex(elapsed: TimeInterval) -> Int? {
        var remaining = elapsed / 60
        for (i, m) in minutes.enumerated() {
            if remaining < Double(m) { return i }
            remaining -= Double(m)
        }
        return nil
    }
}
