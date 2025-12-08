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
            .onTapGesture {
                // Dismiss keyboard when tapping on map
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

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

                        ZStack(alignment: .leading) {
                            if searchText.isEmpty {
                                Text("what tempts you today?")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            TextField("", text: $searchText)
                                .font(.system(size: 16))
                                .foregroundColor(.black)  // ✅ BLACK TEXT
                                .accentColor(.black)  // Cursor color
                        }
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
                PlaceDetailSheet(place: place, isPresented: $showPlaceDetail, onDelete: loadPlaces)
            }
            
            // Search result detail bottom sheet
            if showSearchResultDetail, let result = selectedSearchResult {
                PlaceDetailSheet(
                    place: convertToPlace(result),
                    isPresented: $showSearchResultDetail,
                    onDelete: loadPlaces
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
    
    // Convert GooglePlaceResult to Place for consistent detail sheet
    private func convertToPlace(_ result: GooglePlaceResult) -> Place {
        // Check if this place is already pinned
        // Must check for non-nil place_id before comparing
        let isPinned = places.contains { place in
            guard let placeId = place.place_id else { return false }
            return placeId == result.id
        }
        
        print("🔍 Search result: \(result.name)")
        print("   Google Place ID: \(result.id)")
        print("   Is already pinned: \(isPinned)")
        
        return Place(
            id: 0, // Temporary ID for unsaved places
            name: result.name,
            lat: result.lat,
            lng: result.lng,
            district: nil,
            category: nil,
            category_emoji: "📍",
            address: result.address,
            photo_url: result.photoUrl,
            place_id: result.id,
            opening_hours: nil, // Will be fetched when saving
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
            is_pinned: isPinned,
            is_visited: false,
            notes: nil,
            confidence: nil,
            extraction_method: "search",
            tags: nil,
            source: nil
        )
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
        // Dismiss keyboard first
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
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

// MARK: - Place Detail Sheet
struct PlaceDetailSheet: View {
    let place: Place
    @Binding var isPresented: Bool
    var onDelete: (() -> Void)? = nil
    @State private var isUpdating = false
    
    var body: some View {
        VStack {
            Spacer()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Close button (top-right)
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
                    
                    // Name
                    Text(place.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                    
                    // Address
                    if let address = place.address {
                        Text(address)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    }
                    
                    // Open status + hours
                    HStack(spacing: 8) {
                        if let isOpen = place.is_open_now {
                            Text(isOpen ? "open" : "closed")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isOpen ? .green : .red)
                        }
                        
                        if let hours = place.opening_hours?.todayHours {
                            Text(hours)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Photos (horizontal scroll)
                    if let photoUrl = place.photo_url, let url = URL(string: photoUrl) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 280, height: 200)
                                            .clipped()
                                            .cornerRadius(12)
                                    case .failure(_):
                                        placeholderPhoto
                                    case .empty:
                                        placeholderPhoto
                                    @unknown default:
                                        placeholderPhoto
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Saved by (mock for now)
                    HStack(spacing: 8) {
                        // Profile icons
                        HStack(spacing: -8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.orange)
                                    )
                            }
                        }
                        
                        Text("saved by liese, clairiedance and 7 other people")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    
                    // All action buttons in one row
                    HStack(spacing: 8) {
                        // Share button
                        Button(action: {
                            sharePlace()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(22)
                        }
                        
                        // Directions button
                        Button(action: {
                            openDirections()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                Text("directions")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(22)
                        }
                        
                        // Want to try button (bookmark - orange if saved, gray if not)
                        Button(action: {
                            toggleWantToTry()
                        }) {
                            let isSaved = place.id > 0
                            HStack(spacing: 4) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14))
                                Text("want to try")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(isSaved ? .white : .black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(isSaved ? Color.orange : Color.gray.opacity(0.1))
                            .cornerRadius(22)
                        }
                        .disabled(isUpdating)
                        
                        // Visited button (toggle)
                        Button(action: {
                            toggleVisited()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: place.is_visited == true ? "checkmark.circle.fill" : "checkmark.circle")
                                    .font(.system(size: 14))
                                Text("visited")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(place.is_visited == true ? .white : .black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(place.is_visited == true ? Color.green : Color.gray.opacity(0.1))
                            .cornerRadius(22)
                        }
                        .disabled(isUpdating)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
            .padding(.bottom, 80)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
        )
    }
    
    var placeholderPhoto: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 280, height: 200)
            .cornerRadius(12)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }
    
    func sharePlace() {
        let text = "\(place.name)\n\(place.address ?? "")"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func openDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func toggleWantToTry() {
        // "want to try" = saved to backend
        // If place is not saved yet (id == 0) → save it
        // If place is already saved (id > 0) → delete it
        
        print("🔘 toggleWantToTry called")
        print("   place.id: \(place.id)")
        print("   place.name: \(place.name)")
        
        if place.id == 0 {
            print("   → Saving place (pinning to map)")
            savePlace()
        } else {
            print("   → Deleting place (unpinning from map)")
            deletePlace()
        }
    }
    
    func savePlace() {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("❌ No auth token")
            return
        }
        
        isUpdating = true
        
        guard let url = URL(string: "\(Config.apiBaseURL)/places") else {
            isUpdating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any?] = [
            "name": place.name,
            "lat": place.lat,
            "lng": place.lng,
            "address": place.address,
            "place_id": place.place_id,
            "photo_url": place.photo_url,
            "rating": place.rating,
            "extraction_method": "search"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isUpdating = false
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    print("✅ Place saved (pinned)")
                    // Close the sheet and refresh map
                    isPresented = false
                    onDelete?() // Reuse onDelete callback to refresh map
                } else {
                    print("❌ Failed to save place")
                }
            }
        }.resume()
    }
    
    func toggleVisited() {
        // Toggle: if currently nil or want to try (false), set to true (visited)
        // If already visited (true), unmark it (nil)
        let newValue: Bool? = (place.is_visited == true) ? nil : true
        updateVisitStatus(visited: newValue)
    }
    
    func updateVisitStatus(visited: Bool?) {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("❌ No auth token")
            return
        }
        
        isUpdating = true
        
        guard let url = URL(string: "\(Config.apiBaseURL)/places/\(place.id)") else {
            isUpdating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any?] = ["is_visited": visited]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isUpdating = false
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ Updated visit status: \(visited)")
                    // Close sheet after update
                    isPresented = false
                } else {
                    print("❌ Failed to update visit status")
                }
            }
        }.resume()
    }
    
    func deletePlace() {
        guard let token = KeychainHelper.shared.readAccessToken() else {
            print("❌ No auth token")
            return
        }
        
        isUpdating = true
        
        guard let url = URL(string: "\(Config.apiBaseURL)/places/\(place.id)") else {
            isUpdating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isUpdating = false
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ Place deleted (unpinned)")
                    // Close the sheet and refresh map
                    isPresented = false
                    onDelete?()
                } else {
                    print("❌ Failed to delete place")
                }
            }
        }.resume()
    }
}


