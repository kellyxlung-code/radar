import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Start on Map tab

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDiscoveryView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("home")
                }
                .tag(0)

            MapViewNew()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "map.fill" : "map")
                    Text("map")
                }
                .tag(1)

            ChatView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "message.fill" : "message")
                    Text("chat")
                }
                .tag(2)
        }
        .tint(Color(hex: "FC7339")) // iOS 15+ accent for icons/text
    }
}

#Preview {
    MainTabView()
}

