import Testing
@testable import Solutus

/// `SystemAudioCapture` drives ScreenCaptureKit, which needs Screen Recording
/// permission and a display, so starting it is verified manually. These tests
/// cover the hardware-independent idle-state guarantees.
@Suite("SystemAudioCapture")
struct SystemAudioCaptureTests {

    @Test("a fresh capture is idle with no buffers")
    func freshCaptureIsIdle() {
        let capture = SystemAudioCapture()
        #expect(capture.isRecording == false)
        #expect(capture.bufferCount == 0)
    }

    @Test("stop before start is a safe no-op")
    func stopBeforeStartIsSafe() async {
        let capture = SystemAudioCapture()
        await capture.stop()
        #expect(capture.isRecording == false)
    }
}
