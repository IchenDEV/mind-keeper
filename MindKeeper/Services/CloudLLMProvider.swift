import Foundation

struct CloudLLMProvider: LLMProvider {
    let apiKey: String
    let endpoint: String?

    private var baseURL: String {
        endpoint ?? "https://api.openai.com/v1"
    }

    func classify(_ text: String, context: String) async throws -> LLMClassification {
        var systemContent = classificationPrompt
        if !context.isEmpty {
            systemContent += "\n\n用户历史偏好:\n\(context)"
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.networkError("HTTP error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""

        guard let contentData = content.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }

        return try JSONDecoder().decode(LLMClassification.self, from: contentData)
    }
}

private let classificationPrompt = """
你是通知优先级分析助手。分析通知/任务并返回 JSON:
{"category":"work|social|system|finance|health|shopping|other","urgency":1-10,"importance":1-10,"reason":"判断依据","suggested_action":"respond|review|ignore|defer"}
只返回 JSON。
"""
