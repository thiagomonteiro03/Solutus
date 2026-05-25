import Foundation

/// Wires the two `Transcriber`s of an HR meeting (you + the other party) to the
/// raw audio sources, so each speaker has its own labeled transcript stream.
///
/// Holds concrete references to `MicrophoneCapture` and `SystemAudioCapture`
/// because the two sources expose buffer callbacks with different types
/// (`AVAudioPCMBuffer` vs `CMSampleBuffer`), which doesn't fit cleanly behind
/// the `AudioSource` protocol.
nonisolated final class MeetingTranscriber {

    private let microphone: MicrophoneCapture
    private let systemAudio: SystemAudioCapture

    private let micTranscriber: Transcriber
    private let systemTranscriber: Transcriber

    // Guards the staggered system-audio start against a `stop()` that lands
    // before the delayed dispatch fires.
    private var isStopRequested = false

    /// Forwarded from each underlying `Transcriber.onText`. Useful when a UI
    /// layer wants to surface the live transcript instead of only logging it.
    var onText: ((_ label: String, _ text: String, _ isFinal: Bool) -> Void)?

    init(
        microphone: MicrophoneCapture,
        systemAudio: SystemAudioCapture,
        locale: Locale = .current
    ) {
        self.microphone = microphone
        self.systemAudio = systemAudio
        self.micTranscriber = Transcriber(label: "Você", locale: locale)
        self.systemTranscriber = Transcriber(label: "Outra parte", locale: locale)
    }

    /// Starts both recognition tasks and wires the audio sources' buffer
    /// callbacks. Must be called before `MeetingAudioSession.start()` so that
    /// no audio frame is dropped before the recognizers are ready.
    ///
    /// The two recognizers are started **staggered** by ~2 s: in practice,
    /// kicking both `SFSpeechRecognizer`s off at the same time made both die
    /// with "No speech detected" inside 300 ms. Letting the microphone settle
    /// first and bringing the system-audio one in afterwards is what allowed
    /// either to produce text reliably.
    func start() throws {
        isStopRequested = false

        try micTranscriber.start()

        microphone.onBuffer = { [weak self] buffer in
            self?.micTranscriber.append(buffer)
        }
        micTranscriber.onText = { [weak self] text, isFinal in
            guard let self else { return }
            print("[\(self.micTranscriber.label)] \(text)")
            self.onText?(self.micTranscriber.label, text, isFinal)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !self.isStopRequested else { return }
            do {
                try self.systemTranscriber.start()
                self.systemAudio.onBuffer = { [weak self] sample in
                    self?.systemTranscriber.append(sample)
                }
                self.systemTranscriber.onText = { [weak self] text, isFinal in
                    guard let self else { return }
                    print("[\(self.systemTranscriber.label)] \(text)")
                    self.onText?(self.systemTranscriber.label, text, isFinal)
                }
                print("System-audio transcriber started (staggered after mic).")
            } catch {
                print("System-audio transcriber failed to start: \(error.localizedDescription)")
            }
        }
    }

    /// Disconnects the buffer callbacks and stops both recognition tasks.
    /// Flipping `isStopRequested` first prevents a still-pending staggered
    /// start from spinning up the system transcriber after we've been stopped.
    func stop() {
        isStopRequested = true
        microphone.onBuffer = nil
        systemAudio.onBuffer = nil
        micTranscriber.stop()
        systemTranscriber.stop()
    }
}
