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

            ListView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    Text("lists")
                }
                .tag(2)

            ChatView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                    Text("chat")
                }
                .tag(3)
        }
        .tint(Color(hex: "FC7339")) // iOS 15+ accent for icons/text
    }
}

#Preview {
    MainTabView()
}

