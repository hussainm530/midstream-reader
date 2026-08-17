import UIKit

/// The rep clock, drawn as the reading plan rather than as a number.
///
/// Two bars, stacked, both filling **left to right**:
///
///   ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░   the whole arc — how far through the read
///   ▓▓▓▓│▓▓░░│░░░░│░░░░│░░░░   the chunks — which one you are in
///
/// The first version had one segmented bar whose fill *drained* toward the
/// left while progress moved right, so the two halves of the animation fought
/// each other and it read as broken. Filling is also the honest metaphor for
/// the top bar: a thing you are completing, not a thing being taken away.
///
/// Segment widths are proportional to each chunk's minutes, so a 10-minute
/// triage is visibly shorter than a 15-minute chunk rather than an equal-sized
/// lie.
///
/// Why a bar at all rather than digits: the Time Timer's disappearing disc
/// renders time as a *quantity* instead of a number you have to subtract, which
/// is the point when the failure being designed against is time blindness
/// rather than ignorance of the clock.
final class ChunkTimerBar: UIView {

    private let overallTrack = UIView()
    private let overallFill = UIView()
    private var overallFillWidth: NSLayoutConstraint!

    private let chunkTrack = UIStackView()
    private let caption = UILabel()
    private let restartButton = UIButton(type: .system)

    /// Restart the current chunk's clock. Reported with the index so the
    /// caller can work out where in the arc to rewind to.
    var onRestartChunk: ((Int) -> Void)?
    private var currentChunk = 0

    private var segments: [UIView] = []
    private var fills: [UIView] = []
    private var fillWidths: [NSLayoutConstraint] = []
    private var minutes: [Int] = []

    private let done = UIColor(red: 0.42, green: 0.56, blue: 0.47, alpha: 1)
    private let live = UIColor(red: 0.91, green: 0.69, blue: 0.29, alpha: 1)
    private let pending = UIColor(white: 0.87, alpha: 1)
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
        overallTrack.backgroundColor = pending
        overallTrack.layer.cornerRadius = 5
        overallTrack.clipsToBounds = true
        overallTrack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overallTrack)

        overallFill.backgroundColor = live
        overallFill.translatesAutoresizingMaskIntoConstraints = false
        overallTrack.addSubview(overallFill)

        chunkTrack.axis = .horizontal
        chunkTrack.spacing = 3
        chunkTrack.distribution = .fill
        chunkTrack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chunkTrack)

        caption.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        caption.textColor = UIColor(white: 0.35, alpha: 1)
        caption.numberOfLines = 2
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)

        // A chunk you got pulled out of should be restartable without
        // restarting the whole rep -- that is the granularity interruptions
        // actually happen at.
        restartButton.setTitle("↺ Restart chunk", for: .normal)
        restartButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        restartButton.setTitleColor(UIColor(white: 0.42, alpha: 1), for: .normal)
        restartButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 0,
                                                       bottom: 6, right: 0)
        restartButton.contentHorizontalAlignment = .leading
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.addTarget(self, action: #selector(restartTapped),
                                for: .touchUpInside)
        addSubview(restartButton)

        overallFillWidth = overallFill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            overallTrack.topAnchor.constraint(equalTo: topAnchor),
            overallTrack.leadingAnchor.constraint(equalTo: leadingAnchor),
            overallTrack.trailingAnchor.constraint(equalTo: trailingAnchor),
            overallTrack.heightAnchor.constraint(equalToConstant: 10),

            overallFill.leadingAnchor.constraint(equalTo: overallTrack.leadingAnchor),
            overallFill.topAnchor.constraint(equalTo: overallTrack.topAnchor),
            overallFill.bottomAnchor.constraint(equalTo: overallTrack.bottomAnchor),
            overallFillWidth,

            chunkTrack.topAnchor.constraint(equalTo: overallTrack.bottomAnchor,
                                            constant: 4),
            chunkTrack.leadingAnchor.constraint(equalTo: leadingAnchor),
            chunkTrack.trailingAnchor.constraint(equalTo: trailingAnchor),
            chunkTrack.heightAnchor.constraint(equalToConstant: 8),

            caption.topAnchor.constraint(equalTo: chunkTrack.bottomAnchor, constant: 6),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor),

            restartButton.topAnchor.constraint(equalTo: caption.bottomAnchor),
            restartButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            restartButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            restartButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func restartTapped() {
        onRestartChunk?(currentChunk)
    }

    /// Rebuild both tracks for a given arc.
    func setChunks(_ chunks: [GuideChunk]) {
        segments.forEach { $0.removeFromSuperview() }
        segments = []; fills = []; fillWidths = []
        minutes = chunks.map { max(1, $0.minutes) }
        guard !minutes.isEmpty else { return }

        let total = CGFloat(minutes.reduce(0, +))
        for m in minutes {
            let seg = UIView()
            seg.backgroundColor = pending
            seg.layer.cornerRadius = 2
            seg.clipsToBounds = true
            seg.translatesAutoresizingMaskIntoConstraints = false

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

            chunkTrack.addArrangedSubview(seg)
            seg.widthAnchor.constraint(
                equalTo: chunkTrack.widthAnchor,
                multiplier: CGFloat(m) / total,
                constant: -3).isActive = true

            segments.append(seg); fills.append(fill); fillWidths.append(w)
        }
        update(elapsed: 0)
    }

    /// Advance both bars. `elapsed` is seconds since the rep began.
    func update(elapsed: TimeInterval) {
        guard !minutes.isEmpty else { return }
        layoutIfNeeded()   // segment widths must be real before they are used

        let totalMin = Double(minutes.reduce(0, +))
        let intoArc = elapsed / 60

        // Top: one continuous fill across the whole arc.
        let progress = min(1, intoArc / totalMin)
        overallFillWidth.constant = overallTrack.bounds.width * CGFloat(progress)
        overallFill.backgroundColor = intoArc > totalMin ? over : live

        // Bottom: chunks. A finished chunk stays solid rather than emptying --
        // the bar is a record of the read as much as a clock.
        var remaining = intoArc
        var current = -1
        for (i, m) in minutes.enumerated() {
            let span = Double(m)
            if remaining >= span {
                remaining -= span
                fills[i].backgroundColor = done
                fillWidths[i].constant = segments[i].bounds.width
            } else {
                if current < 0 {
                    current = i
                    fills[i].backgroundColor = live
                    fillWidths[i].constant = segments[i].bounds.width
                        * CGFloat(max(0, remaining) / span)
                } else {
                    fillWidths[i].constant = 0
                }
                remaining = 0
            }
        }
        layoutIfNeeded()

        if current < 0 {
            currentChunk = minutes.count - 1
            caption.textColor = over
            caption.text = String(format: "Arc complete · %d min over",
                                  Int(intoArc - totalMin))
            return
        }
        currentChunk = current

        // Rounded up: "0 min left" while a chunk is still running would be a
        // lie, and this number exists to be glanced at, not trusted to the
        // second.
        let startOfCurrent = Double(minutes[0..<current].reduce(0, +))
        let leftInChunk = Double(minutes[current]) - (intoArc - startOfCurrent)
        caption.textColor = UIColor(white: 0.35, alpha: 1)
        caption.text = String(format: "Chunk %d of %d · %d min left  ·  %d of %d min done",
                              current + 1, minutes.count,
                              max(0, Int(leftInChunk.rounded(.up))),
                              Int(intoArc), Int(totalMin))
    }

    /// Minutes from the start of the arc to the start of chunk `index` — where
    /// the arc clock rewinds to when that chunk is restarted.
    func startOfChunk(_ index: Int) -> TimeInterval {
        guard index > 0 && index <= minutes.count else { return 0 }
        return TimeInterval(minutes[0..<index].reduce(0, +) * 60)
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
