import AVFoundation
import Foundation

/// Records a spoken annotation to an m4a in the app's `voice/` directory.
///
/// This is the answer to "typing is a pain" that does not depend on iOS 12
/// ever getting a swipe keyboard. iOS dictation is real-time speech-to-text
/// and is mediocre on this hardware; this deliberately does *not* transcribe.
/// It captures audio and defers transcription to Moonshine on the ThinkPad,
/// which is both far more accurate and impossible to run on an A7.
///
/// The trade-off is honest: the annotation is unreadable until it syncs and is
/// transcribed. For a paragraph of thinking on a train, speaking for twenty
/// seconds beats typing it with two thumbs on a 7.9" screen.
final class VoiceRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var currentFilename: String?

    var isRecording: Bool { return recorder?.isRecording ?? false }

    /// Elapsed seconds, for the level/duration readout while recording.
    var duration: TimeInterval { return recorder?.currentTime ?? 0 }

    /// Requests permission if needed, then starts. `completion` reports whether
    /// recording actually began -- a denied microphone must not look like a
    /// silent successful recording.
    func start(paperKey: String, completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    completion(false)
                    return
                }
                completion(self.beginRecording(paperKey: paperKey, session: session))
            }
        }
    }

    private func beginRecording(paperKey: String, session: AVAudioSession) -> Bool {
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return false
        }

        // Named by paper and timestamp so the laptop can file the transcript
        // against the right annotation without a lookup table.
        let stamp = Int(Date().timeIntervalSince1970)
        let name = "\(paperKey)-\(stamp).m4a"
        let url = Store.shared.voiceDir.appendingPathComponent(name)

        // Mono 22 kHz AAC: speech-grade, and small enough that a long offline
        // stretch of voice notes is still a trivial upload.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            guard r.record() else { return false }
            recorder = r
            currentFilename = name
            return true
        } catch {
            return false
        }
    }

    /// Stops and returns the filename, or nil if nothing usable was captured.
    @discardableResult
    func stop() -> String? {
        guard let r = recorder else { return nil }
        let tooShort = r.currentTime < 0.6
        r.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        let name = currentFilename
        currentFilename = nil

        // A stray tap should not leave an empty file for the laptop to
        // transcribe into nothing.
        if tooShort, let name = name {
            try? FileManager.default.removeItem(
                at: Store.shared.voiceDir.appendingPathComponent(name))
            return nil
        }
        return name
    }

    func cancel() {
        guard let r = recorder, let name = currentFilename else { return }
        r.stop()
        recorder = nil
        currentFilename = nil
        try? FileManager.default.removeItem(
            at: Store.shared.voiceDir.appendingPathComponent(name))
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
