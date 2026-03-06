import Foundation

enum ChatRole: Equatable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let createdAt: Date
}
