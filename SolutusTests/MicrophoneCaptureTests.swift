import AVFoundation
import Testing
@testable import Solutus

/// Covers the hardware-independent surface of `MicrophoneCapture`: the pure
/// authorization mapping and the idle-state guarantees. Starting the engine
/// needs a real input device + permission, so it is exercised manually, not here.
@Suite("MicrophoneCapture")
struct MicrophoneCaptureTests {

    // MARK: - Authorization mapping (pure)

    @Test("authorized status maps to .authorized")
    func authorizedMapsToAuthorized() {
        #expect(MicrophoneCapture.access(for: .authorized) == .authorized)
    }

    @Test("denied status maps to .denied")
    func deniedMapsToDenied() {
        #expect(MicrophoneCapture.access(for: .denied) == .denied)
    }

    @Test("restricted status maps to .denied (user cannot grant it)")
    func restrictedMapsToDenied() {
        #expect(MicrophoneCapture.access(for: .restricted) == .denied)
    }

    @Test("notDetermined status maps to .undetermined (should prompt)")
    func notDeterminedMapsToUndetermined() {
        #expect(MicrophoneCapture.access(for: .notDetermined) == .undetermined)
    }

    // MARK: - Idle-state guarantees

    @Test("a fresh capture is idle with no buffers")
    func freshCaptureIsIdle() {
        let capture = MicrophoneCapture()
        #expect(capture.isRecording == false)
        #expect(capture.bufferCount == 0)
    }

    @Test("stop before start is a safe no-op")
    func stopBeforeStartIsSafe() {
        let capture = MicrophoneCapture()
        capture.stop()
        #expect(capture.isRecording == false)
    }
}
