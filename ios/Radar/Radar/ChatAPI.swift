import Foundation

final class ChatAPI {
    static let shared = ChatAPI()
    private init() {}

    private var baseURL: String { Config.apiBaseURL }

    struct ChatRequestBody: Codable {
        let message: String
    }

    struct ChatResponseBody: Codable {
        let response: String
        let places: [GooglePlaceResult]?
    }

    func send(message: String) async throws -> (String, [GooglePlaceResult]) {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw NSError(domain: "chat", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        guard let token = KeychainHelper.shared.readAccessToken() else {
            throw NSError(domain: "chat", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ChatRequestBody(message: message)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "chat",
                          code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode): \(text)"])
        }

        let decoded = try JSONDecoder().decode(ChatResponseBody.self, from: data)
        return (decoded.response, decoded.places ?? [])
    }
}
