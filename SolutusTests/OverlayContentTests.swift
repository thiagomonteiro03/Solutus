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
        let content = OverlayContent.solution(payload)
        guard case .solution(let text) = content else {
            Issue.record("expected .solution")
            return
        }
        #expect(text == payload)
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

    @Test("all cases are distinguishable via pattern-matching")
    func casesAreDistinguishable() {
        let items: [OverlayContent] = [
            .captured(count: 1),
            .loading,
            .solution("x"),
            .error("y")
        ]
        var capturedHits = 0
        var loadingHits = 0
        var solutionHits = 0
        var errorHits = 0

        for item in items {
            switch item {
            case .captured:  capturedHits += 1
            case .loading:   loadingHits  += 1
            case .solution:  solutionHits += 1
            case .error:     errorHits    += 1
            }
        }

        #expect(capturedHits == 1)
        #expect(loadingHits  == 1)
        #expect(solutionHits == 1)
        #expect(errorHits    == 1)
    }
}
