import SwiftUI

struct HomeDiscoveryView: View {
    @State private var allPlaces: [Place] = []
    @State private var events: [Event] = []
    @State private var trendingPlaces: [TrendingPlace] = []
    @State private var supportLocalPlaces: [Place] = []
    @State private var friendMatches: [FriendMatch] = []
    @State private var isLoading = true
    @State private var showImportSheet = false
    @State private var userLocation: (lat: Double, lng: Double)? = nil
    @State private var loadError: String? = nil
    @State private var selectedCategory: String? = nil
    
    // Filtered places based on selected category
    var filteredPlaces: [Place] {
        if let category = selectedCategory {
            if category == "trending" {
                // Show all places sorted by created_at (most recent first)
                return allPlaces.sorted { $0.id > $1.id }
            } else {
                // Map category names to database values
                let categoryMap: [String: String] = [
                    "coffee": "cafe",
                    "bars": "bar",
                    "restaurants": "restaurant",
                    "activities": "activity"
                ]
                let dbCategory = categoryMap[category] ?? category
                return allPlaces.filter { $0.category?.lowercased() == dbCategory }
            }
        }
        return allPlaces
    }

    // Top trending places (first 3)
    var pickedForYou: [Place] {
        Array(filteredPlaces.prefix(3))
    }

    // Places imported from Instagram/RED (filter by source)
    var fromYourSaves: [Place] {
        filteredPlaces.filter { place in
            (place.source_type?.contains("instagram") == true) ||
            (place.source_type?.contains("red") == true) ||
            (place.source_url?.hasPrefix("http") == true)
        }
    }

    // Nearby (within 2km)
    var nearbyFavorites: [Place] {
        guard let userLoc = userLocation else { return [] }

        return filteredPlaces.compactMap { place in
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

                            // Trending categories
                            Spacer().frame(height: 8)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    CategoryChip(
                                        emoji: "🔥",
                                        text: "trending",
                                        isSelected: selectedCategory == "trending"
                                    ) {
                                        selectedCategory = selectedCategory == "trending" ? nil : "trending"
                                    }
                                    CategoryChip(
                                        emoji: "☕️",
                                        text: "coffee",
                                        isSelected: selectedCategory == "coffee"
                                    ) {
                                        selectedCategory = selectedCategory == "coffee" ? nil : "coffee"
                                    }
                                    CategoryChip(
                                        emoji: "🍸",
                                        text: "bars",
                                        isSelected: selectedCategory == "bars"
                                    ) {
                                        selectedCategory = selectedCategory == "bars" ? nil : "bars"
                                    }
                                    CategoryChip(
                                        emoji: "🍽️",
                                        text: "restaurants",
                                        isSelected: selectedCategory == "restaurants"
                                    ) {
                                        selectedCategory = selectedCategory == "restaurants" ? nil : "restaurants"
                                    }
                                    CategoryChip(
                                        emoji: "🎯",
                                        text: "activities",
                                        isSelected: selectedCategory == "activities"
                                    ) {
                                        selectedCategory = selectedCategory == "activities" ? nil : "activities"
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // SECTION 1: Happening Now in HK
                            if !events.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Happening Now in HK 🎪")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(events) { event in
                                                EventCard(event: event)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // SECTION 2: Trending This Week
                            if !trendingPlaces.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Trending This Week 🔥")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(trendingPlaces) { place in
                                                TrendingPlaceCard(place: place)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // SECTION 3: Nearby Favourites
                            if !nearbyFavorites.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Nearby Favourites 📍")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(nearbyFavorites) { place in
                                                NearbyPlaceCard(place: place, userLocation: userLocation)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // SECTION 4: Support Local
                            if !supportLocalPlaces.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Support Local 💛")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(supportLocalPlaces) { place in
                                                SupportLocalCard(place: place)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // SECTION 5: Friend Taste Match
                            if !friendMatches.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Friend Taste Match 🤝")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(friendMatches) { friend in
                                                FriendMatchCard(friend: friend)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // SECTION 6: Picked for You
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
                loadEvents()
                loadTrending()
                loadSupportLocal()
                loadFriendTasteMatch()
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
    
    func loadEvents() {
        guard let url = URL(string: "\(Config.apiBaseURL)/events") else {
            print("⚠️ Invalid events URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ /events error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("⚠️ No events data")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([Event].self, from: data)
                DispatchQueue.main.async {
                    self.events = decoded
                    print("✅ Loaded \(decoded.count) events")
                }
            } catch {
                print("❌ Decode /events error:", error.localizedDescription)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Events Response:", jsonString)
                }
            }
        }.resume()
    }
    
    func loadTrending() {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token for trending")
            return
        }
        
        guard let url = URL(string: "\(Config.apiBaseURL)/trending") else {
            print("⚠️ Invalid trending URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ /trending error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("⚠️ No trending data")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([TrendingPlace].self, from: data)
                DispatchQueue.main.async {
                    self.trendingPlaces = decoded
                    print("✅ Loaded \(decoded.count) trending places")
                }
            } catch {
                print("❌ Decode /trending error:", error.localizedDescription)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Trending Response:", jsonString)
                }
            }
        }.resume()
    }
    
    func loadSupportLocal() {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token for support-local")
            return
        }
        
        guard let url = URL(string: "\(Config.apiBaseURL)/support-local") else {
            print("⚠️ Invalid support-local URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ /support-local error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("⚠️ No support-local data")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([Place].self, from: data)
                DispatchQueue.main.async {
                    self.supportLocalPlaces = decoded
                    print("✅ Loaded \(decoded.count) support local places")
                }
            } catch {
                print("❌ Decode /support-local error:", error.localizedDescription)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Support Local Response:", jsonString)
                }
            }
        }.resume()
    }
    
    func loadFriendTasteMatch() {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token for friend-taste-match")
            return
        }
        
        guard let url = URL(string: "\(Config.apiBaseURL)/friend-taste-match") else {
            print("⚠️ Invalid friend-taste-match URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ /friend-taste-match error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("⚠️ No friend-taste-match data")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([FriendMatch].self, from: data)
                DispatchQueue.main.async {
                    self.friendMatches = decoded
                    print("✅ Loaded \(decoded.count) friend matches")
                }
            } catch {
                print("❌ Decode /friend-taste-match error:", error.localizedDescription)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Friend Match Response:", jsonString)
                }
            }
        }.resume()
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
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.orange : Color(white: 0.95))
            )
        }
    }
}

// MARK: - Corner-Style Place Card
struct CornerStylePlaceCard: View {
    let place: Place
    @State private var showPlaceDetail = false
    
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
        }
        .padding(16)
        .background(Color(white: 0.98))  // Very light grey background
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onTapGesture {
            showPlaceDetail = true
        }
        .sheet(isPresented: $showPlaceDetail) {
            PlaceDetailSheet(place: place, isPresented: $showPlaceDetail)
        }
    }
}

// MARK: - Compact Square Card
struct CompactSquareCard: View {
    let place: Place
    let userLocation: (lat: Double, lng: Double)?
    @State private var showPlaceDetail = false
    
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
        .onTapGesture {
            showPlaceDetail = true
        }
        .sheet(isPresented: $showPlaceDetail) {
            PlaceDetailSheet(place: place, isPresented: $showPlaceDetail)
        }
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
    @State private var linkText = ""
    @State private var isLoading = false
    @State private var extractedPlace: Place?
    @State private var showPlaceDetail = false
    @State private var showErrorScreen = false
    @State private var errorMessage: String?
    var onPlaceSaved: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Title
            Text("import link")
                .font(.title2.bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Text input + Paste button
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if linkText.isEmpty {
                        Text("paste your link here")
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.leading, 16)
                    }
                    TextField("", text: $linkText)
                        .textFieldStyle(.plain)
                        .padding()
                        .foregroundColor(.black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(Color.white)
                )
                
                Button(action: {
                    if let clipboardString = UIPasteboard.general.string {
                        linkText = clipboardString
                    }
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .background(Color.white)
                        )
                }
            }
            .padding(.horizontal)
            
            // Upload button
            Button(action: {
                extractPlaces()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("upload")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1)
                    .background(Color.white)
            )
            .padding(.horizontal)
            .disabled(linkText.isEmpty || isLoading)
            .opacity(linkText.isEmpty || isLoading ? 0.5 : 1.0)
            

            
            Spacer()
        }
        .background(Color.white)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .overlay {
            // Success: Show place detail sheet
            if showPlaceDetail, let place = extractedPlace {
                PlaceDetailSheet(
                    place: place,
                    isPresented: $showPlaceDetail,
                    onDelete: {
                        onPlaceSaved?()
                        dismiss()
                    }
                )
            }
            
            // Error: Show error screen with manual search
            if showErrorScreen {
                ErrorScreenWithSearch(
                    isPresented: $showErrorScreen,
                    onPlaceSaved: {
                        onPlaceSaved?()
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - API Functions
    func extractPlaces() {
        isLoading = true
        
        guard let url = URL(string: "\(Config.apiBaseURL)/import") else {
            isLoading = false
            return
        }
        
        guard let token = KeychainHelper.shared.readAccessToken() else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = ["url": linkText]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let data = data else { return }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Success: Parse place and show detail sheet
                        if let place = try? JSONDecoder().decode(Place.self, from: data) {
                            extractedPlace = place
                            showPlaceDetail = true
                        }
                    } else {
                        // Error: Show error screen with manual search
                        showErrorScreen = true
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Error Screen With Search
struct ErrorScreenWithSearch: View {
    @Binding var isPresented: Bool
    var onPlaceSaved: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var searchResults: [GooglePlaceResult] = []
    @State private var isSearching = false
    @State private var selectedPlace: Place?
    @State private var showPlaceDetail = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Error icon and message
                    Text("👀")
                        .font(.system(size: 60))
                    
                    Text("we couldn't find the place")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Search field
                    TextField("search for it yourself", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(24)
                        .padding(.horizontal, 20)
                        .onChange(of: searchText) { newValue in
                            if newValue.count > 2 {
                                searchPlaces(query: newValue)
                            }
                        }
                    
                    // Search results
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(searchResults) { result in
                                    Button(action: {
                                        selectedPlace = convertToPlace(result)
                                        showPlaceDetail = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(result.name)
                                                    .font(.headline)
                                                    .foregroundColor(.black)
                                                Text(result.address)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(maxHeight: 300)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
            }
        }
        .overlay {
            if showPlaceDetail, let place = selectedPlace {
                PlaceDetailSheet(
                    place: place,
                    isPresented: $showPlaceDetail,
                    onDelete: {
                        onPlaceSaved?()
                        isPresented = false
                    }
                )
            }
        }
    }
    
    func searchPlaces(query: String) {
        isSearching = true
        
        guard let url = URL(string: "\(Config.apiBaseURL)/search-places?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            isSearching = false
            return
        }
        
        guard let token = KeychainHelper.shared.readAccessToken() else {
            isSearching = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                guard let data = data else { return }
                
                if let searchResponse = try? JSONDecoder().decode(GoogleSearchResponse.self, from: data) {
                    searchResults = searchResponse.results
                }
            }
        }.resume()
    }
    
    func convertToPlace(_ result: GooglePlaceResult) -> Place {
        return Place(
            id: 0,
            name: result.name,
            lat: result.lat,
            lng: result.lng,
            district: nil,
            category: nil,
            category_emoji: "📍",
            address: result.address,
            photo_url: result.photoUrl,
            place_id: result.id,
            opening_hours: nil,
            is_open_now: nil,
            rating: result.rating,
            user_ratings_total: nil,
            price_level: nil,
            source_url: nil,
            source_type: nil,
            caption: nil,
            author: nil,
            post_image_url: nil,
            post_video_url: nil,
            is_pinned: false,
            is_visited: false,
            notes: nil,
            confidence: nil,
            extraction_method: "search",
            tags: nil,
            source: nil
        )
    }
}


// MARK: - Event Card
struct EventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event Photo
            if let photoUrl = event.photo_url, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 180)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 180)
                    .overlay(
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                    )
            }
            
            // Event Info
            VStack(alignment: .leading, spacing: 8) {
                Text(event.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                Text(event.time_description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                if let location = event.location {
                    Text(location)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Trending Place Card
struct TrendingPlaceCard: View {
    let place: TrendingPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Place Photo
            if let photoUrl = place.photo_url, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 180)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 180)
                    .overlay(
                        Text(place.displayEmoji)
                            .font(.system(size: 48))
                    )
            }
            
            // Place Info
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                if let district = place.district {
                    Text(district)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Trending stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("👥")
                            .font(.system(size: 14))
                        Text("\(place.total_saves) saves")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("+\(place.recent_saves) this week")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


// MARK: - Nearby Place Card
struct NearbyPlaceCard: View {
    let place: Place
    let userLocation: (lat: Double, lng: Double)?
    
    var distance: Double {
        guard let userLoc = userLocation else { return 0 }
        let R = 6371.0
        let dLat = (place.lat - userLoc.lat) * .pi / 180
        let dLng = (place.lng - userLoc.lng) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(userLoc.lat * .pi / 180) * cos(place.lat * .pi / 180) *
                sin(dLng/2) * sin(dLng/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Place Photo
            if let photoUrl = place.photo_url, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 180)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 280, height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 180)
                    .overlay(
                        Text(place.displayEmoji)
                            .font(.system(size: 48))
                    )
            }
            
            // Place Info
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                if let district = place.district {
                    Text(district)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Distance
                HStack(spacing: 4) {
                    Text("📍")
                        .font(.system(size: 14))
                    Text(String(format: "%.1f km away", distance))
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


// MARK: - Support Local Card
struct SupportLocalCard: View {
    let place: Place
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Place Photo with yellow heart badge
            ZStack(alignment: .topTrailing) {
                if let photoUrl = place.photo_url, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 280, height: 180)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 180)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 280, height: 180)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 280, height: 180)
                        .overlay(
                            Text(place.displayEmoji)
                                .font(.system(size: 48))
                        )
                }
                
                // Yellow heart badge
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .padding(8)
            }
            
            // Place Info
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                if let district = place.district {
                    Text(district)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Local badge
                Text("🏠 Independent Business")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


// MARK: - Friend Match Card (Simplified)
struct FriendMatchCard: View {
    let friend: FriendMatch
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text(String(friend.friend_name.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            // Friend name
            Text(friend.friend_name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
            
            // Big percentage
            Text("\(friend.match_percentage)%")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.orange)
        }
        .frame(width: 140)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

