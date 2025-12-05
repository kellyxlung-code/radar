import SwiftUI

struct ChatView: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "hey! i'm your radar ai. i'll help you find cool spots in hk. just ask me what you're looking for and i'll hook you up with some recs ✨", isUser: false, places: [])
    ]
    @State private var isSending = false
    @State private var selectedPlace: GooglePlaceResult? = nil
    @State private var showPlaceDetail = false

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
                                ChatBubble(message: message, onPlaceTap: { place in
                                    selectedPlace = place
                                    showPlaceDetail = true
                                })
                            }
                        }
                        .padding()
                    }

                    // Suggested prompts (if only the first system message)
                    if messages.count == 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                SuggestedPrompt(text: "where should i go for coffee?")
                                    .onTapGesture { quickSend("where should i go for coffee?") }
                                SuggestedPrompt(text: "best bars in central")
                                    .onTapGesture { quickSend("best bars in central") }
                                SuggestedPrompt(text: "italian food")
                                    .onTapGesture { quickSend("i want italian food") }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }

                    // Input bar
                    HStack(spacing: 12) {
                        TextField("ask me anything...", text: $messageText)
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
                
                // Place detail bottom sheet
                if showPlaceDetail, let place = selectedPlace {
                    ChatPlaceBottomSheet(
                        result: place,
                        isPresented: $showPlaceDetail
                    )
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
        messages.append(ChatMessage(text: trimmed, isUser: true, places: []))
        messageText = ""
        isSending = true

        Task {
            do {
                let (reply, places) = try await ChatAPI.shared.send(message: trimmed)
                await MainActor.run {
                    messages.append(ChatMessage(text: reply, isUser: false, places: places))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages.append(
                        ChatMessage(
                            text: "hmm, i couldn't reply just now. please try again in a moment.",
                            isUser: false,
                            places: []
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
    let places: [GooglePlaceResult]
}

struct ChatBubble: View {
    let message: ChatMessage
    let onPlaceTap: (GooglePlaceResult) -> Void

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Text bubble
            HStack {
                if message.isUser { Spacer() }

                Text(message.text)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.black : Color(white: 0.95))
                    )
                    .foregroundColor(message.isUser ? .white : .black)

                if !message.isUser { Spacer() }
            }
            
            // Place cards (only for AI messages)
            if !message.isUser && !message.places.isEmpty {
                VStack(spacing: 12) {
                    ForEach(message.places) { place in
                        PlaceCard(place: place)
                            .onTapGesture {
                                onPlaceTap(place)
                            }
                    }
                }
            }
        }
    }
}

struct PlaceCard: View {
    let place: GooglePlaceResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo
            if let photoUrl = place.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(12)
                    case .failure(_), .empty, _:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(place.address)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            )
    }
}

struct ChatPlaceBottomSheet: View {
    let result: GooglePlaceResult
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(result.name)
                        .font(.title2.bold())
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                
                // Photo
                if let photoUrl = result.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure(_), .empty, _:
                            placeholderImage
                        }
                    }
                }
                
                // Rating
                if let rating = result.rating {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                
                // Address
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                    Text(result.address)
                        .font(.body)
                        .foregroundColor(.gray)
                }
                
                // Directions button
                Button(action: openDirections) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 20))
                        Text("Directions")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
        )
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }
    
    private func openDirections() {
        let coordinate = "\(result.lat),\(result.lng)"
        let placeName = result.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "http://maps.apple.com/?daddr=\(coordinate)&q=\(placeName)") {
            UIApplication.shared.open(url)
        }
    }
}

struct SuggestedPrompt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.black)
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
