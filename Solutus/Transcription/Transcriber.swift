import AVFoundation
import Speech

/// Streams audio buffers from a single source into `SFSpeechRecognizer` and
/// forwards the recognized text. One `Transcriber` per speaker — the HR
/// Meeting Helper uses two (you + the other party) so transcripts stay labeled.
///
/// SFSpeech ends a session on silence ("No speech detected") and after ~1 min,
/// so we transparently restart it. The restart can't be instantaneous (the
/// recognizer needs time to tear down), so audio that arrives during the gap is
/// stashed and replayed into the next session — otherwise the start of whatever
/// is said right after a pause gets dropped.
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

    // Shared mutable state, guarded by `lock` because audio buffers arrive on
    // the capture threads while the recognition callback and restart run on
    // their own queues.
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isActive = false
    private var lastPartialText = ""

    // Monotonic id for the current recognition session. SFSpeech can invoke a
    // task's completion handler more than once (e.g. a final result followed by
    // a cancellation), and each "ended" callback used to schedule its own
    // restart — spawning duplicate concurrent tasks that compounded until the
    // recognizer saturated and went deaf. Every session captures its generation;
    // only the first "ended" callback whose generation still matches gets to
    // restart, and it bumps the counter so duplicates and stale callbacks are
    // ignored.
    private var generation = 0

    // Audio captured while there is no live `request` (the restart gap). Replayed
    // into the next session so no speech is lost across a restart. Capped so a
    // long silence can't grow it without bound.
    private var pendingPCM: [AVAudioPCMBuffer] = []
    private var pendingSamples: [CMSampleBuffer] = []
    private let maxPendingBuffers = 80

    /// Called whenever the recognizer emits a (partial or final) result. Invoked
    /// on the recognizer's internal queue, not the main actor.
    var onText: ((_ text: String, _ isFinal: Bool) -> Void)?

    /// Called exactly once per closed utterance — either because SFSpeech
    /// reported `isFinal == true`, or because the session ended (silence
    /// timeout / user stop) while a partial was in progress. Consumers use this
    /// to commit a stable line to the meeting transcript.
    var onUtteranceFinalized: ((_ text: String) -> Void)?

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
        let alreadyActive = lock.withLock { isActive }
        guard !alreadyActive else { return }
        try startRecognition(isInitial: true)
        lock.withLock { isActive = true }
    }

    /// Builds a fresh recognition request + task and replays any audio captured
    /// during the restart gap. Called by `start()` and by the task completion
    /// handler to keep the session going across SFSpeech's silence timeouts.
    private func startRecognition(isInitial: Bool) throws {
        guard let recognizer, recognizer.isAvailable else {
            print("[\(label)] recognizer unavailable (locale=\(recognizer?.locale.identifier ?? "nil"))")
            throw TranscriberError.recognizerUnavailable
        }

        if isInitial {
            print("[\(label)] starting — locale=\(recognizer.locale.identifier) onDevice=\(recognizer.supportsOnDeviceRecognition)")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Long-form continuous speech, tolerant of brief pauses — matches an
        // HR-meeting conversation better than the default generic hint.
        request.taskHint = .dictation
        // On-device recognition is the right tool for a long meeting: the
        // server path caps sessions at ~1 minute and finalizes eagerly on every
        // pause, which fragments continuous speech into choppy pieces. The
        // on-device model has no such cap and is built for live dictation. The
        // earlier "No speech detected in 500 ms" came from two recognizers
        // starting at once, which the 2 s stagger now prevents.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Captured by the completion handler so it can tell whether it still
        // owns the current session (see `generation`).
        let myGeneration = lock.withLock { generation }

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            // Drop callbacks from a session that has already ended or been
            // superseded by a restart — they must not touch live state.
            if self.lock.withLock({ self.generation != myGeneration }) { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.lock.withLock { self.lastPartialText = text }
                self.onText?(text, result.isFinal)
                if result.isFinal {
                    self.commitPendingUtterance()
                }
            }
            let ended = error != nil || (result?.isFinal ?? false)
            guard ended else { return }

            // Session ended via error (typically "No speech detected") with a
            // partial in progress — commit whatever we got before tearing down.
            if error != nil {
                self.commitPendingUtterance()
            }

            // Claim the end exactly once: bump the generation so any duplicate
            // callback for this same session is ignored above, and tear down.
            let stillActive: Bool = self.lock.withLock {
                guard self.generation == myGeneration else { return false }
                self.generation += 1
                self.task = nil
                self.request = nil
                return self.isActive
            }

            // Only restart if we won the claim AND the caller still wants us
            // recording. When `stop()` ran first, `isActive` is already false.
            guard stillActive else { return }

            // SFSpeech ends sessions on every silence pause with "No speech
            // detected" — expected during a meeting, no point spamming the
            // console. Anything else is worth surfacing.
            if let error, !error.localizedDescription.contains("No speech detected") {
                print("[\(self.label)] recognition session ended (\(error.localizedDescription)) — restarting")
            }

            // Defer the restart so SFSpeech can fully tear down the previous
            // session before we ask it to start a new one. Synchronous
            // recursion from inside the callback has shown odd states in
            // practice (recognizer "starts" but never emits partials). Audio
            // arriving during this gap is stashed and replayed below.
            let label = self.label
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.lock.withLock({ self.isActive }) else { return }
                do {
                    try self.startRecognition(isInitial: false)
                } catch {
                    print("[\(label)] could not restart recognition: \(error.localizedDescription)")
                }
            }
        }

        // Publish the new request and flush the gap audio into it atomically so
        // an append racing in can't slip between the two.
        lock.withLock {
            self.request = request
            self.task = task
            for buffer in pendingPCM { request.append(buffer) }
            for sample in pendingSamples { request.appendAudioSampleBuffer(sample) }
            pendingPCM.removeAll()
            pendingSamples.removeAll()
        }
    }

    /// Appends a PCM buffer from the microphone tap.
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            if let request {
                request.append(buffer)
            } else if isActive {
                pendingPCM.append(buffer)
                if pendingPCM.count > maxPendingBuffers { pendingPCM.removeFirst() }
            }
        }
    }

    /// Appends a sample buffer from a ScreenCaptureKit audio stream.
    func append(_ sampleBuffer: CMSampleBuffer) {
        lock.withLock {
            if let request {
                request.appendAudioSampleBuffer(sampleBuffer)
            } else if isActive {
                pendingSamples.append(sampleBuffer)
                if pendingSamples.count > maxPendingBuffers { pendingSamples.removeFirst() }
            }
        }
    }

    /// Ends the audio stream and cancels the recognition task. Safe to call
    /// when idle. Flipping `isActive` BEFORE cancelling prevents the completion
    /// handler from restarting the session on the way out.
    func stop() {
        let (oldRequest, oldTask) = lock.withLock { () -> (SFSpeechAudioBufferRecognitionRequest?, SFSpeechRecognitionTask?) in
            isActive = false
            generation += 1   // invalidate any in-flight session callbacks
            let r = request
            let t = task
            request = nil
            task = nil
            pendingPCM.removeAll()
            pendingSamples.removeAll()
            return (r, t)
        }
        oldRequest?.endAudio()
        oldTask?.cancel()
        // The cancelled task may not fire its completion handler in time, so
        // commit any partial we'd otherwise lose at the end of the meeting.
        commitPendingUtterance()
    }

    /// Emits `onUtteranceFinalized` with the last partial and clears it. No-op
    /// when there's nothing pending.
    private func commitPendingUtterance() {
        let pending: String = lock.withLock {
            let value = lastPartialText
            lastPartialText = ""
            return value
        }
        let trimmed = pending.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onUtteranceFinalized?(trimmed)
    }
}
