import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            text: "LocalBoxAssistantへようこそ。ローカルLLMに質問してください。",
            createdAt: Date()
        )
    ]
    @Published var inputText = ""
    @Published var isGenerating = false
    @Published var errorText: String?

    private let service: LocalLLMService

    init(service: LocalLLMService) {
        self.service = service
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, text: trimmed, createdAt: Date())
        messages.append(userMessage)
        inputText = ""
        isGenerating = true
        errorText = nil

        Task {
            do {
                let reply = try await service.generateReply(history: messages, userInput: trimmed)
                let assistantMessage = ChatMessage(role: .assistant, text: reply, createdAt: Date())
                messages.append(assistantMessage)
            } catch {
                errorText = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
