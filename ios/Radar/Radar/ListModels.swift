import Foundation

// MARK: - List Models

struct PlaceList: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let emoji: String
    let cover_photo_url: String?
    let is_public: Bool
    let place_count: Int
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, emoji, is_public, place_count, created_at
        case cover_photo_url
    }
}

struct ListDetail: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let emoji: String
    let cover_photo_url: String?
    let is_public: Bool
    let places: [ListPlace]
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, emoji, is_public, places, created_at
        case cover_photo_url
    }
}

struct ListPlace: Identifiable, Codable {
    let id: Int
    let name: String
    let lat: Double
    let lng: Double
    let emoji: String?
    let category: String?
    let photo_url: String?
    let position: Int
    let added_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng, emoji, category, position, added_at
        case photo_url
    }
}

// MARK: - API Request/Response Models

struct CreateListRequest: Codable {
    let name: String
    let description: String?
    let emoji: String
    let cover_photo_url: String?
}

struct AddPlaceToListRequest: Codable {
    let place_id: Int
}
