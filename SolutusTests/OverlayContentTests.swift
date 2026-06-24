import Testing
@testable import Solutus

/// `OverlayContent` is the state that drives `OverlayView`.
/// Verifies pattern-matching behavior and the associated payloads.
@Suite("OverlayContent")
struct OverlayContentTests {

    @Test("captured preserves count")
    func capturedCarriesCount() {
        let content = OverlayContent.captured(count: 3)
        guard case .captured(let count) = content else {
            Issue.record("expected .captured")
            return
        }
        #expect(count == 3)
    }

    @Test("solution preserves raw text (markdown-aware)")
    func solutionCarriesText() {
        let payload = "Use a hash map.\n```swift\nfunc x() {}\n```"
        let content = OverlayContent.solution(text: payload, source: .algorithmHelper)
        guard case .solution(let text, _) = content else {
            Issue.record("expected .solution")
            return
        }
        #expect(text == payload)
    }

    @Test("solution preserves the helper source (Android Helper)")
    func solutionCarriesAndroidSource() {
        let content = OverlayContent.solution(text: "irrelevant", source: .androidHelper)
        guard case .solution(_, let source) = content else {
            Issue.record("expected .solution")
            return
        }
        #expect(source == .androidHelper)
    }

    @Test("solution preserves the helper source (Algorithm Helper)")
    func solutionCarriesAlgorithmSource() {
        let content = OverlayContent.solution(text: "irrelevant", source: .algorithmHelper)
        guard case .solution(_, let source) = content else {
            Issue.record("expected .solution")
            return
        }
        #expect(source == .algorithmHelper)
    }

    @Test("error preserves the message")
    func errorCarriesMessage() {
        let content = OverlayContent.error("something went wrong")
        guard case .error(let message) = content else {
            Issue.record("expected .error")
            return
        }
        #expect(message == "something went wrong")
    }

    @Test("loading has no payload")
    func loadingHasNoPayload() {
        let content = OverlayContent.loading
        if case .loading = content {
            // ok
        } else {
            Issue.record("expected .loading")
        }
    }

    @Test("recording preserves the live transcript text")
    func recordingCarriesTranscript() {
        let payload = "Você: hello\nOutra parte: hi"
        let content = OverlayContent.recording(transcript: payload)
        guard case .recording(let transcript) = content else {
            Issue.record("expected .recording")
            return
        }
        #expect(transcript == payload)
    }

    @Test("recording accepts an empty transcript (awaiting first utterance)")
    func recordingAllowsEmptyTranscript() {
        let content = OverlayContent.recording(transcript: "")
        guard case .recording(let transcript) = content else {
            Issue.record("expected .recording")
            return
        }
        #expect(transcript.isEmpty)
    }

    @Test("all cases are distinguishable via pattern-matching")
    func casesAreDistinguishable() {
        let items: [OverlayContent] = [
            .captured(count: 1),
            .loading,
            .recording(transcript: "live"),
            .solution(text: "x", source: .algorithmHelper),
            .error("y")
        ]
        var capturedHits = 0
        var loadingHits = 0
        var recordingHits = 0
        var solutionHits = 0
        var errorHits = 0

        for item in items {
            switch item {
            case .captured:  capturedHits  += 1
            case .loading:   loadingHits   += 1
            case .recording: recordingHits += 1
            case .solution:  solutionHits  += 1
            case .error:     errorHits     += 1
            }
        }

        #expect(capturedHits  == 1)
        #expect(loadingHits   == 1)
        #expect(recordingHits == 1)
        #expect(solutionHits  == 1)
        #expect(errorHits     == 1)
    }
}

/// Covers the `HelperKind` enum used as `source` in `.solution` and as the
/// dispatch key in `AppDelegate` / `LLMService`.
@Suite("HelperKind")
struct HelperKindTests {

    @Test("displayName matches the user-facing labels expected by the overlay")
    func displayNameIsExact() {
        #expect(HelperKind.algorithmHelper.displayName == "Algorithm Helper")
        #expect(HelperKind.androidHelper.displayName   == "Android Helper")
    }

    @Test("equatable allows pattern matching across queues and overlay state")
    func equatable() {
        #expect(HelperKind.algorithmHelper == .algorithmHelper)
        #expect(HelperKind.androidHelper   == .androidHelper)
        #expect(HelperKind.algorithmHelper != .androidHelper)
    }
}
