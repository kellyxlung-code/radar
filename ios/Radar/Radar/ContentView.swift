import SwiftUI

struct ContentView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false

    var body: some View {
        if isAuthenticated {
            // Logged-in experience
            MainTabView()
        } else {
            // Onboarding + phone auth flow
            NavigationStack {
                PhoneEntryView()
            }
        }
    }
}

