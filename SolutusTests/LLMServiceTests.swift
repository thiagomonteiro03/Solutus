import AppKit
import Foundation
import Testing
@testable import Solutus

/// Tests for `LLMService`. Since the current implementation uses
/// `URLSession.shared` directly, there's no way to intercept the network call
/// without refactoring. We focus instead on the *observable* paths that don't
/// hit the network:
/// - input validation (`noAPIKey`, `noScreenshots`)
/// - the same guards apply regardless of the requested `HelperKind`
/// - singleton idempotency
/// - the prompt builder produces a non-empty, kind-specific text
///
/// When the service is refactored to inject a test `URLSession`, add tests for:
///   - correct JSON assembly (`model`, `max_tokens`, `messages`)
///   - singular vs. plural prompt (>1 screenshot)
///   - decoding of `OpenAIResponse`
///   - `apiError` propagation when status != 200
///   - base64 conversion (imageToBase64)
@Suite("LLMService")
struct LLMServiceTests {

    // MARK: - Singleton

    @Test("shared returns the same instance")
    func sharedIsSingleton() {
        let a = LLMService.shared
        let b = LLMService.shared
        #expect(a === b)
    }

    // MARK: - Input validation (Algorithm Helper)

    @Test("solve(.algorithmHelper) without API key throws LLMError.noAPIKey")
    func solveAlgorithmWithoutAPIKeyThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "") {
            let image = await makeImage()
            do {
                _ = try await LLMService.shared.solve(screenshots: [image], kind: .algorithmHelper)
                Issue.record("solve() should have thrown noAPIKey")
            } catch let error as LLMError {
                guard case .noAPIKey = error else {
                    Issue.record("Expected noAPIKey, got: \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected non-LLMError: \(error)")
            }
        }
    }

    @Test("solve(.algorithmHelper) with empty screenshot list throws noScreenshots")
    func solveAlgorithmWithEmptyScreenshotsThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "sk-test-dummy") {
            do {
                _ = try await LLMService.shared.solve(screenshots: [], kind: .algorithmHelper)
                Issue.record("solve() should have thrown noScreenshots")
            } catch let error as LLMError {
                guard case .noScreenshots = error else {
                    Issue.record("Expected noScreenshots, got: \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected non-LLMError: \(error)")
            }
        }
    }

    @Test("solve(.algorithmHelper) prioritizes noAPIKey over noScreenshots")
    func apiKeyCheckHappensBeforeScreenshotsCheck() async throws {
        // With empty key AND empty list, the API key guard is evaluated first.
        // This test is a safety net against accidental reordering of the
        // guards inside `solve()`.
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "") {
            do {
                _ = try await LLMService.shared.solve(screenshots: [], kind: .algorithmHelper)
                Issue.record("solve() should have thrown")
            } catch let error as LLMError {
                guard case .noAPIKey = error else {
                    Issue.record("Expected noAPIKey (guard evaluated first), got: \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected non-LLMError: \(error)")
            }
        }
    }

    // MARK: - Input validation (Android Helper) — guards are kind-independent

    @Test("solve(.androidHelper) without API key throws LLMError.noAPIKey")
    func solveAndroidWithoutAPIKeyThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "") {
            let image = await makeImage()
            do {
                _ = try await LLMService.shared.solve(screenshots: [image], kind: .androidHelper)
                Issue.record("solve() should have thrown noAPIKey")
            } catch let error as LLMError {
                guard case .noAPIKey = error else {
                    Issue.record("Expected noAPIKey, got: \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected non-LLMError: \(error)")
            }
        }
    }

    @Test("solve(.androidHelper) with empty screenshot list throws noScreenshots")
    func solveAndroidWithEmptyScreenshotsThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "sk-test-dummy") {
            do {
                _ = try await LLMService.shared.solve(screenshots: [], kind: .androidHelper)
                Issue.record("solve() should have thrown noScreenshots")
            } catch let error as LLMError {
                guard case .noScreenshots = error else {
                    Issue.record("Expected noScreenshots, got: \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected non-LLMError: \(error)")
            }
        }
    }

    // MARK: - Prompt builder

    @Test("prompt(.algorithmHelper) is non-empty and tailored to coding problems")
    func algorithmPromptIsCodingFocused() {
        let single = LLMService.prompt(for: .algorithmHelper, screenshotCount: 1)
        let multi  = LLMService.prompt(for: .algorithmHelper, screenshotCount: 3)

        #expect(!single.isEmpty)
        #expect(!multi.isEmpty)
        // Stable anchor in the Algorithm Helper prompt (section always present).
        #expect(single.contains("## Complexity"))
        #expect(multi.contains("## Complexity"))
        // Plural vs singular changes the wording that describes the screenshots.
        #expect(single.contains("this screenshot"))
        #expect(multi.contains("3 screens"))
    }

    @Test("prompt(.androidHelper) is non-empty and tailored to Android/Kotlin")
    func androidPromptIsAndroidFocused() {
        let single = LLMService.prompt(for: .androidHelper, screenshotCount: 1)
        let multi  = LLMService.prompt(for: .androidHelper, screenshotCount: 2)

        #expect(!single.isEmpty)
        #expect(!multi.isEmpty)
        // Stable anchors: the prompt must mention Android/Kotlin to steer
        // the model, and Kotlin as the default language.
        #expect(single.contains("Android"))
        #expect(single.contains("Kotlin"))
        #expect(multi.contains("Android"))
        #expect(multi.contains("Kotlin"))
        // Plural vs singular.
        #expect(single.contains("this screenshot"))
        #expect(multi.contains("2 screens"))
    }

    @Test("prompts of distinct kinds produce distinct text")
    func promptsAreKindSpecific() {
        let algo    = LLMService.prompt(for: .algorithmHelper, screenshotCount: 1)
        let android = LLMService.prompt(for: .androidHelper,   screenshotCount: 1)
        #expect(algo != android)
    }

    // MARK: - Helpers

    @MainActor
    private func makeImage() -> NSImage {
        TestHelpers.makeSolidImage()
    }
}
