import Testing
@testable import Solutus

/// Verifies that `MeetingAudioSession` starts and stops both audio sources
/// together, and rolls back the microphone if system audio fails to start.
/// Uses fake sources so no real hardware or permissions are involved.
@Suite("MeetingAudioSession")
struct MeetingAudioSessionTests {

    @Test("start() starts both sources and reports recording")
    func startStartsBothSources() async throws {
        let mic = FakeAudioSource()
        let system = FakeAudioSource()
        let session = MeetingAudioSession(microphone: mic, systemAudio: system)

        try await session.start()

        #expect(mic.startCalls == 1)
        #expect(system.startCalls == 1)
        #expect(session.isRecording)
    }

    @Test("stop() stops both sources")
    func stopStopsBothSources() async throws {
        let mic = FakeAudioSource()
        let system = FakeAudioSource()
        let session = MeetingAudioSession(microphone: mic, systemAudio: system)

        try await session.start()
        await session.stop()

        #expect(mic.stopCalls == 1)
        #expect(system.stopCalls == 1)
        #expect(session.isRecording == false)
    }

    @Test("system-audio failure rolls back the microphone")
    func systemFailureRollsBackMicrophone() async {
        let mic = FakeAudioSource()
        let system = FakeAudioSource()
        system.startError = FakeError.boom
        let session = MeetingAudioSession(microphone: mic, systemAudio: system)

        await #expect(throws: FakeError.self) {
            try await session.start()
        }

        // Microphone was started, then rolled back — never left recording.
        #expect(mic.startCalls == 1)
        #expect(mic.stopCalls == 1)
        #expect(session.isRecording == false)
    }

    @Test("start() is a no-op when already recording")
    func startIsNoOpWhenRecording() async throws {
        let mic = FakeAudioSource()
        let system = FakeAudioSource()
        let session = MeetingAudioSession(microphone: mic, systemAudio: system)

        try await session.start()
        try await session.start()

        #expect(mic.startCalls == 1)
        #expect(system.startCalls == 1)
    }

    @Test("buffer counts are forwarded from the underlying sources")
    func bufferCountsAreForwarded() {
        let mic = FakeAudioSource()
        let system = FakeAudioSource()
        mic.bufferCount = 7
        system.bufferCount = 3
        let session = MeetingAudioSession(microphone: mic, systemAudio: system)

        #expect(session.microphoneBufferCount == 7)
        #expect(session.systemAudioBufferCount == 3)
    }
}

// MARK: - Test doubles

private enum FakeError: Error {
    case boom
}

/// In-memory `AudioSource` that records how it was driven. Not `Sendable`; each
/// test uses its own instances within a single async context.
private final class FakeAudioSource: AudioSource {
    var isRecording = false
    var bufferCount = 0
    var startError: Error?
    private(set) var startCalls = 0
    private(set) var stopCalls = 0

    func start() async throws {
        startCalls += 1
        if let startError { throw startError }
        isRecording = true
    }

    func stop() async {
        stopCalls += 1
        isRecording = false
    }
}
