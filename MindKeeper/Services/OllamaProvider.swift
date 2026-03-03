import Foundation

struct OllamaProvider: LLMProvider, Sendable {
    let model: String
    private let baseURL = "http://localhost:11434"

    init(model: String = "llama3.2") {
        self.model = model
    }

    func classify(_ text: String, context: String) async throws -> LLMClassification {
        var systemPrompt = classificationSystemPrompt
        if !context.isEmpty {
            systemPrompt += "\n\n用户历史偏好参考:\n\(context)"
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "stream": false,
            "format": "json"
        ]

        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw LLMError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMError.networkError("Ollama HTTP error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""

        return try parseClassification(content)
    }

    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func parseClassification(_ raw: String) throws -> LLMClassification {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }
        return try JSONDecoder().decode(LLMClassification.self, from: data)
    }
}

private let classificationSystemPrompt = """
你是一个通知优先级分析助手。分析通知/任务并返回 JSON:
{"category":"work|social|system|finance|health|shopping|other","urgency":1,"importance":1,"reason":"判断依据","suggested_action":"respond|review|ignore|defer"}
urgency 和 importance 取值 1-10。只返回 JSON。
"""

enum LLMError: Error, Sendable {
    case emptyResponse
    case invalidJSON
    case networkError(String)
}
