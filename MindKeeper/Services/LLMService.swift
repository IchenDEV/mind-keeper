import Foundation

struct LLMClassification: Codable, Sendable {
    let category: String
    let urgency: Int
    let importance: Int
    let reason: String
    let suggestedAction: String

    enum CodingKeys: String, CodingKey {
        case category, urgency, importance, reason
        case suggestedAction = "suggested_action"
    }
}

protocol LLMProvider: Sendable {
    func classify(_ text: String, context: String) async throws -> LLMClassification
}

struct TaskSnapshot: Sendable {
    let title: String
    let body: String
    let appName: String?
    let sender: String?
    let createdAt: Date
    let urgency: Int
    let importance: Int
}

actor LLMService {
    private var ollamaProvider: OllamaProvider
    private var cloudProvider: CloudLLMProvider?
    private var _useOllama = true

    var isOllamaReady: Bool { _useOllama }

    init(cloudAPIKey: String? = nil, cloudEndpoint: String? = nil) {
        self.ollamaProvider = OllamaProvider()
        if let key = cloudAPIKey, !key.isEmpty {
            cloudProvider = CloudLLMProvider(apiKey: key, endpoint: cloudEndpoint)
        } else {
            cloudProvider = nil
        }
    }

    func updateConfig(cloudAPIKey: String?, cloudEndpoint: String?, ollamaModel: String) {
        self.ollamaProvider = OllamaProvider(model: ollamaModel)
        if let key = cloudAPIKey, !key.isEmpty {
            self.cloudProvider = CloudLLMProvider(apiKey: key, endpoint: cloudEndpoint)
        } else {
            self.cloudProvider = nil
        }
    }

    func classify(_ snapshot: TaskSnapshot, memoryContext: String = "") async -> LLMClassification? {
        let text = formatForLLM(snapshot)
        if _useOllama {
            do {
                return try await ollamaProvider.classify(text, context: memoryContext)
            } catch {
                _useOllama = false
            }
        }

        if let cloud = cloudProvider {
            return try? await cloud.classify(text, context: memoryContext)
        }

        return fallbackClassification(snapshot)
    }

    func rawQuery(_ prompt: String) async -> String? {
        if _useOllama {
            do {
                let result = try await ollamaProvider.classify(prompt, context: "")
                return result.reason
            } catch { /* fall through */ }
        }
        if let cloud = cloudProvider {
            let result = try? await cloud.classify(prompt, context: "")
            return result?.reason
        }
        return nil
    }

    func checkOllamaStatus() async {
        _useOllama = await ollamaProvider.isAvailable()
    }

    private func formatForLLM(_ s: TaskSnapshot) -> String {
        var parts = ["标题: \(s.title)"]
        if !s.body.isEmpty { parts.append("内容: \(s.body)") }
        if let app = s.appName { parts.append("来源: \(app)") }
        if let sender = s.sender { parts.append("发送人: \(sender)") }
        parts.append("时间: \(s.createdAt.relativeDisplay)")
        return parts.joined(separator: "\n")
    }

    private func fallbackClassification(_ s: TaskSnapshot) -> LLMClassification {
        LLMClassification(
            category: "other",
            urgency: s.urgency,
            importance: s.importance,
            reason: "LLM 不可用，使用默认分类",
            suggestedAction: "review"
        )
    }
}
