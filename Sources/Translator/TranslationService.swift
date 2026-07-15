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
    private let customEndpoint: URL?
    private let customModel: String?
    private let customTemperature: Double?
    let session: URLSession

    init(
        endpoint: URL? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        session: URLSession = .shared
    ) {
        self.customEndpoint = endpoint
        self.customModel = model
        self.customTemperature = temperature
        self.session = session
    }

    func translate(text: String, mode: TranslationMode) async throws -> String {
        // Read configuration from UserDefaults or use custom initializers
        let defaults = UserDefaults.standard
        let apiBase = defaults.string(forKey: "apiEndpoint") ?? "http://localhost:1234/v1"
        let model = customModel ?? defaults.string(forKey: "selectedModel") ?? "local-model"
        let temperature = customTemperature ?? (defaults.object(forKey: "temperature") as? Double ?? 0.2)

        let endpointURL: URL
        if let customEndpoint = customEndpoint {
            endpointURL = customEndpoint
        } else {
            let cleanBase = apiBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if cleanBase.hasSuffix("/responses") || cleanBase.hasSuffix("/chat/completions") {
                guard let url = URL(string: cleanBase) else {
                    throw TranslationServiceError.invalidURL
                }
                endpointURL = url
            } else {
                guard let url = URL(string: "\(cleanBase)/chat/completions") else {
                    throw TranslationServiceError.invalidURL
                }
                endpointURL = url
            }
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "temperature": temperature
        ]

        if endpointURL.path.contains("responses") {
            body["input"] = Self.makePrompt(for: text, mode: mode)
        } else {
            let systemPrompt = Self.makeSystemInstruction(for: mode)
            body["messages"] = [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

    func fetchLoadedModels(baseURL: String) async throws -> [String] {
        let cleanBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/models") else {
            throw TranslationServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw TranslationServiceError.invalidResponse
        }

        struct ModelListResponse: Decodable {
            struct ModelItem: Decodable {
                let id: String
            }
            let data: [ModelItem]
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(ModelListResponse.self, from: data)
        return result.data.map { $0.id }
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

    static func makeSystemInstruction(for mode: TranslationMode) -> String {
        let instruction: String
        switch mode {
        case .auto:
            instruction = "Detect the language of the text and translate it to the other language between Simplified Chinese and English."
        case .zhToEn:
            instruction = "Translate the Chinese text into natural English."
        case .enToZh:
            instruction = "Translate the English text into natural Simplified Chinese."
        }
        return "\(instruction) Output ONLY the clean translation result, with absolutely no explanation, reasoning process, formatting, introduction, or repeating."
    }

    static func stripThinkingProcess(_ text: String) -> String {
        var clean = text
        // Strip complete <think>...</think> or <thought>...</thought> blocks
        let patterns = [
            "(?i)<think>[\\s\\S]*?</think>",
            "(?i)<thought>[\\s\\S]*?</thought>"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: clean.utf16.count)
                clean = regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
            }
        }
        // Strip any unclosed tags and everything after them
        let unclosedTags = ["<think>", "<thought>"]
        for tag in unclosedTags {
            if let range = clean.range(of: tag, options: .caseInsensitive) {
                clean = String(clean[..<range.lowerBound])
            }
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractTranslation(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            throw TranslationServiceError.invalidResponse
        }

        var textResult = ""

        if let outputText = json["output_text"] as? String {
            textResult = outputText
        } else if
            let output = json["output"] as? [[String: Any]]
        {
            // Find the item of type "message", which contains the final text output
            if let messageItem = output.first(where: { ($0["type"] as? String) == "message" }),
               let contentArray = messageItem["content"] as? [[String: Any]],
               let text = contentArray.compactMap({ $0["text"] as? String }).first(where: { !$0.isEmpty }) {
                textResult = text
            } else if let content = output
                .compactMap({ $0["content"] as? [[String: Any]] })
                .flatMap({ $0 })
                .compactMap({ $0["text"] as? String })
                .first(where: { !$0.isEmpty })
            {
                // Fallback to the first non-empty text if no "message" type is found
                textResult = content
            }
        } else if
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String
        {
            textResult = content
        } else {
            throw TranslationServiceError.emptyResult
        }

        let trimmed = textResult.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return stripThinkingProcess(trimmed)
        }

        throw TranslationServiceError.emptyResult
    }
}

private struct RequestBody: Encodable {
    let model: String
    let input: String
    let temperature: Double
    let thinking: ThinkingConfig?
    let reasoning: ReasoningConfig?
    let reasoning_effort: String?

    enum CodingKeys: String, CodingKey {
        case model, input, temperature, thinking, reasoning, reasoning_effort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(input, forKey: .input)
        try container.encode(temperature, forKey: .temperature)
        if let thinking = thinking {
            try container.encode(thinking, forKey: .thinking)
        }
        if let reasoning = reasoning {
            try container.encode(reasoning, forKey: .reasoning)
        }
        if let reasoning_effort = reasoning_effort {
            try container.encode(reasoning_effort, forKey: .reasoning_effort)
        }
    }
}

private struct ThinkingConfig: Encodable {
    let type: String
}

private struct ReasoningConfig: Encodable {
    let effort: String
}
