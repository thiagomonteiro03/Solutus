import Testing
@testable import Solutus

/// Covers every case of `LLMError` and its localized descriptions.
/// These strings are shown directly in the overlay to the end user,
/// so any change here must be intentional.
@Suite("LLMError")
struct LLMErrorTests {

    @Test("imageConversionFailed usa mensagem em português")
    func imageConversionFailed() {
        let error = LLMError.imageConversionFailed
        #expect(error.errorDescription == "Falha ao converter o screenshot.")
    }

    @Test("invalidResponse usa mensagem em português")
    func invalidResponse() {
        let error = LLMError.invalidResponse
        #expect(error.errorDescription == "Resposta inválida do servidor.")
    }

    @Test("noAPIKey orienta o usuário a configurar o scheme")
    func noAPIKey() {
        let error = LLMError.noAPIKey
        let description = error.errorDescription ?? ""
        #expect(description.contains("API key"))
        #expect(description.contains("OPENAI_API_KEY"))
    }

    @Test("noScreenshots usa mensagem em português")
    func noScreenshots() {
        let error = LLMError.noScreenshots
        #expect(error.errorDescription == "Nenhum screenshot para enviar.")
    }

    @Test("apiError inclui status code e corpo truncado")
    func apiErrorIncludesStatusAndBody() {
        let error = LLMError.apiError(statusCode: 429, body: "rate limited")
        let description = error.errorDescription ?? ""
        #expect(description.contains("429"))
        #expect(description.contains("rate limited"))
    }

    @Test("apiError trunca corpos muito grandes em 200 caracteres")
    func apiErrorTruncatesLongBody() {
        let longBody = String(repeating: "x", count: 1_000)
        let error = LLMError.apiError(statusCode: 500, body: longBody)
        let description = error.errorDescription ?? ""
        // The implementation uses `.prefix(200)`, so the truncated body must
        // be at most 200 characters — anything beyond that would be a bug.
        let bodySegment = description.replacingOccurrences(of: "Erro da API (500): ", with: "")
        #expect(bodySegment.count <= 200)
    }

    @Test("LocalizedError conforma com o protocolo padrão do Swift")
    func conformsToLocalizedError() {
        let error: any Error = LLMError.noAPIKey
        #expect((error as? LLMError)?.errorDescription != nil)
    }
}
