import Foundation
import Testing
@testable import Solutus

/// `MeetingTranscript` is a pure store with no hardware or recognizer
/// dependencies, so it is exercised exhaustively here.
@Suite("MeetingTranscript")
struct MeetingTranscriptTests {

    @Test("a fresh transcript is empty")
    func freshTranscriptIsEmpty() {
        let transcript = MeetingTranscript()
        #expect(transcript.segments.isEmpty)
        #expect(transcript.formatted.isEmpty)
    }

    @Test("appended segments keep their text and speaker in order")
    func appendsPreserveOrderAndContent() {
        let transcript = MeetingTranscript()
        transcript.append(speaker: "Você", text: "hello")
        transcript.append(speaker: "Outra parte", text: "hi there")
        transcript.append(speaker: "Você", text: "let's start")

        let segments = transcript.segments
        #expect(segments.count == 3)
        #expect(segments[0].speaker == "Você")
        #expect(segments[0].text == "hello")
        #expect(segments[1].speaker == "Outra parte")
        #expect(segments[2].text == "let's start")
    }

    @Test("formatted renders one labeled line per segment")
    func formattedRendersSegments() {
        let transcript = MeetingTranscript()
        transcript.append(speaker: "Você", text: "hello")
        transcript.append(speaker: "Outra parte", text: "hi there")

        #expect(transcript.formatted == "Você: hello\nOutra parte: hi there")
    }

    @Test("empty and whitespace-only utterances are skipped")
    func whitespaceUtterancesAreSkipped() {
        let transcript = MeetingTranscript()
        transcript.append(speaker: "Você", text: "")
        transcript.append(speaker: "Você", text: "   ")
        transcript.append(speaker: "Você", text: "\n\t")

        #expect(transcript.segments.isEmpty)
        #expect(transcript.formatted.isEmpty)
    }

    @Test("surrounding whitespace is trimmed before storing")
    func surroundingWhitespaceIsTrimmed() {
        let transcript = MeetingTranscript()
        transcript.append(speaker: "Você", text: "  hello world  ")

        #expect(transcript.segments.first?.text == "hello world")
    }

    @Test("clear empties the transcript")
    func clearEmptiesEverything() {
        let transcript = MeetingTranscript()
        transcript.append(speaker: "Você", text: "hello")
        transcript.append(speaker: "Outra parte", text: "hi")

        transcript.clear()

        #expect(transcript.segments.isEmpty)
        #expect(transcript.formatted.isEmpty)
    }

    @Test("timestamps default to now but accept an injected value for tests")
    func timestampInjection() {
        let transcript = MeetingTranscript()
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        transcript.append(speaker: "Você", text: "hello", at: fixed)

        #expect(transcript.segments.first?.timestamp == fixed)
    }
}
