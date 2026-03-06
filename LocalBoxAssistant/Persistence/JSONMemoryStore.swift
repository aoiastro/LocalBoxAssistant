import Foundation

struct AppMemorySnapshot: Codable {
    var conversations: [ChatConversation]
    var selectedConversationID: UUID?
    var options: GenerationOptions
}

actor JSONMemoryStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> AppMemorySnapshot {
        let snapshotURL = try snapshotFileURL()
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            let initialConversation = ChatConversation.initial()
            return AppMemorySnapshot(
                conversations: [initialConversation],
                selectedConversationID: initialConversation.id,
                options: .default
            )
        }

        let data = try Data(contentsOf: snapshotURL)
        var snapshot = try decoder.decode(AppMemorySnapshot.self, from: data)

        if snapshot.conversations.isEmpty {
            let initialConversation = ChatConversation.initial()
            snapshot.conversations = [initialConversation]
            snapshot.selectedConversationID = initialConversation.id
        }

        if snapshot.selectedConversationID == nil {
            snapshot.selectedConversationID = snapshot.conversations.first?.id
        }

        return snapshot
    }

    func save(snapshot: AppMemorySnapshot) throws {
        let snapshotURL = try snapshotFileURL()
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    private func snapshotFileURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LocalLLMError.memoryStoreFailed("Application Support directory unavailable")
        }

        let appDirectory = appSupport.appendingPathComponent("LocalBoxAssistant", isDirectory: true)
        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        return appDirectory.appendingPathComponent("memory.json", isDirectory: false)
    }
}
