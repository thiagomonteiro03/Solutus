import AVFoundation

/// Captures microphone audio with `AVAudioEngine`.
///
/// Card 2 scope: prove that audio frames flow while recording is active. Each
/// captured PCM buffer is forwarded to `onBuffer` so a later card can feed it
/// into speech recognition; for now the only observable effect is `bufferCount`.
nonisolated final class MicrophoneCapture: AudioSource {

    /// The microphone authorization decision the app cares about. Pure and
    /// `Equatable` so it can be unit-tested without touching the hardware or the
    /// system permission dialog.
    enum Access: Equatable {
        case authorized
        case denied
        case undetermined
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var _isRecording = false
    private var _bufferCount = 0

    /// Forwards each captured PCM buffer. Invoked on the audio render thread —
    /// consumers must not touch main-actor state synchronously from here.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    var isRecording: Bool { lock.withLock { _isRecording } }

    /// Number of buffers received since the last `start()`.
    var bufferCount: Int { lock.withLock { _bufferCount } }

    /// Maps the system authorization status to the app's access decision.
    /// `restricted` is treated as `denied` since the user cannot grant it.
    static func access(for status: AVAuthorizationStatus) -> Access {
        switch status {
        case .authorized:          return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined:       return .undetermined
        @unknown default:          return .denied
        }
    }

    /// Starts capturing. No-op if already recording. Throws if the engine fails
    /// to start (e.g. no input device available).
    func start() async throws {
        guard !isRecording else { return }

        lock.withLock { _bufferCount = 0 }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.withLock { self._bufferCount += 1 }
            self.onBuffer?(buffer)
        }

        engine.prepare()
        try engine.start()
        lock.withLock { _isRecording = true }
    }

    /// Stops capturing and removes the tap. Safe to call when idle.
    func stop() async {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.withLock { _isRecording = false }
    }
}
