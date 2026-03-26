import Foundation

protocol TranslationServiceProtocol: Sendable {
    func translate(text: String, mode: TranslationMode) async throws -> String
}

enum TranslationServiceError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case emptyResult
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "LM Studio endpoint is invalid."
        case .invalidResponse:
            return "LM Studio returned an unexpected response."
        case .serverError(let statusCode):
            return "LM Studio returned HTTP \(statusCode)."
        case .emptyResult:
            return "LM Studio returned an empty translation."
        case .requestFailed(let message):
            return "Translation failed: \(message)"
        }
    }
}

struct TranslationService: TranslationServiceProtocol {
    let endpoint: URL
    let model: String
    let temperature: Double
    let session: URLSession

    init(
        endpoint: URL = URL(string: "http://localhost:1234/v1/responses")!,
        model: String = "local-model",
        temperature: Double = 0.2,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.model = model
        self.temperature = temperature
        self.session = session
    }

    func translate(text: String, mode: TranslationMode) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                model: model,
                input: Self.makePrompt(for: text, mode: mode),
                temperature: temperature
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationServiceError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TranslationServiceError.serverError(httpResponse.statusCode)
            }

            return try Self.extractTranslation(from: data)
        } catch let error as TranslationServiceError {
            throw error
        } catch {
            throw TranslationServiceError.requestFailed(error.localizedDescription)
        }
    }

    static func makePrompt(for text: String, mode: TranslationMode) -> String {
        let instruction: String

        switch mode {
        case .auto:
            instruction = "Detect the language of the following text and translate it to the other language between Simplified Chinese and English."
        case .zhToEn:
            instruction = "Translate the following Chinese text into natural English."
        case .enToZh:
            instruction = "Translate the following English text into natural Simplified Chinese."
        }

        return """
        \(instruction)
        Return only the translation result.
        Do not explain anything.

        Text:
        \(text)
        """
    }

    static func extractTranslation(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            throw TranslationServiceError.invalidResponse
        }

        if let outputText = json["output_text"] as? String {
            let trimmed = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if
            let output = json["output"] as? [[String: Any]],
            let content = output
                .compactMap({ $0["content"] as? [[String: Any]] })
                .flatMap({ $0 })
                .compactMap({ $0["text"] as? String })
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty })
        {
            return content
        }

        throw TranslationServiceError.emptyResult
    }
}

private struct RequestBody: Encodable {
    let model: String
    let input: String
    let temperature: Double
}
