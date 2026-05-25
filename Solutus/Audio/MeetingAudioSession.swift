import Foundation

/// Coordinates the two audio sources of an HR meeting — the microphone (your
/// voice) and system audio (the recruiter's voice) — so they start and stop
/// together. Both sources are injected so the coordination logic can be tested
/// with fakes, without real hardware or permissions.
nonisolated final class MeetingAudioSession {

    private let microphone: AudioSource
    private let systemAudio: AudioSource

    init(
        microphone: AudioSource = MicrophoneCapture(),
        systemAudio: AudioSource = SystemAudioCapture()
    ) {
        self.microphone = microphone
        self.systemAudio = systemAudio
    }

    /// `true` while at least one source is capturing.
    var isRecording: Bool { microphone.isRecording || systemAudio.isRecording }

    var microphoneBufferCount: Int { microphone.bufferCount }
    var systemAudioBufferCount: Int { systemAudio.bufferCount }

    /// Starts both sources. If the system-audio source fails to start, the
    /// microphone is rolled back so we never end up half-recording.
    func start() async throws {
        guard !isRecording else { return }

        try await microphone.start()
        do {
            try await systemAudio.start()
        } catch {
            await microphone.stop()
            throw error
        }
    }

    /// Stops both sources. Best-effort and safe to call when idle.
    func stop() async {
        await microphone.stop()
        await systemAudio.stop()
    }
}
