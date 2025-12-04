import SwiftUI

struct PhoneAuthView: View {
    let phoneNumber: String

    @State private var verificationCode = ""
    @State private var navigateToContactSync = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Background
            Color(hex: "FC7339")
                .opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "FC7339"))

                VStack(spacing: 8) {
                    Text("Enter verification code")
                        .font(.system(size: 28, weight: .bold))

                    Text("Sent to +852 \(phoneNumber)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                // Code input
                TextField("6-digit code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .onChange(of: verificationCode) { newValue in
                        if newValue.count > 6 {
                            verificationCode = String(newValue.prefix(6))
                        }
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 40)
                }

                Button(action: verifyCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify & Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canSubmit ? Color(hex: "FC7339") : Color.gray
                )
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .disabled(!canSubmit || isLoading)

                Button(action: resendCode) {
                    Text("Didn't receive code? Resend")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "FC7339"))
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $navigateToContactSync) {
            ContactSyncView()
        }
    }

    private var canSubmit: Bool {
        verificationCode.count == 6
    }

    private func verifyCode() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        APIService.shared.verifyOTP(
            phoneNumber: phoneNumber,
            otpCode: verificationCode,
            password: "dummy123"  // Backend doesn't validate password in MVP mode
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let tokenResponse):
                    // 1) Save JWT so rest of app (Chat, Share, etc.) can use it
                    KeychainHelper.shared.saveAccessToken(tokenResponse.access_token)

                    // 2) Optionally store basic auth flags
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(self.phoneNumber, forKey: "userPhone")

                    // 3) Navigate into app
                    navigateToContactSync = true

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resendCode() {
        // For now just log; you can wire to /auth/send-otp again
        print("Resending code to +852\(phoneNumber)")
    }
}

#Preview {
    PhoneAuthView(phoneNumber: "12345678")
}
