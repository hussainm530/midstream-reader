import Foundation

/// A paper in the reading queue.
///
/// `key` is the Zotero item key -- the same eight-character key that appears in
/// the staged filename. It is the join between this app, the Zotero library,
/// and the literature note, so it must survive every round trip untouched.
struct Paper: Codable {
    let key: String
    let title: String
    let filename: String
    /// Journal page of PDF page 1, so citations come out right. Mirrors
    /// `page_offset` in the staging state file.
    let pageOffset: Int
    /// Why this paper, what to look for -- rendered in the guide drawer.
    /// Comes from the reading plan; empty when the paper is not part of a rep.
    let guideMarkdown: String
    /// Minutes the rep is meant to last, if this paper is queued as one.
    let repMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case key, title, filename
        case pageOffset = "page_offset"
        case guideMarkdown = "guide"
        case repMinutes = "rep_minutes"
    }
}

/// Categories match the vault's own scheme, so the pull needs no translation
/// step. Chosen by tapping a chip -- the point is that most annotations should
/// need no typing at all.
enum AnnotationCategory: String, Codable, CaseIterable {
    case quote = "Quote"
    case finding = "Finding"
    case critique = "Critique"
    case methodology = "Methodology"
    case general = "General"

    var chipLabel: String {
        switch self {
        case .quote: return "Quote"
        case .finding: return "Finding"
        case .critique: return "Critique"
        case .methodology: return "Method"
        case .general: return "General"
        }
    }
}

/// One highlight, plus whatever the reader had to say about it.
///
/// This is the record GoodReader could not keep: `text` is the *actual*
/// selection, captured at the moment of highlighting. GoodReader stores a
/// point-anchored sticky note and discards the selection, which is why 17 of 20
/// annotations had to have their passage inferred on 9 Aug.
struct Annotation: Codable {
    let id: String
    let paperKey: String
    /// Zero-based PDF page index. The journal page is derived with the
    /// paper's `pageOffset` at write time, never stored pre-adjusted.
    let pageIndex: Int
    let text: String
    var comment: String
    var category: AnnotationCategory?
    /// Filename of a recorded voice note in the app's `voice/` directory,
    /// awaiting transcription on the laptop.
    var voiceNote: String?
    let createdAt: Date
    /// Selection rectangles in PDF page space, so the highlight can be
    /// reconstructed exactly when it is written back into the PDF.
    let quadPoints: [[Double]]

    enum CodingKeys: String, CodingKey {
        case id, text, comment, category
        case paperKey = "paper_key"
        case pageIndex = "page_index"
        case voiceNote = "voice_note"
        case createdAt = "created_at"
        case quadPoints = "quad_points"
    }
}

/// A single timed reading rep, written to the vault's Rep Log.
///
/// The timer exists because reps are time-boxed and the clock currently lives
/// on a different device from the paper, so reps go untimed or get guessed
/// after the fact.
struct Rep: Codable {
    let paperKey: String
    let startedAt: Date
    var endedAt: Date?
    var annotationCount: Int

    enum CodingKeys: String, CodingKey {
        case paperKey = "paper_key"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case annotationCount = "annotation_count"
    }
}
