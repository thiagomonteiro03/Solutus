import AppKit
import Foundation

/// Envia screenshots para a API da OpenAI (GPT-4o) e retorna a solução.
///
/// Configure sua API key em uma variável de ambiente chamada OPENAI_API_KEY:
/// Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
final class LLMService: Sendable {

    static let shared = LLMService()

    nonisolated private var apiKey: String {
        guard let ptr = getenv("OPENAI_API_KEY") else { return "" }
        return String(cString: ptr)
    }

    nonisolated private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    nonisolated private let model = "gpt-4o"

    // MARK: - Solve (múltiplos screenshots)

    nonisolated func solve(screenshots: [NSImage]) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }
        guard !screenshots.isEmpty else { throw LLMError.noScreenshots }

        // Monta os blocos de conteúdo: uma imagem por screenshot + texto no final
        var contentBlocks: [[String: Any]] = []

        for (index, image) in screenshots.enumerated() {
            let base64 = try imageToBase64(image)

            if screenshots.count > 1 {
                contentBlocks.append([
                    "type": "text",
                    "text": "Tela \(index + 1) de \(screenshots.count):"
                ])
            }

            contentBlocks.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
            ])
        }

        let prompt = screenshots.count > 1
            ? "Analise estas \(screenshots.count) telas em conjunto. Se houver um problema de programação, algoritmo ou exercício de código, resolva-o de forma clara e concisa com explicação. Se não houver nenhum algoritmo ou problema de código, diga isso brevemente."
            : "Analise este screenshot. Se houver um problema de programação, algoritmo ou exercício de código, resolva-o de forma clara e concisa com explicação. Se não houver nenhum algoritmo ou problema de código, diga isso brevemente."

        contentBlocks.append(["type": "text", "text": prompt])

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [["role": "user", "content": contentBlocks]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "Sem resposta da API."
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
    case noScreenshots

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:  return "Falha ao converter o screenshot."
        case .invalidResponse:        return "Resposta inválida do servidor."
        case .apiError(let c, let b): return "Erro da API (\(c)): \(b.prefix(200))"
        case .noAPIKey:               return "API key não configurada. Adicione OPENAI_API_KEY nas variáveis de ambiente do scheme."
        case .noScreenshots:          return "Nenhum screenshot para enviar."
        }
    }
}

// MARK: - Response Models

private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String }
}
