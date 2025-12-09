import Foundation

class ListsAPI {
    static let shared = ListsAPI()
    private let baseURL = "https://radar-production-0277.up.railway.app"
    
    private init() {}
    
    // MARK: - Get all lists
    func getLists() async throws -> [PlaceList] {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PlaceList].self, from: data)
    }
    
    // MARK: - Get list detail
    func getListDetail(listId: Int) async throws -> ListDetail {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists/\(listId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ListDetail.self, from: data)
    }
    
    // MARK: - Create list
    func createList(name: String, description: String?, emoji: String) async throws -> PlaceList {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateListRequest(
            name: name,
            description: description,
            emoji: emoji,
            cover_photo_url: nil
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PlaceList.self, from: data)
    }
    
    // MARK: - Add place to list
    func addPlaceToList(listId: Int, placeId: Int) async throws {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists/\(listId)/places") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AddPlaceToListRequest(place_id: placeId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Remove place from list
    func removePlaceFromList(listId: Int, placeId: Int) async throws {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists/\(listId)/places/\(placeId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Delete list
    func deleteList(listId: Int) async throws {
        guard let token = KeychainHelper.shared.getToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/lists/\(listId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}
