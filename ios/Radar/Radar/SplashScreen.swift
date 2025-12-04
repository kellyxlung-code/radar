import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    @State private var opacity = 0.0

    var body: some View {
        if isActive {
            PhoneEntryView()
        } else {
            ZStack {
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

                VStack(spacing: 20) {
                    Spacer()

                    Text("🌍")
                        .font(.system(size: 100))
                        .opacity(opacity)

                    Text("radar")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .opacity(opacity)

                    Text("your personal map")
                        .font(.system(size: 18))
                        .foregroundColor(.black.opacity(0.6))
                        .opacity(opacity)

                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreen()
}
