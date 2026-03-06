import Foundation

protocol LocalLLMService {
    func generateReply(history: [ChatMessage], userInput: String) async throws -> String
}
