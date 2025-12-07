import Foundation

// MARK: - Place Model
struct Place: Identifiable, Codable {
    let id: Int
    let name: String
    let lat: Double
    let lng: Double

    // Location / venue
    let district: String?
    let category: String?
    let category_emoji: String?
    let address: String?
    let photo_url: String?
    let place_id: String?
    let opening_hours: OpeningHours?
    let is_open_now: Bool?
    let rating: Double?
    let user_ratings_total: Int?
    let price_level: Int?  // ✅ ADDED: 1-4 ($, $$, $$$, $$$$)

    // Social source (unified with backend)
    let source_url: String?
    let source_type: String?
    let caption: String?
    let author: String?
    let post_image_url: String?
    let post_video_url: String?

    // User / AI state
    let is_pinned: Bool?
    let is_visited: Bool?  // ✅ ADDED: User has visited this place
    let notes: String?
    let confidence: Double?
    let extraction_method: String?
    let tags: [String]?  // ✅ ADDED: Category tags like ["Pasta", "Wine", "Girl Dinner"]

    // Backwards-compat: old 'source' field if backend still sends it
    let source: String?

    // Computed properties for display
    var displayCategory: String {
        category ?? "Other"
    }

    var displayEmoji: String {
        category_emoji ?? "📍"
    }
    
    // Map backend "emoji" field to "category_emoji" in Swift
    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng, district, category, address, photo_url, place_id
        case opening_hours, is_open_now, rating, user_ratings_total, price_level
        case source_url, source_type, caption, author, post_image_url, post_video_url
        case is_pinned, is_visited, notes, confidence, extraction_method, source, tags
        case category_emoji = "emoji"  // Backend sends "emoji", we use "category_emoji"
    }
}

// MARK: - Opening Hours Model
struct OpeningHours: Codable {
    let open_now: Bool?
    let weekday_text: [String]?

    // Raw string for today, e.g. "Monday: 5:00 PM – 12:00 AM"
    var todayHours: String? {
        guard let weekday_text = weekday_text else { return nil }
        let today = Calendar.current.component(.weekday, from: Date())
        // weekday: 1 = Sunday, 2 = Monday, etc.
        // weekday_text: 0 = Monday, 1 = Tuesday, etc.
        let index = (today + 5) % 7
        guard index < weekday_text.count else { return nil }
        return weekday_text[index]
    }

    // "5:00 PM – 12:00 AM"
    var displayHours: String? {
        guard let today = todayHours else { return nil }
        let components = today.components(separatedBy: ": ")
        return components.count > 1 ? components[1] : today
    }
}

// MARK: - Category Model
struct Category: Identifiable, Codable {
    var id: String { name }
    let name: String
    let emoji: String
}

// MARK: - Place Response (optional wrappers if needed)
struct PlaceResponse: Codable {
    let ok: Bool
    let place: Place?
}

struct PlacesResponse: Codable {
    let places: [Place]?
}

struct ImportCandidateResponse: Codable {
    let ok: Bool
    let candidate: Place?
}


// MARK: - Event Model
struct Event: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let photo_url: String?
    let location: String?
    let district: String?
    let start_date: String
    let end_date: String
    let category: String?
    let url: String?
    let time_description: String
}

// MARK: - Trending Place Model
struct TrendingPlace: Identifiable, Codable {
    let id: Int
    let name: String
    let address: String?
    let district: String?
    let lat: Double
    let lng: Double
    let category: String?
    let emoji: String?
    let photo_url: String?
    let rating: Double?
    let total_saves: Int
    let recent_saves: Int
    let trending_score: Double
    
    var displayEmoji: String {
        emoji ?? "📍"
    }
}


// MARK: - Google Place Result Model (for search/chat)
struct GooglePlaceResult: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let rating: Double?
    let photoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "place_id"
        case name
        case address
        case lat
        case lng
        case rating
        case photoUrl
    }
}

struct GoogleSearchResponse: Codable {
    let results: [GooglePlaceResult]
}


// MARK: - Friend Match Model
struct FriendMatch: Identifiable, Codable {
    let friend_id: Int
    let friend_name: String
    let match_percentage: Int
    let mutual_places: Int
    
    var id: Int { friend_id }
}
