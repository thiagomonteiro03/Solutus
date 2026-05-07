import AppKit
import Foundation
import Testing
@testable import Solutus

/// Tests for `LLMService`. Since the current implementation uses
/// `URLSession.shared` directly, there's no way to intercept the network call
/// without refactoring. We focus instead on the *observable* paths that don't
/// hit the network:
/// - input validation (`noAPIKey`, `noScreenshots`)
/// - singleton idempotency
/// - Sendable / concurrency
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

    @Test("LLMService.shared retorna a mesma instância")
    func sharedIsSingleton() {
        let a = LLMService.shared
        let b = LLMService.shared
        #expect(a === b)
    }

    // MARK: - Input validation

    @Test("solve() sem API key lança LLMError.noAPIKey")
    func solveWithoutAPIKeyThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "") {
            let image = await makeImage()
            do {
                _ = try await LLMService.shared.solve(screenshots: [image])
                Issue.record("solve() deveria ter lançado noAPIKey")
            } catch let error as LLMError {
                guard case .noAPIKey = error else {
                    Issue.record("Esperava noAPIKey, recebeu: \(error)")
                    return
                }
            } catch {
                Issue.record("Erro inesperado (não-LLMError): \(error)")
            }
        }
    }

    @Test("solve() com lista vazia de screenshots lança noScreenshots")
    func solveWithEmptyScreenshotsThrows() async throws {
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "sk-test-dummy") {
            do {
                _ = try await LLMService.shared.solve(screenshots: [])
                Issue.record("solve() deveria ter lançado noScreenshots")
            } catch let error as LLMError {
                guard case .noScreenshots = error else {
                    Issue.record("Esperava noScreenshots, recebeu: \(error)")
                    return
                }
            } catch {
                Issue.record("Erro inesperado (não-LLMError): \(error)")
            }
        }
    }

    @Test("solve() prioriza noAPIKey sobre noScreenshots")
    func apiKeyCheckHappensBeforeScreenshotsCheck() async throws {
        // With empty key AND empty list, the API key guard is evaluated first.
        // This test is a safety net against accidental reordering of the
        // guards inside `solve()`.
        try await TestHelpers.withEnvironment(key: "OPENAI_API_KEY", value: "") {
            do {
                _ = try await LLMService.shared.solve(screenshots: [])
                Issue.record("solve() deveria ter lançado")
            } catch let error as LLMError {
                guard case .noAPIKey = error else {
                    Issue.record("Esperava noAPIKey (guard avaliado primeiro), recebeu: \(error)")
                    return
                }
            } catch {
                Issue.record("Erro inesperado (não-LLMError): \(error)")
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeImage() -> NSImage {
        TestHelpers.makeSolidImage()
    }
}
