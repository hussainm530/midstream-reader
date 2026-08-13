import Foundation

/// On-device storage. The whole reason for going native rather than PWA.
///
/// Everything lives in the app's Documents directory: a real filesystem that
/// iOS does not evict, unlike the Cache/IndexedDB storage a web app would have
/// had to trust. Annotations made on a train with no signal are as durable as
/// ones made at the desk, and the app is fully usable with the ThinkPad
/// switched off. Sync is a background convenience, never a precondition.
final class Store {
    static let shared = Store()

    private let fm = FileManager.default
    private let root: URL
    let pdfDir: URL
    let voiceDir: URL
    private let annotationsFile: URL
    private let papersFile: URL
    private let repsFile: URL

    private(set) var papers: [Paper] = []
    private(set) var annotations: [Annotation] = []
    private(set) var reps: [Rep] = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        pdfDir = root.appendingPathComponent("papers", isDirectory: true)
        voiceDir = root.appendingPathComponent("voice", isDirectory: true)
        annotationsFile = root.appendingPathComponent("annotations.json")
        papersFile = root.appendingPathComponent("papers.json")
        repsFile = root.appendingPathComponent("reps.json")

        for dir in [pdfDir, voiceDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        load()
    }

    // MARK: - Loading

    private func load() {
        papers = decodeFile(papersFile) ?? []
        annotations = decodeFile(annotationsFile) ?? []
        reps = decodeFile(repsFile) ?? []
    }

    private func decodeFile<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        // Atomic, because the alternative is a truncated annotations file
        // after a mid-write crash -- and annotations are the one thing here
        // that cannot be regenerated from the laptop.
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Papers

    func setPapers(_ new: [Paper]) {
        papers = new
        write(papers, to: papersFile)
    }

    func localURL(for paper: Paper) -> URL {
        return pdfDir.appendingPathComponent(paper.filename)
    }

    func isDownloaded(_ paper: Paper) -> Bool {
        return fm.fileExists(atPath: localURL(for: paper).path)
    }

    // MARK: - Annotations

    func annotations(for paperKey: String) -> [Annotation] {
        return annotations
            .filter { $0.paperKey == paperKey }
            .sorted { $0.pageIndex < $1.pageIndex }
    }

    func add(_ annotation: Annotation) {
        annotations.append(annotation)
        write(annotations, to: annotationsFile)
    }

    func update(_ annotation: Annotation) {
        guard let i = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations[i] = annotation
        write(annotations, to: annotationsFile)
    }

    func delete(id: String) {
        annotations.removeAll { $0.id == id }
        write(annotations, to: annotationsFile)
    }

    // MARK: - Reps

    func add(_ rep: Rep) {
        reps.append(rep)
        write(reps, to: repsFile)
    }

    func updateLatestRep(_ transform: (inout Rep) -> Void) {
        guard !reps.isEmpty else { return }
        transform(&reps[reps.count - 1])
        write(reps, to: repsFile)
    }

    /// Everything the laptop has not yet acknowledged.
    ///
    /// The unsynced set is derived rather than tracked with a dirty flag, so a
    /// failed or half-finished sync cannot silently mark work as delivered.
    func unsynced(since lastSync: Date?) -> (annotations: [Annotation], reps: [Rep]) {
        guard let last = lastSync else { return (annotations, reps) }
        return (annotations.filter { $0.createdAt > last },
                reps.filter { $0.startedAt > last })
    }
}
