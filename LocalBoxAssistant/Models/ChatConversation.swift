import Foundation

struct ChatConversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func initial() -> ChatConversation {
        ChatConversation(
            title: "New Chat",
            messages: [
                ChatMessage(
                    role: .assistant,
                    text: "LocalBoxAssistantへようこそ。ローカルLLMに質問してください。",
                    createdAt: Date()
                )
            ]
        )
    }
}
