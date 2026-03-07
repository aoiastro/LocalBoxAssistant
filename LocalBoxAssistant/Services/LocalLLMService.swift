import Foundation

protocol LocalLLMService {
    func generateReply(
        history: [ChatMessage],
        userInput: String,
        options: GenerationOptions,
        userImageURLs: [URL],
        onToken: (@Sendable (String) async -> Void)?
    ) async throws -> String
}
