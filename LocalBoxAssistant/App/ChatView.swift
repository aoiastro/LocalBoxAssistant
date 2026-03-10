import PhotosUI
import SwiftUI
import UIKit

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.currentMessages) { message in
                                bubble(for: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.currentMessages.count) {
                        if let last = viewModel.currentMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if let errorText = viewModel.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }

                if let selectedImageURL = viewModel.selectedImageURL,
                   let image = UIImage(contentsOfFile: selectedImageURL.path) {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(selectedImageURL.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button("Remove") {
                            viewModel.setSelectedImageURL(nil)
                            selectedPhotoItem = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .frame(width: 30, height: 30)
                    }

                    TextField("メッセージを入力", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if viewModel.isGenerating {
                            viewModel.cancelGeneration()
                        } else {
                            viewModel.send()
                        }
                    } label: {
                        if viewModel.isGenerating {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle(viewModel.currentConversationTitle)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        viewModel.showConversationList = true
                    } label: {
                        Image(systemName: "text.bubble")
                    }

                    Button {
                        viewModel.createConversation()
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Clear") {
                        viewModel.clearCurrentConversation()
                    }
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(options: $viewModel.options) {
                    viewModel.persistOptionsChange()
                    viewModel.showSettings = false
                }
            }
            .sheet(isPresented: $viewModel.showConversationList) {
                ConversationListView(viewModel: viewModel)
            }
            .onChange(of: selectedPhotoItem) {
                Task {
                    await loadSelectedPhoto()
                }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self) else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("image-\(UUID().uuidString).jpg")
            try data.write(to: tempURL, options: .atomic)
            await MainActor.run {
                viewModel.setSelectedImageURL(tempURL)
            }
        } catch {
            await MainActor.run {
                viewModel.errorText = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.text)
                        .padding(10)
                        .background(Color.gray.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contextMenu {
                            Button("Copy") {
                                UIPasteboard.general.string = message.text
                            }
                        }
                }
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.text)
                        .padding(10)
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contextMenu {
                            Button("Copy") {
                                UIPasteboard.general.string = message.text
                            }
                        }

                    if !message.imagePaths.isEmpty {
                        Text("+ image")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ConversationListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.orderedConversations) { conversation in
                    Button {
                        viewModel.selectConversation(conversation.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if conversation.id == viewModel.selectedConversationID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { viewModel.orderedConversations[$0].id }
                    viewModel.deleteConversations(ids: ids)
                }
            }
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createConversation()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct SettingsView: View {
    @Binding var options: GenerationOptions
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Model (Hugging Face)") {
                    TextField("Model ID", text: $options.modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField("Revision", text: $options.modelRevision)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    SecureField("HF Token (optional)", text: $options.hfToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section("Sampling") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature: \(options.temperature, specifier: "%.2f")")
                        Slider(value: $options.temperature, in: 0...1.5, step: 0.05)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top P: \(options.topP, specifier: "%.2f")")
                        Slider(value: $options.topP, in: 0.1...1.0, step: 0.05)
                    }
                }

                Section("Length / Repetition") {
                    Stepper("Max Tokens: \(options.maxTokens)", value: $options.maxTokens, in: 64...4096, step: 64)
                    Stepper(
                        "Repetition Context: \(options.repetitionContextSize)",
                        value: $options.repetitionContextSize,
                        in: 32...1024,
                        step: 32
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repetition Penalty: \(options.repetitionPenalty, specifier: "%.2f")")
                        Slider(value: $options.repetitionPenalty, in: 1.0...1.5, step: 0.01)
                    }
                }

                Section("System Prompt") {
                    TextField("System Prompt", text: $options.systemPrompt, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Generation Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        options = .default
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
