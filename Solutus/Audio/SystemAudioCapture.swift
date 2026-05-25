import ScreenCaptureKit
import CoreMedia

/// Captures system audio (what plays through the speakers — e.g. the recruiter's
/// voice in a call) via ScreenCaptureKit's `SCStream`. Reuses the Screen
/// Recording permission already requested by the screenshot feature.
///
/// Card 3 scope: prove the audio frames flow alongside the microphone. The
/// `CMSampleBuffer`s are forwarded to `onBuffer` for the upcoming transcription
/// card; for now the only observable effect is `bufferCount`.
nonisolated final class SystemAudioCapture: NSObject, AudioSource {

    enum CaptureError: Error {
        case noDisplay
    }

    private var stream: SCStream?
    private let lock = NSLock()
    private var _isRecording = false
    private var _bufferCount = 0
    private let sampleQueue = DispatchQueue(label: "com.montway.Solutus.systemAudio")

    /// Forwards each captured audio sample buffer. Invoked on `sampleQueue` —
    /// consumers must not touch main-actor state synchronously from here.
    var onBuffer: ((CMSampleBuffer) -> Void)?

    var isRecording: Bool { lock.withLock { _isRecording } }
    var bufferCount: Int { lock.withLock { _bufferCount } }

    /// Starts capturing system audio. No-op if already recording. The first call
    /// triggers the Screen Recording permission dialog. Throws if no display is
    /// available or the stream fails to start.
    func start() async throws {
        guard !isRecording else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        // Don't record our own overlay/UI sounds back into the transcript.
        config.excludesCurrentProcessAudio = true
        // Video is required by the stream but unused here — keep it tiny and slow.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()

        self.stream = stream
        lock.withLock {
            _isRecording = true
            _bufferCount = 0
        }
    }

    /// Stops capturing and tears down the stream. Safe to call when idle.
    func stop() async {
        guard isRecording else { return }
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        lock.withLock { _isRecording = false }
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio else { return }
        lock.withLock { _bufferCount += 1 }
        onBuffer?(sampleBuffer)
    }
}
