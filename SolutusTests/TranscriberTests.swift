import Speech
import Testing
@testable import Solutus

/// `Transcriber` drives `SFSpeechRecognizer`, which needs Speech Recognition
/// permission, hardware audio, and the locale to be available — so a full
/// start/stop cycle is verified manually. These tests cover the pure
/// authorization-status mapping and the basic label propagation.
@Suite("Transcriber")
struct TranscriberTests {

    // MARK: - Authorization mapping (pure)

    @Test("authorized status maps to .authorized")
    func authorizedMapsToAuthorized() {
        #expect(Transcriber.access(for: .authorized) == .authorized)
    }

    @Test("denied status maps to .denied")
    func deniedMapsToDenied() {
        #expect(Transcriber.access(for: .denied) == .denied)
    }

    @Test("restricted status maps to .denied (user cannot grant it)")
    func restrictedMapsToDenied() {
        #expect(Transcriber.access(for: .restricted) == .denied)
    }

    @Test("notDetermined status maps to .undetermined (should prompt)")
    func notDeterminedMapsToUndetermined() {
        #expect(Transcriber.access(for: .notDetermined) == .undetermined)
    }

    // MARK: - Label

    @Test("label is propagated unchanged so the UI can prefix each line")
    func labelIsPropagated() {
        let transcriber = Transcriber(label: "Você")
        #expect(transcriber.label == "Você")
    }

    @Test("stop before start is a safe no-op")
    func stopBeforeStartIsSafe() {
        let transcriber = Transcriber(label: "Outra parte")
        transcriber.stop()
        // No assertion needed — surviving the call without crashing is the
        // contract. Mirrors the idle-state guarantees of the audio captures.
    }
}
