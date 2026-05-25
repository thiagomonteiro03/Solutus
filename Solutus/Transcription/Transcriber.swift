import AVFoundation
import Speech

/// Streams audio buffers from a single source into `SFSpeechRecognizer` and
/// forwards the recognized text. One `Transcriber` per speaker — the HR
/// Meeting Helper uses two (you + the other party) so transcripts stay labeled.
///
/// Card 4 scope: produce a live stream of recognized text per source. Persisting
/// and summarizing the transcript lands in the next card.
nonisolated final class Transcriber {

    /// The speech-recognition authorization decision the app cares about. Pure
    /// and `Equatable` so the mapping can be unit-tested without the system
    /// permission dialog.
    enum Access: Equatable {
        case authorized
        case denied
        case undetermined
    }

    enum TranscriberError: Error {
        case recognizerUnavailable
    }

    /// User-visible label prepended to each transcript line (e.g. "Você").
    let label: String

    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Tracks whether the caller still wants us recording. SFSpeech ends the
    // session on its own (e.g. "No speech detected" after silence, or after
    // ~1 minute), so we restart the recognition task whenever that happens and
    // `isActive` is still true — until `stop()` flips it back to false.
    private var isActive = false

    // Log the audio format once per buffer kind so we can tell whether the
    // recognizer is being fed something it can decode without flooding the
    // console on every frame.
    private var didLogPCMFormat = false
    private var didLogSampleFormat = false

    /// Called whenever the recognizer emits a (partial or final) result. Invoked
    /// on the recognizer's internal queue, not the main actor.
    var onText: ((_ text: String, _ isFinal: Bool) -> Void)?

    init(label: String, locale: Locale = .current) {
        self.label = label
        self.recognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
            ?? SFSpeechRecognizer()
    }

    /// Maps the system authorization status to the app's access decision.
    /// `restricted` is treated as `denied` since the user cannot grant it.
    static func access(for status: SFSpeechRecognizerAuthorizationStatus) -> Access {
        switch status {
        case .authorized:          return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined:       return .undetermined
        @unknown default:          return .denied
        }
    }

    /// Prompts the user for speech-recognition access if needed and returns the
    /// resulting decision.
    static func requestAccess() async -> Access {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: Self.access(for: status))
            }
        }
    }

    /// Starts a recognition task. No-op if already running. Throws if the
    /// recognizer is unavailable for the chosen locale.
    func start() throws {
        guard !isActive else { return }
        try startRecognition(isInitial: true)
        isActive = true
    }

    /// Builds a fresh recognition request + task. Called by `start()` and by
    /// the task completion handler to keep the session going across the silence
    /// timeouts SFSpeech enforces.
    private func startRecognition(isInitial: Bool) throws {
        guard let recognizer, recognizer.isAvailable else {
            print("[\(label)] recognizer unavailable (locale=\(recognizer?.locale.identifier ?? "nil"))")
            throw TranscriberError.recognizerUnavailable
        }

        if isInitial {
            print("[\(label)] starting — locale=\(recognizer.locale.identifier) onDevice=\(recognizer.supportsOnDeviceRecognition)")
            didLogPCMFormat = false
            didLogSampleFormat = false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Long-form continuous speech, tolerant of brief pauses — matches an
        // HR-meeting conversation better than the default generic hint.
        request.taskHint = .dictation
        // We intentionally do NOT force on-device recognition: in practice
        // on-device en-US has been bailing with "No speech detected" within
        // ~500 ms while server-based handles the same audio fine.

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.onText?(result.bestTranscription.formattedString, result.isFinal)
            }
            let ended = error != nil || (result?.isFinal ?? false)
            guard ended else { return }

            self.task = nil
            self.request = nil

            // Only restart if the caller still wants us recording. When `stop()`
            // ran first, `isActive` is already false and we let the session die.
            guard self.isActive else { return }

            // SFSpeech ends sessions on every silence pause with "No speech
            // detected" — expected during a meeting, no point spamming the
            // console. Anything else is worth surfacing.
            if let error, !error.localizedDescription.contains("No speech detected") {
                print("[\(self.label)] recognition session ended (\(error.localizedDescription)) — restarting")
            }

            // Defer the restart so SFSpeech can fully tear down the previous
            // session before we ask it to start a new one. Synchronous
            // recursion from inside the callback has shown odd states in
            // practice (recognizer "starts" but never emits partials).
            let label = self.label
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.isActive else { return }
                do {
                    try self.startRecognition(isInitial: false)
                } catch {
                    print("[\(label)] could not restart recognition: \(error.localizedDescription)")
                }
            }
        }
        self.request = request
    }

    /// Appends a PCM buffer from the microphone tap.
    func append(_ buffer: AVAudioPCMBuffer) {
        if !didLogPCMFormat {
            didLogPCMFormat = true
            let format = buffer.format
            print("[\(label)] first PCM buffer — sampleRate=\(format.sampleRate) channels=\(format.channelCount) commonFormat=\(format.commonFormat.rawValue)")
        }
        request?.append(buffer)
    }

    /// Appends a sample buffer from a ScreenCaptureKit audio stream.
    func append(_ sampleBuffer: CMSampleBuffer) {
        if !didLogSampleFormat {
            didLogSampleFormat = true
            if let desc = CMSampleBufferGetFormatDescription(sampleBuffer),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                print("[\(label)] first sample buffer — sampleRate=\(asbd.mSampleRate) channels=\(asbd.mChannelsPerFrame) bitsPerChannel=\(asbd.mBitsPerChannel)")
            } else {
                print("[\(label)] first sample buffer — no format description")
            }
        }
        request?.appendAudioSampleBuffer(sampleBuffer)
    }

    /// Ends the audio stream and cancels the recognition task. Safe to call
    /// when idle. Flipping `isActive` BEFORE cancelling prevents the completion
    /// handler from restarting the session on the way out.
    func stop() {
        isActive = false
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }
}
