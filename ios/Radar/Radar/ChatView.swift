import SwiftUI

struct ChatView: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hey! I'm your Radar AI assistant. Ask me anything about places in Hong Kong!", isUser: false)
    ]
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ WHITE BACKGROUND
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                            }
                        }
                        .padding()
                    }

                    // Suggested prompts (if only the first system message)
                    if messages.count == 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                SuggestedPrompt(text: "Where should I go for coffee?")
                                    .onTapGesture { quickSend("Where should I go for coffee?") }
                                SuggestedPrompt(text: "Best bars in Central")
                                    .onTapGesture { quickSend("Best bars in Central") }
                                SuggestedPrompt(text: "Show me activities")
                                    .onTapGesture { quickSend("Show me activities in Hong Kong") }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }

                    // Input bar
                    HStack(spacing: 12) {
                        TextField("Ask me anything...", text: $messageText)
                            .padding(12)
                            .foregroundColor(.black)  // ✅ BLACK TEXT INPUT
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(white: 0.95))  // Light grey background
                            )

                        Button(action: sendMessage) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(messageText.isEmpty ? .gray : .black)
                            }
                        }
                        .disabled(messageText.isEmpty || isSending)
                    }
                    .padding()
                    .background(Color.white)  // ✅ WHITE BACKGROUND
                }
            }
            .navigationTitle("chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func quickSend(_ text: String) {
        messageText = text
        sendMessage()
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(text: trimmed, isUser: true))
        messageText = ""
        isSending = true

        Task {
            do {
                let reply = try await ChatAPI.shared.send(message: trimmed)
                await MainActor.run {
                    messages.append(ChatMessage(text: reply, isUser: false))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages.append(
                        ChatMessage(
                            text: "Hmm, I couldn't reply just now. Please try again in a moment.",
                            isUser: false
                        )
                    )
                    isSending = false
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.isUser ? Color.black : Color(white: 0.95))  // Light grey for AI messages
                )
                .foregroundColor(message.isUser ? .white : .black)  // ✅ BLACK TEXT for AI messages

            if !message.isUser { Spacer() }
        }
    }
}

struct SuggestedPrompt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.black)  // ✅ BLACK TEXT
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    ChatView()
}
