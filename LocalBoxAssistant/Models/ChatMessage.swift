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
    var imagePaths: [String]

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date,
        imagePaths: [String] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.imagePaths = imagePaths
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case createdAt
        case imagePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        imagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths) ?? []
    }
}
