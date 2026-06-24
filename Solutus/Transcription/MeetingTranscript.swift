import Foundation

/// Append-only store of finalized utterances captured during an HR meeting.
///
/// Each `Segment` is one closed thought (one SFSpeech recognition session), so
/// the transcript reads as alternating turns between speakers. Building this
/// out of finalized utterances — rather than streaming partials — keeps the
/// stored text stable and lets the live overlay update by simply re-rendering
/// `formatted` whenever a new segment is appended.
nonisolated final class MeetingTranscript {

    struct Segment: Equatable {
        let speaker: String
        let text: String
        let timestamp: Date
    }

    private let lock = NSLock()
    private var _segments: [Segment] = []

    var segments: [Segment] { lock.withLock { _segments } }

    /// Snapshot of the transcript formatted as `Speaker: text` lines in
    /// chronological order. Empty when no segments have been appended yet.
    var formatted: String {
        segments.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
    }

    /// Appends an utterance. Trims surrounding whitespace and skips empty or
    /// whitespace-only text so the rendered transcript stays readable.
    func append(speaker: String, text: String, at time: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.withLock {
            _segments.append(Segment(speaker: speaker, text: trimmed, timestamp: time))
        }
    }

    /// Resets the transcript. Called at the start of a new meeting so previous
    /// content doesn't leak into the next recording session.
    func clear() {
        lock.withLock { _segments.removeAll() }
    }
}
