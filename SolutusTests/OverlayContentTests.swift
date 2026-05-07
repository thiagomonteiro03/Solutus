import Testing
@testable import Solutus

/// `OverlayContent` is the state that drives `OverlayView`.
/// Verifies pattern-matching behavior and the associated payloads.
@Suite("OverlayContent")
struct OverlayContentTests {

    @Test("captured preserva count")
    func capturedCarriesCount() {
        let content = OverlayContent.captured(count: 3)
        guard case .captured(let count) = content else {
            Issue.record("esperava .captured")
            return
        }
        #expect(count == 3)
    }

    @Test("solution preserva o texto cru (markdown-aware)")
    func solutionCarriesText() {
        let payload = "Use um hash map.\n```swift\nfunc x() {}\n```"
        let content = OverlayContent.solution(payload)
        guard case .solution(let text) = content else {
            Issue.record("esperava .solution")
            return
        }
        #expect(text == payload)
    }

    @Test("error preserva a mensagem")
    func errorCarriesMessage() {
        let content = OverlayContent.error("algo deu errado")
        guard case .error(let message) = content else {
            Issue.record("esperava .error")
            return
        }
        #expect(message == "algo deu errado")
    }

    @Test("loading não tem payload")
    func loadingHasNoPayload() {
        let content = OverlayContent.loading
        if case .loading = content {
            // ok
        } else {
            Issue.record("esperava .loading")
        }
    }

    @Test("cases distintos são distinguíveis por pattern-matching")
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
