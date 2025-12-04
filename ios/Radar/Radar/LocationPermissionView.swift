import SwiftUI
import CoreLocation
import Combine

struct LocationPermissionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(Color(hex: "FC7339"))

                    VStack(spacing: 12) {
                        Text("Enable Location")
                            .font(.system(size: 26, weight: .bold))

                        Text("See places near you and get personalized recommendations based on your location")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        BenefitRow(icon: "mappin.circle.fill", text: "Find nearby saved places")
                        BenefitRow(icon: "figure.walk", text: "See distance to venues")
                        BenefitRow(icon: "star.fill", text: "Discover local favorites")
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        Button(action: {
                            locationManager.requestPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onDismiss()
                                dismiss()
                            }
                        }) {
                            Text("Enable Location")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "FC7339"))
                                .cornerRadius(12)
                        }

                        Button(action: {
                            onDismiss()
                            dismiss()
                        }) {
                            Text("Maybe Later")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "FC7339"))
                .frame(width: 28)

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Location Manager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

