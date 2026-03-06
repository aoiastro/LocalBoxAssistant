import Foundation

#if canImport(MLX)
import MLX
#endif

#if canImport(MLXLLM)
import MLXLLM
#endif

#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

enum LocalLLMError: LocalizedError {
    case emptyInput
    case modelDownloadFailed(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "入力が空です。"
        case .modelDownloadFailed(let detail):
            return "モデルのダウンロードに失敗しました: \(detail)"
        case .generationFailed(let detail):
            return "生成に失敗しました: \(detail)"
        }
    }
}

final class MLXChatService: LocalLLMService {
    private let downloader = HuggingFaceModelDownloader()
    private let modelConfig: HFModelConfig
    private let systemPrompt = "あなたは端的で正確なアシスタントです。"

    #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
    private var cachedContainer: ModelContainer?
    #endif

    init(modelConfig: HFModelConfig = .default) {
        self.modelConfig = modelConfig
    }

    func generateReply(history: [ChatMessage], userInput: String) async throws -> String {
        let prompt = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw LocalLLMError.emptyInput
        }

        let localModelDirectory = try await downloader.ensureModelDownloaded(config: modelConfig)

        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
        let container = try await loadModelContainer(from: localModelDirectory)
        let chatMessages = buildChatMessages(history: history, latestUserInput: prompt)
        let input = UserInput(chat: chatMessages)
        let parameters = GenerateParameters(
            maxTokens: 512,
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.05,
            repetitionContextSize: 128
        )

        let responseText = try await container.perform { (context: ModelContext) in
            let lmInput = try await context.processor.prepare(input: input)
            var assembled = ""
            for await generation in try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameters,
                context: context
            ) {
                switch generation {
                case .chunk(let text):
                    assembled += text
                case .toolCall:
                    break
                case .info:
                    break
                }
            }
            return assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if responseText.isEmpty {
            throw LocalLLMError.generationFailed("empty model output")
        }
        return responseText
        #else
        return "[Fallback] (\(localModelDirectory.lastPathComponent)) \(prompt)"
        #endif
    }

    #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
    private func loadModelContainer(from directory: URL) async throws -> ModelContainer {
        if let cachedContainer {
            return cachedContainer
        }

        Memory.cacheLimit = 32 * 1024 * 1024
        let configuration = ModelConfiguration(directory: directory)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)
        cachedContainer = container
        return container
    }

    private func buildChatMessages(history: [ChatMessage], latestUserInput: String) -> [Chat.Message] {
        var messages: [Chat.Message] = [.init(role: .system, content: systemPrompt)]
        for message in history {
            let role: Chat.Message.Role = message.role == .assistant ? .assistant : .user
            messages.append(.init(role: role, content: message.text))
        }

        if history.last?.text != latestUserInput || history.last?.role != .user {
            messages.append(.init(role: .user, content: latestUserInput))
        }

        return messages
    }
    #endif
}
