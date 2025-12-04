import Foundation

// MARK: - Auth Models

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let user_id: Int?        // Backend returns this in MVP mode
    let mvp_bypass: Bool?    // Backend returns this in MVP mode
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()
    private init() {}

    private let baseURL = Config.apiBaseURL

    // Send OTP to phone
    func sendOTP(phoneNumber: String,
                 completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/send-otp") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "phone_number": phoneNumber
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }.resume()
    }

    // Verify OTP + set password => returns JWT
    func verifyOTP(phoneNumber: String,
                   otpCode: String,
                   password: String,
                   completion: @escaping (Result<TokenResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/verify-otp") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "phone_number": phoneNumber,
            "otp_code": otpCode,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OTP Error:", error.localizedDescription)
                completion(.failure(error))
                return
            }
            
            // Log HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("ℹ️ OTP Response Status:", httpResponse.statusCode)
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            // Log raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("ℹ️ OTP Response JSON:", jsonString)
            }

            do {
                let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
                print("✅ OTP Success! Token:", decoded.access_token.prefix(20), "...")
                completion(.success(decoded))
            } catch {
                print("❌ OTP Decode Error:", error)
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, _):
                        print("  Missing key:", key.stringValue)
                    case .typeMismatch(let type, let context):
                        print("  Type mismatch:", type, "at", context.codingPath)
                    case .valueNotFound(let type, let context):
                        print("  Value not found:", type, "at", context.codingPath)
                    case .dataCorrupted(let context):
                        print("  Data corrupted:", context)
                    @unknown default:
                        print("  Unknown decoding error")
                    }
                }
                completion(.failure(error))
            }
        }.resume()
    }
}
