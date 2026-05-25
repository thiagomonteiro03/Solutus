import Foundation

/// A start/stop audio source coordinated by `MeetingAudioSession`.
///
/// Abstracted behind a protocol so the session can be unit-tested with fakes,
/// without touching real hardware or requiring microphone / screen-recording
/// permissions. `start()`/`stop()` are async because the system-audio source
/// (ScreenCaptureKit) starts and stops asynchronously.
nonisolated protocol AudioSource: AnyObject {
    var isRecording: Bool { get }
    /// Number of buffers received since the last `start()`. Used as a
    /// proof-of-capture signal until transcription consumes the buffers.
    var bufferCount: Int { get }
    func start() async throws
    func stop() async
}
