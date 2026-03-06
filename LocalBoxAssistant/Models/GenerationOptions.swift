import Foundation

struct GenerationOptions: Codable, Equatable {
    var temperature: Double
    var topP: Double
    var maxTokens: Int
    var repetitionPenalty: Double
    var repetitionContextSize: Int
    var systemPrompt: String
    var modelID: String
    var modelRevision: String
    var hfToken: String

    static let `default` = GenerationOptions(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 512,
        repetitionPenalty: 1.05,
        repetitionContextSize: 128,
        systemPrompt: "あなたは端的で正確なアシスタントです。",
        modelID: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        modelRevision: "main",
        hfToken: ""
    )
}
