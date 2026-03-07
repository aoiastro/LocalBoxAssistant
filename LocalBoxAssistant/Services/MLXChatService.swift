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
    case invalidModelID
    case modelDownloadFailed(String)
    case generationFailed(String)
    case memoryStoreFailed(String)
    case sttFailed(String)
    case cameraFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "入力が空です。"
        case .invalidModelID:
            return "HF Model ID が空です。例: mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        case .modelDownloadFailed(let detail):
            return "モデルのダウンロードに失敗しました: \(detail)"
        case .generationFailed(let detail):
            return "生成に失敗しました: \(detail)"
        case .memoryStoreFailed(let detail):
            return "メモリ保存に失敗しました: \(detail)"
        case .sttFailed(let detail):
            return "音声認識に失敗しました: \(detail)"
        case .cameraFailed(let detail):
            return "カメラ処理に失敗しました: \(detail)"
        }
    }
}

final class MLXChatService: LocalLLMService {
    private let downloader = HuggingFaceModelDownloader()

    #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
    private var cachedContainers: [String: ModelContainer] = [:]
    #endif

    init() {}

    func generateReply(history: [ChatMessage], userInput: String) async throws -> String {
        try await generateReply(
            history: history,
            userInput: userInput,
            options: .default,
            userImageURLs: [],
            onToken: nil
        )
    }

    func generateReply(
        history: [ChatMessage],
        userInput: String,
        options: GenerationOptions,
        userImageURLs: [URL],
        onToken: (@Sendable (String) async -> Void)?
    ) async throws -> String {
        let prompt = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw LocalLLMError.emptyInput
        }

        let modelID = options.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else {
            throw LocalLLMError.invalidModelID
        }

        let modelRevision = options.modelRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "main"
            : options.modelRevision.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = options.hfToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelConfig = HFModelConfig(
            repoID: modelID,
            revision: modelRevision,
            files: nil,
            token: token.isEmpty ? nil : token
        )

        let localModelDirectory = try await downloader.ensureModelDownloaded(config: modelConfig)

        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
        let cacheKey = "\(modelConfig.repoID)@\(modelConfig.revision)"
        let container = try await loadModelContainer(from: localModelDirectory, cacheKey: cacheKey)
        let chatMessages = buildChatMessages(
            history: history,
            latestUserInput: prompt,
            latestUserImages: userImageURLs,
            systemPrompt: options.systemPrompt
        )
        let input = UserInput(chat: chatMessages)
        let parameters = GenerateParameters(
            maxTokens: options.maxTokens,
            temperature: Float(options.temperature),
            topP: Float(options.topP),
            repetitionPenalty: Float(options.repetitionPenalty),
            repetitionContextSize: options.repetitionContextSize
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
                    if let onToken {
                        await onToken(text)
                    }
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
    private func loadModelContainer(from directory: URL, cacheKey: String) async throws -> ModelContainer {
        if let cachedContainer = cachedContainers[cacheKey] {
            return cachedContainer
        }

        let configuration = ModelConfiguration(directory: directory)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)
        cachedContainers[cacheKey] = container
        return container
    }

    private func buildChatMessages(
        history: [ChatMessage],
        latestUserInput: String,
        latestUserImages: [URL],
        systemPrompt: String
    ) -> [Chat.Message] {
        var messages: [Chat.Message] = [.init(role: .system, content: systemPrompt)]
        for message in history {
            let role: Chat.Message.Role = message.role == .assistant ? .assistant : .user
            let images = message.imagePaths.map { UserInput.Image.url(URL(fileURLWithPath: $0)) }
            messages.append(.init(role: role, content: message.text, images: images, videos: []))
        }

        if history.last?.text != latestUserInput || history.last?.role != .user {
            let images = latestUserImages.map { UserInput.Image.url($0) }
            messages.append(.init(role: .user, content: latestUserInput, images: images, videos: []))
        }

        return messages
    }
    #endif
}
