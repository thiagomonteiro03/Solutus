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

Solutus is a **macOS menu bar app** (not iOS) that:
1. Captures screenshots via `⌘+Shift+S` using `ScreenCaptureKit`
2. Queues them in `AppDelegate.capturedScreenshots`
3. Sends the queue to OpenAI GPT-4o via `⌘+Shift+Enter`
4. Shows the AI response in a floating overlay window that is **invisible to screen recording** (`sharingType = .none`)

## Architecture

```
SolutusApp.swift          → SwiftUI App entry point, sets up AppDelegate
AppDelegate.swift         → Coordinator: owns HotKeyManager, OverlayWindowController, screenshot queue
HotKey/HotKeyManager.swift     → CGEvent tap for keyboard shortcuts
Capture/ScreenCapture.swift    → ScreenCaptureKit wrapper, returns NSImage?
LLM/LLMService.swift           → Singleton, calls OpenAI API, reads OPENAI_API_KEY from env
Overlay/OverlayWindowController.swift  → NSWindow lifecycle (floating, borderless, invisible to recording)
Overlay/OverlayView.swift      → SwiftUI view driven by OverlayContent enum
```

**Key type:** `OverlayContent` enum drives the entire UI:
- `.captured(count: Int)` — shows screenshot count
- `.loading` — shows spinner
- `.solution(String)` — shows AI response
- `.error(String)` — shows error message in red

## Existing test coverage

Before touching any file, understand what's already protected:

| File | Test file | What's covered |
|------|-----------|----------------|
| `AppDelegate` | `AppDelegateTests.swift` | Instantiation, `dismiss()` idempotency, queue starts empty |
| `HotKeyManager` | `HotKeyManagerTests.swift` | Init, start/stop without accessibility permission, multiple cycles |
| `LLMService` | `LLMServiceTests.swift` | Singleton identity, `noAPIKey` guard, `noScreenshots` guard, guard order |
| `LLMError` | `LLMErrorTests.swift` | All error messages in Portuguese, 200-char truncation of apiError body |
| `OverlayView` | `OverlayViewTests.swift` | All OverlayContent states build without crash, frameHeight adapts |
| `OverlayWindowController` | `OverlayWindowControllerTests.swift` | Window creation, reuse, `sharingType == .none`, level/opacity, hide safety |
| `OverlayContent` | `OverlayContentTests.swift` | All enum cases, associated values, pattern matching |
| `ScreenCapture` | `ScreenCaptureTests.swift` | Returns Optional without throwing, parallel calls are safe |
| `TestHelpers` | `TestHelpers.swift` | Shared utilities: solid/empty NSImage, env var sandbox |

## Known gaps (fill as you go)

The existing tests themselves document these TODOs — address them when touching the relevant area:

- `LLMService`: no URL session injection → network path untested. If refactoring to inject `URLSession`, add tests for JSON body structure, base64 conversion, and `apiError` propagation.
- `HotKeyManager`: no tests for specific key dispatch logic. Extract `shouldTrigger(keyCode:flags:) -> Trigger?` as a pure function to make it testable.
- `OverlayView`: SwiftUI tree not deeply inspectable without external libs — frameHeight is tested indirectly only.

## How to approach every change

### Step 1: Identify what's affected
Before writing any code, list which source files will change and which test files cover them (use the table above).

### Step 2: Read the relevant tests
Read the test files for the affected components. Ask: will my change break any existing assertion? If yes, is the break intentional (behavior change) or a regression?

### Step 3: Write or update tests alongside the code
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
# Run all tests
xcodebuild test -scheme Solutus -destination 'platform=macOS'

# Or in Xcode: ⌘+U
```

## Adding a new feature — checklist

- [ ] Which components does this touch? (AppDelegate, HotKeyManager, LLMService, Overlay*)
- [ ] Are existing tests still valid, or does the new behavior change their expectations?
- [ ] Does the new code have any public/observable behavior that deserves a test?
- [ ] If adding a new `OverlayContent` case: add it to `OverlayContentTests` and `OverlayViewTests`
- [ ] If adding a new `LLMError` case: add it to `LLMErrorTests` with the exact Portuguese string
- [ ] Does the change affect `OverlayWindowController` window properties? Verify `sharingType == .none` still holds.
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
  - The prompt sent to GPT and the response Claude returns continue to be in English (product requirement).
- Use `@MainActor` for any UI-touching code
- `LLMService` is `Sendable` / `nonisolated` — keep network methods `nonisolated`
- `OverlayContent` is the single source of truth for UI state — don't pass raw strings to the view layer
- Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest
