import SwiftUI
import MapKit

struct MapViewNew: View {
    @State private var places: [Place] = []
    @State private var categories: [Category] = []
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPlace: Place? = nil
    @State private var showPlaceDetail = false
    @State private var showSearchResults = false
    @State private var searchResults: [GooglePlaceResult] = []
    @State private var isSearching = false
    @State private var selectedSearchResult: GooglePlaceResult? = nil
    @State private var showSearchResultDetail = false

    var filteredPlaces: [Place] {
        var filtered = places
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        return filtered
    }

    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: filteredPlaces) { place in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng)) {
                    VStack(spacing: 4) {
                        Text(place.category_emoji ?? "📍")
                            .font(.system(size: 32))
                            .onTapGesture {
                                selectedPlace = place
                                showPlaceDetail = true
                            }

                        // ✅ FIX: Added explicit black text color
                        Text(place.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.black)  // ✅ BLACK TEXT
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            )
                    }
                }
            }
            .ignoresSafeArea()

            // Top controls
            VStack {
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                            )
                    }
                }
                .padding()

                Spacer()
            }

            // Bottom UI
            VStack {
                Spacer()

                // Category chips
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryFilterChip(
                                emoji: "🗺️",
                                text: "all",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }

                            ForEach(categories) { category in
                                CategoryFilterChip(
                                    emoji: category.emoji,
                                    text: category.name.lowercased(),
                                    isSelected: selectedCategory == category.name
                                ) {
                                    selectedCategory = category.name
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }

                // Search bar
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search for places...", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(.black)  // ✅ BLACK TEXT
                            .onChange(of: searchText) { newValue in
                                if newValue.count > 2 {
                                    searchGooglePlaces(query: newValue)
                                } else {
                                    searchResults = []
                                    showSearchResults = false
                                }
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                showSearchResults = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: showSearchResults ? 15 : 25)
                            .fill(Color.white)
                    )

                    if showSearchResults && !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { result in
                                Button(action: {
                                    selectSearchResult(result)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(Color.orange)
                                            .font(.system(size: 20))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.black)  // ✅ BLACK TEXT

                                            Text(result.address)
                                                .font(.system(size: 13))
                                                .foregroundColor(.gray)  // ✅ GREY TEXT
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }

                                if result.id != searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(15, corners: [.bottomLeft, .bottomRight])
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }

            // Place detail
            if showPlaceDetail, let place = selectedPlace {
                PlaceDetailSheet(place: place, isPresented: $showPlaceDetail)
            }
            
            // Search result detail bottom sheet
            if showSearchResultDetail, let result = selectedSearchResult {
                SearchResultBottomSheet(
                    result: result,
                    isPresented: $showSearchResultDetail,
                    places: places
                )
            }
        }
        .onAppear {
            loadPlaces()
            loadCategories()
        }
    }

    // MARK: - Backend calls

    private func loadPlaces() {
        guard let url = URL(string: "\(Config.apiBaseURL)/places") else { return }
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token; user not logged in")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }

            if let decoded = try? JSONDecoder().decode([Place].self, from: data) {
                DispatchQueue.main.async {
                    self.places = decoded
                    if let first = decoded.first {
                        region.center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
                    }
                }
            } else {
                print("❌ Failed to decode /places")
            }
        }.resume()
    }

    private func loadCategories() {
        let catDict = Dictionary(uniqueKeysWithValues:
            places.compactMap { place -> (String, String)? in
                guard let name = place.category, let emoji = place.category_emoji else { return nil }
                return (name, emoji)
            }
        )
        categories = catDict.map { Category(name: $0.key, emoji: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private func searchGooglePlaces(query: String) {
        isSearching = true
        showSearchResults = false
        
        guard let url = URL(string: "\(Config.apiBaseURL)/search-places?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            isSearching = false
            return
        }
        
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("⚠️ No token for search")
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
            }
            
            if let error = error {
                print("❌ Search error:", error.localizedDescription)
                return
            }
            
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = decoded.results
                    self.showSearchResults = !decoded.results.isEmpty
                }
            } catch {
                print("❌ Failed to decode search results:", error)
            }
        }.resume()
    }

    private func selectSearchResult(_ result: GooglePlaceResult) {
        searchText = ""
        showSearchResults = false
        searchResults = []
        
        // Zoom to location
        region.center = CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng)
        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        // Show bottom sheet
        selectedSearchResult = result
        showSearchResultDetail = true
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let emoji: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .black)  // ✅ BLACK TEXT when not selected
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.black : Color.white)
            )
        }
    }
}

// MARK: - Google Search Models
struct GoogleSearchResponse: Codable {
    let results: [GooglePlaceResult]
}

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
        case photoUrl = "photo_url"
    }
}

// MARK: - Place Detail Sheet
struct PlaceDetailSheet: View {
    let place: Place
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(place.displayEmoji)
                        .font(.system(size: 48))
                    
                    VStack(alignment: .leading) {
                        Text(place.name)
                            .font(.title2.bold())
                            .foregroundColor(.black)  // ✅ BLACK TEXT
                        
                        if let district = place.district {
                            Text(district)
                                .font(.subheadline)
                                .foregroundColor(.gray)  // ✅ GREY TEXT
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                
                if let address = place.address {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.orange)
                        Text(address)
                            .font(.body)
                            .foregroundColor(.black)  // ✅ BLACK TEXT
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .onTapGesture {
            isPresented = false
        }
    }
}

// MARK: - Search Result Bottom Sheet
struct SearchResultBottomSheet: View {
    let result: GooglePlaceResult
    @Binding var isPresented: Bool
    let places: [Place]
    
    // Check if this place is already pinned
    private var isPinned: Bool {
        places.contains { $0.place_id == result.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                // Header with close button
                HStack {
                    Text(result.name)
                        .font(.title2.bold())
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                
                // Photo (if available)
                if let photoUrl = result.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure(_):
                            placeholderImage
                        case .empty:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                }
                
                // Rating
                if let rating = result.rating {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                
                // Address
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                    Text(result.address)
                        .font(.body)
                        .foregroundColor(.gray)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    // Directions button
                    Button(action: {
                        openDirections()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.system(size: 20))
                            Text("Directions")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Pin status button
                    Button(action: {
                        // TODO: Add pin/unpin functionality
                    }) {
                        HStack {
                            Image(systemName: isPinned ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 20))
                            Text(isPinned ? "Pinned" : "Pin")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(isPinned ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isPinned ? Color.green : Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
        )
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }
    
    private func openDirections() {
        let coordinate = "\(result.lat),\(result.lng)"
        let placeName = result.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Open Apple Maps with directions
        if let url = URL(string: "http://maps.apple.com/?daddr=\(coordinate)&q=\(placeName)") {
            UIApplication.shared.open(url)
        }
    }
}
