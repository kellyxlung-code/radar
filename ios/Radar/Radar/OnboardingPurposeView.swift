import SwiftUI

struct OnboardingPurposeView: View {
    @State private var selectedPurpose: String? = nil
    @State private var navigateToNext = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.7, green: 0.85, blue: 1.0),
                        Color(red: 0.85, green: 0.95, blue: 0.85),
                        Color(red: 1.0, green: 0.95, blue: 0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    Text("i am here to...")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    VStack(spacing: 20) {
                        PurposeButton(
                            emoji: "✨",
                            text: "discover new places",
                            isSelected: selectedPurpose == "discover"
                        ) {
                            selectedPurpose = "discover"
                            navigateNext()
                        }

                        PurposeButton(
                            emoji: "📝",
                            text: "save my places",
                            isSelected: selectedPurpose == "save"
                        ) {
                            selectedPurpose = "save"
                            navigateNext()
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $navigateToNext) {
                ImportPlacesView()
            }
        }
    }

    private func navigateNext() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigateToNext = true
        }
    }
}

struct PurposeButton: View {
    let emoji: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(emoji)
                    .font(.system(size: 24))

                Text(text)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSelected ? Color.black : Color.black.opacity(0.7))
            )
        }
    }
}

#Preview {
    OnboardingPurposeView()
}

