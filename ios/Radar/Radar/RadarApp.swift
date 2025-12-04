import SwiftUI

@main
struct RadarApp: App {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @State private var showLocationPermission = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isAuthenticated {
                    MainTabView()
                        .onAppear {
                            let hasAskedLocation = UserDefaults.standard.bool(forKey: "hasAskedLocation")
                            if !hasAskedLocation {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    showLocationPermission = true
                                    UserDefaults.standard.set(true, forKey: "hasAskedLocation")
                                }
                            }
                        }
                } else {
                    SplashScreen()
                }

                if showLocationPermission {
                    LocationPermissionView {
                        showLocationPermission = false
                    }
                }
            }
        }
    }
}
