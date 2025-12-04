import SwiftUI

struct HomeDiscoveryView: View {
    @State private var allPlaces: [Place] = []
    @State private var isLoading = true
    @State private var showImportSheet = false
    @State private var userLocation: (lat: Double, lng: Double)? = nil
    @State private var loadError: String? = nil

    // Top trending places (first 3)
    var pickedForYou: [Place] {
        Array(allPlaces.prefix(3))
    }

    // Places imported from Instagram/RED (filter by source)
    var fromYourSaves: [Place] {
        allPlaces.filter { place in
            (place.source_type?.contains("instagram") == true) ||
            (place.source_type?.contains("red") == true) ||
            (place.source_url?.hasPrefix("http") == true)
        }
    }

    // Nearby (within 2km)
    var nearbyFavorites: [Place] {
        guard let userLoc = userLocation else { return [] }

        return allPlaces.compactMap { place in
            let distance = calculateDistance(
                lat1: userLoc.lat, lng1: userLoc.lng,
                lat2: place.lat, lng2: place.lng
            )
            return distance < 2.0 ? place : nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ WHITE BACKGROUND
                Color.white
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Text("Unable to load places")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Try Again") {
                            loadPlaces()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 32) {

                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("discover")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)  // ✅ BLACK TEXT

                                Text("places your friends love")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)  // ✅ GREY TEXT
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 20)

                            // Trending categories
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    CategoryChip(emoji: "🔥", text: "trending")
                                    CategoryChip(emoji: "☕️", text: "coffee")
                                    CategoryChip(emoji: "🍸", text: "bars")
                                    CategoryChip(emoji: "🍽️", text: "restaurants")
                                    CategoryChip(emoji: "🎯", text: "activities")
                                }
                                .padding(.horizontal)
                            }

                            // SECTION 1: Picked for You
                            if !pickedForYou.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Picked for you 👈")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.black)  // ✅ BLACK TEXT
                                        Text("You might like these...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)  // ✅ GREY TEXT
                                    }
                                    .padding(.horizontal)

                                    ForEach(pickedForYou) { place in
                                        CornerStylePlaceCard(place: place)
                                            .padding(.horizontal)
                                    }
                                }
                            }

                            // SECTION 2: From Your Saves
                            if !fromYourSaves.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("From Your Saves 📸")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.black)  // ✅ BLACK TEXT
                                        Text("Imported from Instagram or RED — now mapped by Radar")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)  // ✅ GREY TEXT
                                    }
                                    .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(fromYourSaves.prefix(10)) { place in
                                                CompactSquareCard(place: place, userLocation: userLocation)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // SECTION 3: Nearby Favourites
                            if !nearbyFavorites.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Nearby Favourites 📍")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.black)  // ✅ BLACK TEXT
                                        Text("Your saved spots nearby — ready to check out IRL")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)  // ✅ GREY TEXT
                                    }
                                    .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(nearbyFavorites.prefix(10)) { place in
                                                CompactSquareCard(place: place, userLocation: userLocation)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showImportSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.orange)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportOptionsSheet()
            }
        }
        .onAppear {
            if allPlaces.isEmpty {
                loadPlaces()
                loadUserLocation()
            }
        }
    }

    func loadPlaces() {
        isLoading = true
        loadError = nil
        
        guard let url = URL(string: "\(Config.apiBaseURL)/places") else {
            DispatchQueue.main.async {
                self.loadError = "Invalid API URL"
                self.isLoading = false
            }
            return
        }
        
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token; user not logged in")
            DispatchQueue.main.async {
                self.loadError = "Not logged in"
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ /places error:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.loadError = "Network error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.loadError = "No data received"
                    self.isLoading = false
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([Place].self, from: data)
                DispatchQueue.main.async {
                    self.allPlaces = decoded
                    self.isLoading = false
                }
            } catch {
                print("❌ Decode /places error:", error.localizedDescription)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Backend Response:")
                    print(jsonString)
                }
                print("🔍 Decode Error Details:", error)
                DispatchQueue.main.async {
                    self.loadError = "Failed to parse places data"
                    self.isLoading = false
                }
            }
        }.resume()
    }

    func loadUserLocation() {
        userLocation = (lat: 22.2819, lng: 114.1579)
    }

    func calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng/2) * sin(dLng/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let emoji: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)  // ✅ BLACK TEXT
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.95))  // Light grey background
        )
    }
}

// MARK: - Corner-Style Place Card
struct CornerStylePlaceCard: View {
    let place: Place
    
    var categoryTags: [String] {
        if let tags = place.tags, !tags.isEmpty {
            return Array(tags.prefix(3))
        }
        switch place.category?.lowercased() {
        case "restaurant": return ["Pasta", "Wine", "Girl Dinner"]
        case "bar": return ["Cocktails", "Vibes", "Late Night"]
        case "cafe": return ["Coffee", "Brunch", "Cozy"]
        default: return []
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Photo
            if let photoURL = place.photo_url, !photoURL.isEmpty, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .cornerRadius(12)
                    default:
                        PlaceholderSquare(emoji: place.displayEmoji)
                    }
                }
            } else {
                PlaceholderSquare(emoji: place.displayEmoji)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)  // ✅ BLACK TEXT
                    .lineLimit(1)

                if let district = place.district, !district.isEmpty {
                    HStack(spacing: 4) {
                        Text(district)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)  // ✅ GREY TEXT
                        if let priceLevel = place.price_level, priceLevel > 0, priceLevel <= 4 {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(String(repeating: "$", count: priceLevel))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }

                // ✅ YELLOW TAGS
                if !categoryTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categoryTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)  // ✅ BLACK TEXT ON YELLOW
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow)  // ✅ YELLOW BACKGROUND
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                // Friend count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("12 friends saved this")
                        .font(.system(size: 13))
                }
                .foregroundColor(.orange)
            }

            Spacer()
            
            Image(systemName: "bookmark")
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(white: 0.98))  // Very light grey background
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Compact Square Card
struct CompactSquareCard: View {
    let place: Place
    let userLocation: (lat: Double, lng: Double)?
    
    var distance: String? {
        guard let userLoc = userLocation else { return nil }
        let dist = calculateDistance(
            lat1: userLoc.lat, lng1: userLoc.lng,
            lat2: place.lat, lng2: place.lng
        )
        if dist < 1.0 {
            return "\(Int(dist * 1000))m away"
        } else {
            return String(format: "%.1fkm away", dist)
        }
    }
    
    var categoryLabel: String {
        switch place.category?.lowercased() {
        case "bar": return "Bar"
        case "cafe": return "Cafe"
        case "restaurant": return "Restaurant"
        case "activity": return "Activity"
        case "culture": return "Culture"
        default: return "Place"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let photoURL = place.photo_url, !photoURL.isEmpty, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 200)
                                .clipped()
                        default:
                            PlaceholderSquareLarge(emoji: place.displayEmoji)
                        }
                    }
                } else {
                    PlaceholderSquareLarge(emoji: place.displayEmoji)
                }
                
                // ✅ YELLOW CATEGORY BADGE
                Text(categoryLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)  // ✅ BLACK TEXT ON YELLOW
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow)  // ✅ YELLOW BACKGROUND
                    .cornerRadius(12)
                    .padding(12)
            }
            .frame(width: 200, height: 200)
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)  // ✅ BLACK TEXT
                    .lineLimit(1)

                Text(place.district ?? "Hong Kong")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)  // ✅ GREY TEXT
                
                if let dist = distance {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                        Text(dist)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding(12)
        }
        .frame(width: 200)
        .background(Color(white: 0.98))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    func calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng/2) * sin(dLng/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
}

// MARK: - Placeholders
struct PlaceholderSquare: View {
    let emoji: String
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(emoji).font(.system(size: 48))
        }
        .frame(width: 120, height: 120)
        .cornerRadius(12)
    }
}

struct PlaceholderSquareLarge: View {
    let emoji: String
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(emoji).font(.system(size: 64))
        }
        .frame(width: 200, height: 200)
    }
}

// MARK: - Import Sheet
struct ImportOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Import from")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                Button("Instagram") { dismiss() }.buttonStyle(.borderedProminent)
                Button("RED") { dismiss() }.buttonStyle(.borderedProminent)
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white)
        }
    }
}
