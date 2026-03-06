import SwiftUI

@main
struct LocalBoxAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: ChatViewModel(service: MLXChatService()))
        }
    }
}
