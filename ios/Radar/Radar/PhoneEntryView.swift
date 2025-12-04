import SwiftUI

struct PhoneEntryView: View {
    @State private var phoneNumber: String = ""
    @State private var showPhoneAuth = false
    @State private var isSendingOTP = false
    @State private var errorMessage: String?
    @FocusState private var isPhoneFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color(hex: "FC7339")
                .opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "FC7339"))

                VStack(spacing: 12) {
                    Text("Enter your phone number")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("We'll send you a verification code")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // Phone input + button
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("🇭🇰")
                                .font(.system(size: 24))
                            Text("+852")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .font(.system(size: 18))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isPhoneFocused)
                    }
                    .padding(.horizontal, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Button(action: sendOTP) {
                        if isSendingOTP {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        canSubmit ? Color(hex: "FC7339") : Color.gray
                    )
                    .cornerRadius(12)
                    .disabled(!canSubmit || isSendingOTP)
                    .padding(.horizontal, 24)
                }

                Spacer()

                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFocused = true
            }
        }
        .fullScreenCover(isPresented: $showPhoneAuth) {
            PhoneAuthView(phoneNumber: phoneNumber)
        }
    }

    private var canSubmit: Bool {
        phoneNumber.trimmingCharacters(in: .whitespaces).count >= 8
    }

    private func sendOTP() {
        guard canSubmit else { return }
        isSendingOTP = true
        errorMessage = nil

        APIService.shared.sendOTP(phoneNumber: phoneNumber) { result in
            DispatchQueue.main.async {
                isSendingOTP = false
                switch result {
                case .success:
                    showPhoneAuth = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    PhoneEntryView()
}

