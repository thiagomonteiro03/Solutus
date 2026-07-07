---
name: solutus-dev
description: >
  Use this skill for ANY request that involves changing, adding, or fixing code in the
  Solutus macOS project. Triggers on words like "adicionar", "implementar", "mudar",
  "corrigir", "nova feature", "refatorar", or any request that would touch source files
  in the Solutus project. This skill ensures all development follows a test-aware
  workflow so the app's existing behavior is protected while new features are built.
---

# Solutus Development Guide

Always read this skill before making any change to the Solutus project — new features, bug fixes, refactors, or anything that touches source files.

## What the app does

Solutus is a **macOS menu bar app** (not iOS). The menu-bar icon opens the **Solutus Hub**, a window with one card per feature. Everything visible to the user runs through a floating overlay window that is **invisible to screen recording** (`sharingType = .none`). There are three features today:

1. **Algorithm Helper** — capture screenshots (`⌘+Shift+S`) → send the queue (`⌘+Shift+Enter`) → GPT-4o solves the coding problem, answer shown in the overlay (in English).
2. **Android Helper** — capture screenshots (`⌘+Shift+A`) → send (`⌘+Shift+Enter`) → GPT-4o answers the Android/Kotlin question (in English). Each helper has its **own independent screenshot queue**; `⌘+Shift+Enter` dispatches the queue of the *last helper the user captured into* (see `AppDelegate.resolveDispatch`).
3. **HR Meeting Helper** — click the card to start/stop. While recording it captures the **microphone + system audio**, transcribes both speakers live with `SFSpeechRecognizer`, and shows the running transcript in the overlay. On stop it asks GPT-4o for a **PT-BR summary** of the interview, shows it, and saves summary + raw transcript to a `.txt` under `~/Documents/Solutus/Transcricoes`.

## Architecture

```
SolutusApp.swift              → SwiftUI App entry point, installs AppDelegate
AppDelegate.swift             → Coordinator: owns HotKeyManager, Overlay + Hub controllers, the
                                menu-bar status item, per-helper screenshot queues, and the meeting
                                audio/transcription objects. Injects each hub card's action.
ContentView.swift             → legacy SwiftUI placeholder; the app is driven by AppDelegate, not this

Hub/
  HelperKind.swift            → enum {algorithmHelper, androidHelper}: picks the prompt + labels the response
  Feature.swift               → Feature model (id/title/subtitle/category/action) + FeatureCategory badge enum
  FeatureRegistry.swift       → pure DI registry; defaultFeatures(...) builds the 3 cards with injected actions
  HubView.swift               → SwiftUI hub: header + adaptive grid of FeatureCards
  HubWindowController.swift   → standard titled NSWindow hosting HubView (NOT the invisible overlay)

HotKey/HotKeyManager.swift    → CGEvent tap; pure shouldTrigger(keyCode:flags:) -> Trigger? maps
                                ⌘+Shift+S / +A / +Enter to captureAlgorithm / captureAndroid / send
Capture/ScreenCapture.swift   → ScreenCaptureKit wrapper, returns NSImage?

Audio/
  AudioSource.swift           → protocol {isRecording, bufferCount, start() async throws, stop() async}
  MicrophoneCapture.swift     → AVAudioEngine mic tap; applies gain; forwards AVAudioPCMBuffer via onBuffer
  SystemAudioCapture.swift    → SCStream system audio; forwards CMSampleBuffer via onBuffer
  MeetingAudioSession.swift   → starts/stops both sources together; rolls back mic if system audio fails

Transcription/
  Transcriber.swift           → one SFSpeechRecognizer per speaker; on-device, self-restarting across
                                silence timeouts (generation guard + pending-buffer replay); emits
                                onText + onUtteranceFinalized
  MeetingTranscriber.swift    → wires the two sources to two labeled Transcribers ("Você"/"Outra parte"),
                                staggered ~2s; appends finalized utterances to the transcript
  MeetingTranscript.swift     → thread-safe append-only store of Segments; `formatted` renders labeled lines
  TranscriptExporter.swift    → saves header + AI summary + raw transcript to ~/Documents/Solutus/Transcricoes

LLM/LLMService.swift          → Singleton, OpenAI GPT-4o, reads OPENAI_API_KEY from env.
                                solve(screenshots:kind:) for the screenshot helpers;
                                summarizeMeeting(transcript:) for the HR flow. LLMError enum.
Overlay/OverlayWindowController.swift  → floating, borderless NSWindow, invisible to recording (sharingType=.none)
Overlay/OverlayView.swift     → SwiftUI view driven by OverlayContent enum
```

**Key type:** `OverlayContent` enum drives the entire overlay UI:
- `.captured(count: Int)` — screenshot count for the active helper
- `.loading` — spinner ("Analisando…")
- `.recording(transcript: String)` — live HR meeting capture; empty string until the first utterance
- `.solution(text: String, source: HelperKind)` — screenshot answer, headed by which helper responded
- `.summary(text: String)` — AI summary of a finished meeting (not tied to a `HelperKind`)
- `.error(String)` — error message in red

**Two distinct LLM flows** live in `LLMService`: the screenshot path (`solve`, prompt + response in **English**) and the meeting path (`summarizeMeeting`, prompt + response in **PT-BR**). Don't assume "responses are always English" — that only holds for the screenshot helpers.

## Existing test coverage

Before touching any file, understand what's already protected:

| File | Test file | What's covered |
|------|-----------|----------------|
| `AppDelegate` + `resolveDispatch` | `AppDelegateTests.swift` | Instantiation, `dismiss()` clears both queues, `resolveDispatch` policy (active / fallback / no-op) |
| `HotKeyManager` | `HotKeyManagerTests.swift` | Init/start/stop safety, `shouldTrigger` maps ⌘+Shift+S/A/Enter and rejects extra modifiers |
| `ScreenCapture` | `ScreenCaptureTests.swift` | Returns Optional without throwing, parallel calls are safe |
| `Feature` / `FeatureCategory` | `FeatureTests.swift` | Field preservation, `Identifiable`, `iconLabel`/`displayName`, stable `rawValue`s |
| `FeatureRegistry` | `FeatureRegistryTests.swift` | All 3 helpers registered with right category/title, unique ids, actions are lazy |
| `HubWindowController` | `HubWindowControllerTests.swift` | Lazy window, reuse, `toggle`, standard chrome, hosts `HubView`, stays alive |
| `OverlayContent` / `HelperKind` | `OverlayContentTests.swift` | All cases incl. `recording`/`summary`/`solution(source:)`, pattern matching, `HelperKind` displayName/equatable |
| `OverlayView` | `OverlayViewTests.swift` | All states build without crash, frameHeight adapts, markdown/newlines preserved |
| `OverlayWindowController` | `OverlayWindowControllerTests.swift` | Window creation, reuse, `sharingType == .none`, hide safety, accepts all content types |
| `LLMService` | `LLMServiceTests.swift` | Singleton, `solve` guards per kind (`noAPIKey`/`noScreenshots`/order), prompt builders per kind, `meetingSummaryPrompt` is PT-BR, `summarizeMeeting` guards (`noAPIKey`/`noTranscript`) |
| `LLMError` | `LLMErrorTests.swift` | Portuguese messages, 200-char truncation of `apiError` body, `LocalizedError` conformance |
| `MicrophoneCapture` | `MicrophoneCaptureTests.swift` | `access(for:)` mapping, fresh state idle, stop-before-start safe |
| `SystemAudioCapture` | `SystemAudioCaptureTests.swift` | Fresh state idle, stop-before-start safe |
| `MeetingAudioSession` | `MeetingAudioSessionTests.swift` | Starts/stops both sources, rollback on system-audio failure, no-op when recording, buffer counts forwarded |
| `Transcriber` | `TranscriberTests.swift` | `access(for:)` mapping, `label` propagation, stop-before-start safe |
| `MeetingTranscript` | `MeetingTranscriptTests.swift` | Empty fresh, ordered segments, `formatted` lines, trims/skips empties, `clear`, timestamp injection |
| `TranscriptExporter` | `TranscriptExporterTests.swift` | Timestamped `.txt` name, header, nil on empty transcript, `fileBody` sections + summary placeholder |
| `TestHelpers` | `TestHelpers.swift` | Shared utilities: solid/empty NSImage, env var sandbox |

## Known gaps (fill as you go)

- `LLMService`: no `URLSession` injection → the whole network path (`chat(...)`, JSON body structure, base64 conversion, `apiError` propagation, and `summarizeMeeting`'s network call) is untested. If refactoring to inject `URLSession`, add tests there.
- `Transcriber`: only its pure bits are tested (`access(for:)`, `label`). The concurrency-critical part — self-restart across silence timeouts, the `generation` guard against duplicate callbacks, and pending-buffer replay across the restart gap — is untested because it needs a fake `SFSpeechRecognizer`. Tread carefully here; this is the trickiest code in the app.
- `SystemAudioCapture` / `MicrophoneCapture`: only idle-state and permission mapping are covered; the actual buffer-forwarding path (real hardware) is not unit-tested.
- `OverlayView`: SwiftUI tree not deeply inspectable without external libs — frameHeight is tested indirectly only.

## Core working principles

Distilled from field notes on LLM-assisted coding (CLAUDE.md) and long-running agent loops (LOOPS.md). These are the mindset behind the steps below — the throughline is: this model is fast at producing *plausible* code and slow at noticing that plausible is not correct, so the discipline comes from the process.

- **Read before you write.** Read the source files you are about to touch (not just the tests), copy the patterns that already exist, and check the real imports before reaching for a new dependency. When you cannot find a pattern, ask instead of guessing.
- **Think before you code.** State your assumptions and name the tradeoffs out loud before typing. If a task is genuinely ambiguous, stop and ask — that is exactly the code that passes a casual review and fails when it matters.
- **Define success first (goal-driven).** Turn a vague request into a testable criterion before writing code. "Add validation" becomes "reject a malformed transcript, surface a PT-BR error in the overlay, test both cases." For anything multi-step, state the plan first so the user can catch a wrong approach early.
- **Simplicity + surgical diffs.** Write the minimum that solves the problem in front of you, not every future version of it. The diff should be the size of the task: don't reformat, don't touch unrelated files, don't refactor "while you're in there." If a line changed only because you were passing by, revert it.
- **Verification is the only proof.** Code that works and code you think works are different things — the gap is testing. See Step 3/Step 5; for bug fixes specifically, the failing test comes first.
- **Debug by reading, not guessing.** When something breaks, read the whole error/trace and reproduce it before changing anything, then change one thing at a time. Don't paper over an unexpected `nil` with a guard — find out *why* it is nil. Most "the agent did the wrong thing" moments are a single point where reasoning diverged; find that point, fix it there, don't just re-run.
- **Communicate what and why.** Say what you changed and why, flag concerns even when you did exactly what was asked, and be precise about uncertainty ("I'm not sure this API supports X" beats "this should work").
- **Watch for the common failure modes** — name them and stop when you catch yourself:
  - *Kitchen Sink* — restructuring half the codebase while doing a small task.
  - *Wrong Abstraction* — copy-pasting twice beats the wrong abstraction once.
  - *Optimistic Path* — happy path handled, the error/`.error` path ignored.
  - *Runaway Refactor* — a fix that cascades across files. Stop, don't push through.

## How to approach every change

### Step 1: Identify what's affected
Before writing any code, list which source files will change and which test files cover them (use the table above). Read the source itself, not only the tests — match the existing style and imports.

### Step 2: Read the relevant tests
Read the test files for the affected components. Ask: will my change break any existing assertion? If yes, is the break intentional (behavior change) or a regression?

### Step 3: Write or update tests alongside the code
- **Bug fix → write the failing test first.** Reproduce the bug as a test, watch it fail, then fix it. That is the only proof you fixed the cause and not a symptom. Test behavior that can actually break, not that a constructor sets a field.
- New public method → new test
- New enum case in `OverlayContent` → new case in `OverlayContentTests`
- New error in `LLMError` → new test in `LLMErrorTests` covering the Portuguese message
- New guard in `LLMService.solve()` → new test covering the guard
- New property on `OverlayWindowController` that affects the window → new test using Mirror if the property is private

### Step 4: Keep tests honest
- Tests use `Mirror` to inspect private state — if you rename a private property, update the mirror lookup in the test.
- Error messages appear directly in the user-facing overlay. If you change an `errorDescription` string, update the corresponding test assertion.
- `OverlayWindowController` has a critical product requirement: `window.sharingType == .none`. Never remove or weaken this — `OverlayWindowControllerTests` will catch it.

### Step 5: Run tests
```bash
# Run all tests. Use the SolutusTests scheme — the `Solutus` app scheme is NOT
# wired for the test action from the command line ("Scheme Solutus is not
# currently configured for the test action").
xcodebuild test -scheme SolutusTests -destination 'platform=macOS'

# Or in Xcode: ⌘+U
```

### Step 6: Critical pass before closing
Before declaring the change done, review it as if the code is broken and it's your job to prove it — a separate reading, not the one that wrote it. Re-read the diff against the "common failure modes" list, confirm the diff is the size of the task, and check the error/edge paths, not just the happy path. For larger changes, `/code-review` runs this pass for you.

## Adding a new feature — checklist

- [ ] Which components does this touch? (AppDelegate, Hub/*, HotKeyManager, Audio/*, Transcription/*, LLMService, Overlay*)
- [ ] Are existing tests still valid, or does the new behavior change their expectations?
- [ ] Does the new code have any public/observable behavior that deserves a test?
- [ ] If adding a new hub feature: register it in `FeatureRegistry.defaultFeatures(...)` (inject the action) and cover it in `FeatureRegistryTests` (category/title, unique id, lazy action).
- [ ] If adding a new `HelperKind` case: update `LLMService.prompt(for:)`, `AppDelegate`'s queue/dispatch, and `OverlayContentTests`/`OverlayViewTests` for the labeled `.solution`.
- [ ] If adding a new `OverlayContent` case: add it to `OverlayContentTests` and `OverlayViewTests`
- [ ] If adding a new `LLMError` case: add it to `LLMErrorTests` with the exact Portuguese string
- [ ] Does the change affect `OverlayWindowController` window properties? Verify `sharingType == .none` still holds.
- [ ] If touching the audio/transcription pipeline: prefer testing the pure/coordination bits (via `AudioSource` fakes, `MeetingTranscript`, `access(for:)` mappings); the live-recognition path is a known gap, not a place to guess.
- [ ] If new network behavior in `LLMService`: document it in the test file as a known gap or add a test

## Language and style conventions

- **Code is in English. Strings shown to the user are in Portuguese (Brazilian).**
  Concretely:
  - Comments (single-line, block, doc comments, `// MARK:` headers) → English.
  - Type/property/method/local names → English (already the convention).
  - `print()` and other developer-console output → English (not user-facing).
  - User-facing strings stay in PT-BR. This includes:
    - `LLMError.errorDescription` — rendered in the overlay's `.error` state.
    - Alert bodies/titles shown via `NSAlert`.
    - SwiftUI `Text(...)` content rendered to the user (overlay copy, hub copy, feature subtitles, `FeatureCategory.displayName`, etc.).
    - Default fallbacks that surface to the user (e.g., `"Sem resposta da API."`).
  - Language of the LLM prompt/response depends on the flow:
    - **Screenshot helpers** (`solve`, Algorithm/Android): prompt AND response in **English** (product requirement — consistent overlay output).
    - **HR Meeting Helper** (`summarizeMeeting`): prompt AND response in **PT-BR**, because the summary feeds the user's Portuguese recruiting pipeline.
- Use `@MainActor` for any UI-touching code
- `LLMService` is `Sendable` / `nonisolated` — keep network methods `nonisolated`
- The `Audio/` and `Transcription/` types are `nonisolated` and guard shared state with `NSLock` — their `onBuffer`/`onText`/`onTranscriptUpdated` callbacks fire on capture/recognizer threads, NOT the main actor. Any UI touch from them must hop via `Task { @MainActor in … }` (see how `AppDelegate` wires `.recording`).
- `OverlayContent` is the single source of truth for UI state — don't pass raw strings to the view layer
- Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest
