import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversations: [ChatConversation] = []
    @Published var selectedConversationID: UUID?
    @Published var inputText = ""
    @Published var isGenerating = false
    @Published var errorText: String?
    @Published var options: GenerationOptions = .default
    @Published var showSettings = false
    @Published var showConversationList = false

    @Published var isRobotModeEnabled = false
    @Published var robotState: RobotState = .idle
    @Published var wakeTranscript = ""
    @Published var selectedImageURL: URL?

    var currentMessages: [ChatMessage] {
        guard let currentIndex else { return [] }
        return conversations[currentIndex].messages
    }

    var currentConversationTitle: String {
        guard let currentIndex else { return "LocalBoxAssistant" }
        return conversations[currentIndex].title
    }

    var orderedConversations: [ChatConversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    private let service: LocalLLMService
    private let memoryStore = JSONMemoryStore()
    private let speechToText = SpeechToTextService()
    private let textToSpeech = TextToSpeechService()
    private let frontCamera = FrontCameraCaptureService()
    private var generationTask: Task<Void, Never>?
    private var isWakeWordTriggerInFlight = false

    private var currentIndex: Int? {
        guard let selectedConversationID else { return nil }
        return conversations.firstIndex { $0.id == selectedConversationID }
    }

    init(service: LocalLLMService) {
        self.service = service
        Task {
            await loadMemory()
        }
    }

    func setSelectedImageURL(_ url: URL?) {
        selectedImageURL = url
    }

    func setRobotModeEnabled(_ enabled: Bool) {
        isRobotModeEnabled = enabled
        if enabled {
            Task {
                await startWakeWordListening()
            }
        } else {
            stopWakeWordListening()
            textToSpeech.stop()
            robotState = .idle
        }
    }

    func startWakeWordListening() async {
        do {
            try await speechToText.requestPermissions()
            try speechToText.startListening { [weak self] text in
                Task { @MainActor in
                    self?.handleWakeWordTranscript(text)
                }
            }
            robotState = .listening
        } catch {
            errorText = error.localizedDescription
            robotState = .idle
        }
    }

    func stopWakeWordListening() {
        speechToText.stopListening()
        wakeTranscript = ""
    }

    func send() {
        sendInternal(userInput: inputText, fromWakeWord: false, attachedImageURLs: nil)
    }

    private func sendInternal(userInput: String, fromWakeWord: Bool, attachedImageURLs: [URL]?) {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        guard let conversationID = ensureActiveConversation(),
              let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        let now = Date()
        let imageURLs: [URL] = attachedImageURLs ?? (selectedImageURL.map { [$0] } ?? [])
        let userMessage = ChatMessage(
            role: .user,
            text: trimmed,
            createdAt: now,
            imagePaths: imageURLs.map(\.path)
        )

        conversations[conversationIndex].messages.append(userMessage)
        conversations[conversationIndex].updatedAt = now
        if conversations[conversationIndex].title == "New Chat" {
            conversations[conversationIndex].title = String(trimmed.prefix(24))
        }
        let requestHistory = conversations[conversationIndex].messages

        let assistantMessageID = UUID()
        conversations[conversationIndex].messages.append(
            ChatMessage(id: assistantMessageID, role: .assistant, text: "", createdAt: now)
        )

        inputText = ""
        isGenerating = true
        errorText = nil
        robotState = .thinking
        persistSnapshot()

        var selectedOptions = options
        if fromWakeWord {
            selectedOptions.modelID = options.robotVisionModelID
        }

        generationTask = Task {
            do {
                let reply = try await service.generateReply(
                    history: requestHistory,
                    userInput: trimmed,
                    options: selectedOptions,
                    userImageURLs: imageURLs
                ) { token in
                    await MainActor.run {
                        self.appendToken(
                            token,
                            conversationID: conversationID,
                            assistantMessageID: assistantMessageID
                        )
                    }
                }

                if let pair = self.messageIndex(conversationID: conversationID, messageID: assistantMessageID),
                   conversations[pair.0].messages[pair.1].text.isEmpty {
                    conversations[pair.0].messages[pair.1].text = reply
                }
                touchConversation(conversationID)
                persistSnapshot()

                if isRobotModeEnabled && options.robotAutoSpeak {
                    robotState = .speaking
                    textToSpeech.speak(reply) { [weak self] in
                        Task { @MainActor in
                            guard let self else { return }
                            self.robotState = self.isRobotModeEnabled ? .listening : .idle
                        }
                    }
                } else {
                    robotState = isRobotModeEnabled ? .listening : .idle
                }
            } catch is CancellationError {
                cleanupEmptyAssistantMessage(conversationID: conversationID, assistantMessageID: assistantMessageID)
                persistSnapshot()
                robotState = isRobotModeEnabled ? .listening : .idle
            } catch {
                cleanupEmptyAssistantMessage(conversationID: conversationID, assistantMessageID: assistantMessageID)
                errorText = error.localizedDescription
                persistSnapshot()
                robotState = isRobotModeEnabled ? .listening : .idle
            }

            isGenerating = false
            generationTask = nil
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        robotState = isRobotModeEnabled ? .listening : .idle
    }

    func clearCurrentConversation() {
        cancelGeneration()
        guard let conversationID = ensureActiveConversation(),
              let idx = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        conversations[idx].messages = [
            ChatMessage(
                role: .assistant,
                text: "会話をリセットしました。新しく質問してください。",
                createdAt: Date()
            )
        ]
        conversations[idx].updatedAt = Date()
        conversations[idx].title = "New Chat"
        errorText = nil
        persistSnapshot()
    }

    func createConversation() {
        cancelGeneration()
        let conversation = ChatConversation.initial()
        conversations.append(conversation)
        selectedConversationID = conversation.id
        errorText = nil
        persistSnapshot()
    }

    func selectConversation(_ id: UUID) {
        cancelGeneration()
        guard conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
        errorText = nil
        persistSnapshot()
    }

    func deleteConversations(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        cancelGeneration()

        let deletedSet = Set(ids)
        conversations.removeAll { deletedSet.contains($0.id) }

        if conversations.isEmpty {
            let initialConversation = ChatConversation.initial()
            conversations = [initialConversation]
            selectedConversationID = initialConversation.id
        } else if let currentSelectedID = selectedConversationID, deletedSet.contains(currentSelectedID) {
            selectedConversationID = conversations.sorted { $0.updatedAt > $1.updatedAt }.first?.id
        }

        persistSnapshot()
    }

    func persistOptionsChange() {
        persistSnapshot()
    }

    private func handleWakeWordTranscript(_ text: String) {
        wakeTranscript = text
        guard isRobotModeEnabled, !isGenerating else { return }

        let wake = options.wakeWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wake.isEmpty else { return }
        guard text.contains(wake) else { return }

        let command = extractCommand(from: text, wakeWord: wake)
        guard !command.isEmpty else { return }
        guard !isWakeWordTriggerInFlight else { return }
        isWakeWordTriggerInFlight = true

        Task {
            defer { self.isWakeWordTriggerInFlight = false }
            do {
                let frontImageURL = try await frontCamera.captureFrontPhoto()
                selectedImageURL = frontImageURL
                sendInternal(userInput: command, fromWakeWord: true, attachedImageURLs: [frontImageURL])
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func extractCommand(from text: String, wakeWord: String) -> String {
        guard let range = text.range(of: wakeWord, options: .backwards) else { return "" }
        let suffix = text[range.upperBound...]
        return suffix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadMemory() async {
        do {
            let snapshot = try await memoryStore.load()
            conversations = snapshot.conversations
            options = snapshot.options
            selectedConversationID = snapshot.selectedConversationID ?? snapshot.conversations.first?.id
        } catch {
            let initialConversation = ChatConversation.initial()
            conversations = [initialConversation]
            selectedConversationID = initialConversation.id
            options = .default
            errorText = error.localizedDescription
        }
    }

    private func persistSnapshot() {
        let snapshot = AppMemorySnapshot(
            conversations: conversations,
            selectedConversationID: selectedConversationID,
            options: options
        )

        Task {
            do {
                try await memoryStore.save(snapshot: snapshot)
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func ensureActiveConversation() -> UUID? {
        if let selectedConversationID,
           conversations.contains(where: { $0.id == selectedConversationID }) {
            return selectedConversationID
        }

        if let firstID = conversations.first?.id {
            selectedConversationID = firstID
            return firstID
        }

        let conversation = ChatConversation.initial()
        conversations = [conversation]
        selectedConversationID = conversation.id
        return conversation.id
    }

    private func appendToken(_ token: String, conversationID: UUID, assistantMessageID: UUID) {
        guard let pair = messageIndex(conversationID: conversationID, messageID: assistantMessageID) else { return }
        conversations[pair.0].messages[pair.1].text += token
    }

    private func cleanupEmptyAssistantMessage(conversationID: UUID, assistantMessageID: UUID) {
        guard let pair = messageIndex(conversationID: conversationID, messageID: assistantMessageID) else { return }
        if conversations[pair.0].messages[pair.1].text.isEmpty {
            conversations[pair.0].messages.remove(at: pair.1)
        }
    }

    private func touchConversation(_ conversationID: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].updatedAt = Date()
    }

    private func messageIndex(conversationID: UUID, messageID: UUID) -> (Int, Int)? {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return nil
        }

        guard let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return nil
        }

        return (conversationIndex, messageIndex)
    }
}
