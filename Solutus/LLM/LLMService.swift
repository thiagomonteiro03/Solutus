import AppKit
import Foundation

/// Envia o screenshot para a API da Claude e retorna a solução.
///
/// Configure sua API key em uma variável de ambiente chamada ANTHROPIC_API_KEY:
/// Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
final class LLMService: Sendable {

    static let shared = LLMService()

    // MARK: - Config

    nonisolated private var apiKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }

    nonisolated private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    nonisolated private let model = "claude-opus-4-6"

    // MARK: - Solve

    nonisolated func solve(screenshot: NSImage) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let base64 = try imageToBase64(screenshot)

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64
                            ]
                        ],
                        [
                            "type": "text",
                            "text": """
                            Analise este screenshot. Se houver um problema de programação, \
                            algoritmo ou exercício de código visível na tela, resolva-o de forma \
                            clara e concisa, com explicação da solução. \
                            Se não houver nenhum algoritmo ou problema de código, diga isso brevemente.
                            """
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? "Sem resposta da API."
    }

    // MARK: - Helpers

    nonisolated private func imageToBase64(_ image: NSImage) throws -> String {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            throw LLMError.imageConversionFailed
        }
        return jpeg.base64EncodedString()
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Falha ao converter o screenshot."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case .apiError(let code, let body):
            return "Erro da API (\(code)): \(body.prefix(200))"
        case .noAPIKey:
            return "API key não configurada. Adicione ANTHROPIC_API_KEY nas variáveis de ambiente do scheme."
        }
    }
}

// MARK: - Response Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}
