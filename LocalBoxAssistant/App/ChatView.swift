import SwiftUI

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                bubble(for: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let last = viewModel.messages.last {
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

                HStack(spacing: 8) {
                    TextField("メッセージを入力", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        viewModel.send()
                    } label: {
                        if viewModel.isGenerating {
                            ProgressView()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .disabled(viewModel.isGenerating)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("LocalBoxAssistant")
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
                }
            }
        }
    }
}
