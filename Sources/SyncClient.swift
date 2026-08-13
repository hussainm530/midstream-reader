import Foundation

/// Talks to the reader server on the ThinkPad over Tailscale.
///
/// Two properties matter more than anything else here, because they are the
/// two complaints that motivated the whole app:
///
/// 1. **Never blocks the UI.** Sync runs on a background `URLSession` and the
///    reader stays fully usable throughout. GoodReader's Connect-to-Computer
///    holds the app hostage in a modal server mode; nothing here does.
/// 2. **Never requires leaving the paper.** Annotations are pushed one at a
///    time as they are made. There is no "sync" step to go and find.
final class SyncClient {
    static let shared = SyncClient()

    /// The ThinkPad's Tailscale address. Stable, and only reachable on the
    /// tailnet, which is also the only authentication this has.
    var baseURL = URL(string: "http://100.117.163.83:8761")!

    private let session: URLSession
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private(set) var lastSync: Date? {
        get { return UserDefaults.standard.object(forKey: "lastSync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastSync") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        // Short timeouts: offline is the expected case, not an error state.
        // Failing fast keeps the "syncing" indicator honest instead of
        // leaving it spinning for a minute on a train.
        config.timeoutIntervalForRequest = 8
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    // MARK: - Library

    func fetchLibrary(completion: @escaping ([Paper]?) -> Void) {
        let task = session.dataTask(with: baseURL.appendingPathComponent("api/library")) { data, _, _ in
            guard let data = data,
                  let papers = try? self.decoder.decode([Paper].self, from: data) else {
                completion(nil)
                return
            }
            DispatchQueue.main.async {
                Store.shared.setPapers(papers)
                completion(papers)
            }
        }
        task.resume()
    }

    /// Pull a PDF down for offline reading.
    ///
    /// Explicit rather than automatic: the reading lane is only ~8 MB total, so
    /// downloading everything would also be defensible, but making it a
    /// deliberate act means you always know what you have with you before you
    /// lose signal.
    func download(_ paper: Paper, progress: ((Double) -> Void)? = nil,
                  completion: @escaping (Bool) -> Void) {
        let encoded = paper.filename.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed) ?? paper.filename
        let url = baseURL.appendingPathComponent("pdf").appendingPathComponent(encoded)
        let task = session.downloadTask(with: url) { temp, response, _ in
            guard let temp = temp,
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let dest = Store.shared.localURL(for: paper)
            try? FileManager.default.removeItem(at: dest)
            let ok = (try? FileManager.default.moveItem(at: temp, to: dest)) != nil
            DispatchQueue.main.async { completion(ok) }
        }
        task.resume()
    }

    // MARK: - Push

    /// Push one annotation immediately. Silent on failure by design.
    ///
    /// The local copy in `Store` is the record of truth; this is an
    /// opportunistic early delivery. Anything that does not land is picked up
    /// by `flush()` later, so a failed push is not worth interrupting reading
    /// for.
    func push(_ annotation: Annotation) {
        guard var request = jsonRequest(path: "api/annotations") else { return }
        request.httpBody = try? encoder.encode([annotation])
        session.dataTask(with: request).resume()
    }

    /// Send everything the laptop has not acknowledged, including voice notes.
    func flush(completion: ((Bool) -> Void)? = nil) {
        let pending = Store.shared.unsynced(since: lastSync)
        guard var request = jsonRequest(path: "api/sync") else {
            completion?(false)
            return
        }
        let payload = SyncPayload(annotations: pending.annotations, reps: pending.reps)
        request.httpBody = try? encoder.encode(payload)

        session.dataTask(with: request) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if ok {
                self.lastSync = Date()
                self.uploadVoiceNotes(pending.annotations)
            }
            DispatchQueue.main.async { completion?(ok) }
        }.resume()
    }

    /// Voice notes go up as raw audio; transcription happens on the ThinkPad
    /// with Moonshine, which cannot run on this hardware. The recording is the
    /// annotation until then -- deliberately, so speaking a thought is never
    /// blocked on a transcription that might not be available for hours.
    private func uploadVoiceNotes(_ annotations: [Annotation]) {
        for annotation in annotations {
            guard let name = annotation.voiceNote else { continue }
            let url = Store.shared.voiceDir.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else { continue }
            var request = URLRequest(url: baseURL.appendingPathComponent("api/voice/\(name)"))
            request.httpMethod = "POST"
            request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
            session.uploadTask(with: request, from: data).resume()
        }
    }

    private func jsonRequest(path: String) -> URLRequest? {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

private struct SyncPayload: Encodable {
    let annotations: [Annotation]
    let reps: [Rep]
}
