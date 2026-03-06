import Foundation

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: ChatRole
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, text: String, createdAt: Date) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
