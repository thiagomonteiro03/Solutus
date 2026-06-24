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

    // Software gain applied before forwarding buffers. On many Mac built-in
    // mics even a 100 % input slider lands SFSpeech around ~30 % of full scale,
    // well below its detection sweet spot — boosting by 2.5× brings normal
    // speech into the 60–80 % range. Clipped to ±1.0 to avoid harsh
    // distortion on peaks.
    private let gain: Float = 2.5

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
            self.applyGain(buffer)
            self.lock.withLock { self._bufferCount += 1 }
            self.onBuffer?(buffer)
        }

        engine.prepare()
        try engine.start()
        lock.withLock { _isRecording = true }
    }

    /// Multiplies each sample by `gain` in place and hard-clamps to ±1.0 so
    /// peaks don't fold over into the negative half (which sounds distorted to
    /// the recognizer and the user). Cheap enough to run inside the tap.
    private func applyGain(_ buffer: AVAudioPCMBuffer) {
        guard gain != 1.0,
              let channels = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        for c in 0..<channelCount {
            let channel = channels[c]
            for i in 0..<frameLength {
                let scaled = channel[i] * gain
                channel[i] = min(1.0, max(-1.0, scaled))
            }
        }
    }

    /// Stops capturing and removes the tap. Safe to call when idle.
    func stop() async {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.withLock { _isRecording = false }
    }
}
