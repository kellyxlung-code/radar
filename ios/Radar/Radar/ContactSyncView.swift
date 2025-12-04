import SwiftUI
import Contacts

struct ContactSyncView: View {
    @State private var navigateToImportTutorial = false
    @State private var isLoading = false
    @State private var friendsFound = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "FC7339")
                .opacity(0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "FC7339"))
                
                // Title
                VStack(spacing: 12) {
                    Text("Find your friends")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("See which of your contacts are on Radar and discover places they love")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Finding friends...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if friendsFound > 0 {
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 60))
                        
                        Text("\(friendsFound) friends found!")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color(hex: "FC7339"))
                    }
                    .padding(.vertical, 40)
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: syncContacts) {
                        Text("Sync Contacts")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "FC7339"))
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        navigateToImportTutorial = true
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $navigateToImportTutorial) {
            OnboardingPurposeView()
        }
    }
    
    func syncContacts() {
        isLoading = true
        
        // Request contacts permission
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    // TODO: Upload contacts to backend to find matches
                    // For now, simulate finding friends
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        friendsFound = Int.random(in: 3...15)
                        isLoading = false
                        
                        // Auto-advance after showing results
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            navigateToImportTutorial = true
                        }
                    }
                } else {
                    isLoading = false
                    // Show error or skip
                    navigateToImportTutorial = true
                }
            }
        }
    }
}

#Preview {
    ContactSyncView()
}

