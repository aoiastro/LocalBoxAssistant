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
    var wakeWord: String
    var robotVisionModelID: String
    var robotAutoSpeak: Bool

    static let `default` = GenerationOptions(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 512,
        repetitionPenalty: 1.05,
        repetitionContextSize: 128,
        systemPrompt: "あなたは端的で正確なアシスタントです。",
        modelID: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        modelRevision: "main",
        hfToken: "",
        wakeWord: "箱",
        robotVisionModelID: "mlx-community/LFM2.5-VL-1.6B-4bit",
        robotAutoSpeak: true
    )

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP
        case maxTokens
        case repetitionPenalty
        case repetitionContextSize
        case systemPrompt
        case modelID
        case modelRevision
        case hfToken
        case wakeWord
        case robotVisionModelID
        case robotAutoSpeak
    }

    init(
        temperature: Double,
        topP: Double,
        maxTokens: Int,
        repetitionPenalty: Double,
        repetitionContextSize: Int,
        systemPrompt: String,
        modelID: String,
        modelRevision: String,
        hfToken: String,
        wakeWord: String,
        robotVisionModelID: String,
        robotAutoSpeak: Bool
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
        self.systemPrompt = systemPrompt
        self.modelID = modelID
        self.modelRevision = modelRevision
        self.hfToken = hfToken
        self.wakeWord = wakeWord
        self.robotVisionModelID = robotVisionModelID
        self.robotAutoSpeak = robotAutoSpeak
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.default
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? d.temperature
        topP = try container.decodeIfPresent(Double.self, forKey: .topP) ?? d.topP
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? d.maxTokens
        repetitionPenalty = try container.decodeIfPresent(Double.self, forKey: .repetitionPenalty) ?? d.repetitionPenalty
        repetitionContextSize = try container.decodeIfPresent(Int.self, forKey: .repetitionContextSize) ?? d.repetitionContextSize
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? d.systemPrompt
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID) ?? d.modelID
        modelRevision = try container.decodeIfPresent(String.self, forKey: .modelRevision) ?? d.modelRevision
        hfToken = try container.decodeIfPresent(String.self, forKey: .hfToken) ?? d.hfToken
        wakeWord = try container.decodeIfPresent(String.self, forKey: .wakeWord) ?? d.wakeWord
        robotVisionModelID = try container.decodeIfPresent(String.self, forKey: .robotVisionModelID) ?? d.robotVisionModelID
        robotAutoSpeak = try container.decodeIfPresent(Bool.self, forKey: .robotAutoSpeak) ?? d.robotAutoSpeak
    }
}
