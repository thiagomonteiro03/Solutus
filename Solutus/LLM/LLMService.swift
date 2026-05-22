import AppKit
import Foundation

/// Sends screenshots to OpenAI's API (GPT-4o) and returns the solution.
///
/// Configure your API key as an environment variable called OPENAI_API_KEY:
/// Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
final class LLMService: Sendable {

    static let shared = LLMService()

    nonisolated private var apiKey: String {
        guard let ptr = getenv("OPENAI_API_KEY") else { return "" }
        return String(cString: ptr)
    }

    nonisolated private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    nonisolated private let model = "gpt-4o"

    // MARK: - Solve (multiple screenshots)

    /// Sends the screenshots to GPT-4o using the prompt for the given `kind`.
    ///
    /// The prompt is built by `Self.prompt(for:screenshotCount:)` — all the
    /// "which feature asks for what" logic lives there, keeping this method
    /// agnostic to the prompt content.
    nonisolated func solve(screenshots: [NSImage], kind: HelperKind) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }
        guard !screenshots.isEmpty else { throw LLMError.noScreenshots }

        // Build the content blocks: one image per screenshot plus the prompt text at the end.
        var contentBlocks: [[String: Any]] = []

        for (index, image) in screenshots.enumerated() {
            let base64 = try imageToBase64(image)

            if screenshots.count > 1 {
                contentBlocks.append([
                    "type": "text",
                    "text": "Screen \(index + 1) of \(screenshots.count):"
                ])
            }

            contentBlocks.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
            ])
        }

        let promptText = Self.prompt(for: kind, screenshotCount: screenshots.count)
        contentBlocks.append(["type": "text", "text": promptText])

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

    // MARK: - Prompt builders

    /// Resolves the full prompt to send to GPT, based on the active feature.
    ///
    /// The returned text is always in ENGLISH — a product requirement, so the
    /// response shown in the overlay is consistent regardless of the language
    /// the user wrote the original question in.
    nonisolated static func prompt(for kind: HelperKind, screenshotCount: Int) -> String {
        switch kind {
        case .algorithmHelper: return algorithmHelperPrompt(screenshotCount: screenshotCount)
        case .androidHelper:   return androidHelperPrompt(screenshotCount: screenshotCount)
        }
    }

    nonisolated private static func algorithmHelperPrompt(screenshotCount: Int) -> String {
        let target = screenshotCount > 1
            ? "these \(screenshotCount) screens together"
            : "this screenshot"

        return """
        Analyze \(target). The ENTIRE response must be written in ENGLISH (section titles, comments, explanations — everything). If there is a programming problem, algorithm, or coding exercise, structure your response exactly in this order:

        ## Solution
        Provide the full solution code. IMPORTANT: immediately above the main function/method that solves the problem, write numbered comments (// 1 - ..., // 2 - ..., // 3 - ...), one per line, describing each step of the algorithm in ONE short, objective sentence in English. These comments are a roadmap of the reasoning (steps), letting the reader try to implement it before looking at the code below. Use the same language as the prompt (or Kotlin/Swift/Python depending on context).

        Example of the comment format above the function:
        // 1 - Declare prev and curr pointers
        // 2 - Iterate while curr is not null
        // 3 - Save next, reverse link, advance pointers
        // 4 - Return prev as the new head of the list

        ## Complexity
        State time and space complexity (in English).

        If there is no algorithm or coding problem, just say so briefly (in English).
        """
    }

    nonisolated private static func androidHelperPrompt(screenshotCount: Int) -> String {
        let target = screenshotCount > 1
            ? "these \(screenshotCount) screens together"
            : "this screenshot"

        return """
        Analyze \(target). It contains something related to mobile development — most likely Android (Kotlin or Java), but it may be ANY question, prompt, exercise, or topic about technologies, tools, libraries, or concepts used to build mobile apps (e.g., Jetpack Compose, coroutines, Flow, Gradle, Room, Retrofit, Hilt/Dagger, the Android SDK, navigation, architecture patterns like MVVM/MVI, testing, Material Design, the app/Activity/Fragment lifecycle, permissions, build/release tooling, and so on).

        It is IMPORTANT that you answer ANY such question that appears in the screenshot — no matter how short, simple, or basic it is. A one-line question still deserves a direct answer. Never refuse or skip a question just because it looks trivial, too short, or only loosely related to Android: if it touches mobile development technology, answer it.

        Answer EXACTLY what the screenshot asks — nothing more. Do NOT invent a full app, do NOT add tests, and do NOT pad the answer with extra features or tangents that were not requested.

        The ENTIRE response must be written in ENGLISH (section titles, comments, explanations — everything).

        Identify what is being asked and respond accordingly:
        - Conceptual / theory questions (including very short or simple ones, e.g., "what is a ViewModel?", "explain the Activity lifecycle", "difference between LiveData and StateFlow", "when to use viewModelScope vs lifecycleScope") → answer with concise, direct text; use bullets when they help clarity.
        - Code questions (a function, class, Composable, ViewModel, migration, etc.) → respond with code.
        - Algorithm or coding problems → solve them, following the code-roadmap rule below.
        - If the screenshot requires a mix, mix them.

        Default language: Kotlin. Only use Java if the screenshot is clearly written in Java.

        When the answer contains code, immediately above the main declaration that solves it, write numbered comments (// 1 - ..., // 2 - ..., // 3 - ...), one per line, each a single short sentence in English describing one step of your reasoning. These comments are a roadmap (the steps) that let the reader try to implement it before reading the code below.

        Example of the comment format above the declaration:
        // 1 - Collect the StateFlow inside the composable
        // 2 - Hoist the state up to the ViewModel
        // 3 - Emit a new UiState whenever the repository returns

        When the answer is conceptual text, be direct and concise — no repetition, no filler.

        If you made any relevant assumptions to answer the question (e.g., "assumed Hilt for DI", "assumed minSdk 24"), declare them in a short final section titled "## Notes". Otherwise, omit the section entirely.

        Only if the screenshot has nothing to do with mobile development at all, say so briefly (in English).
        """
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
