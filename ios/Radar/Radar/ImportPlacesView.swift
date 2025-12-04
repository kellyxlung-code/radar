import SwiftUI

struct ImportPlacesView: View {
    @State private var selectedMethods: Set<String> = []
    @State private var navigateToMainApp = false
    @State private var showLocationPermission = false

    var body: some View {
        ZStack {
            // Background
            Color(hex: "FC7339")
                .opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Icon
                Text("📥")
                    .font(.system(size: 80))

                // Title
                VStack(spacing: 12) {
                    Text("Import places to\nsetup your map")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text("Choose at least one method")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                // Method cards
                VStack(spacing: 16) {
                    ImportMethodCard(
                        icons: ["📷", "🎵"],
                        title: "Instagram & TikTok",
                        subtitle: "Paste links to import",
                        isSelected: selectedMethods.contains("social")
                    ) {
                        toggleMethod("social")
                    }

                    ImportMethodCard(
                        icons: ["📍"],
                        title: "Google Maps Lists",
                        subtitle: "Import saved places",
                        isSelected: selectedMethods.contains("maps")
                    ) {
                        toggleMethod("maps")
                    }

                    ImportMethodCard(
                        icons: ["📝"],
                        title: "Text or Notes",
                        subtitle: "Copy and paste",
                        isSelected: selectedMethods.contains("notes")
                    ) {
                        toggleMethod("notes")
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                Button(action: {
                    // Show location permission first
                    showLocationPermission = true
                }) {
                    Text(selectedMethods.isEmpty ? "Skip for now" : "Continue to Radar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedMethods.isEmpty ? Color.gray : Color(hex: "FC7339")
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay {
            if showLocationPermission {
                LocationPermissionView {
                    showLocationPermission = false
                    navigateToMainApp = true
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToMainApp) {
            MainTabView()
        }
    }

    private func toggleMethod(_ method: String) {
        if selectedMethods.contains(method) {
            selectedMethods.remove(method)
        } else {
            selectedMethods.insert(method)
        }
    }
}

struct ImportMethodCard: View {
    let icons: [String]
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icons
                HStack(spacing: -8) {
                    ForEach(icons, id: \.self) { icon in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(icon)
                                    .font(.system(size: 24))
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "FC7339"))
                        .font(.system(size: 28))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
    }
}

#Preview {
    ImportPlacesView()
}

