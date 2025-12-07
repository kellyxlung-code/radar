import SwiftUI
import CoreLocation

// MARK: - Models

struct Event: Codable, Identifiable {
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

struct TrendingPlace: Codable, Identifiable {
    let id: Int
    let name: String
    let district: String?
    let category: String?
    let emoji: String
    let photo_url: String?
    let lat: Double
    let lng: Double
    let rating: Double?
    let saves_this_week: Int
    let total_saves: Int
}

struct FriendMatch: Codable, Identifiable {
    let friend_id: Int
    let friend_name: String
    let friend_phone: String
    let match_percentage: Int
    let shared_places_count: Int
    
    var id: Int { friend_id }
}

// MARK: - Main View

struct HomeDiscoveryViewNew: View {
    @StateObject private var locationManager = LocationManager()
    @State private var allPlaces: [Place] = []
    @State private var events: [Event] = []
    @State private var trendingPlaces: [TrendingPlace] = []
    @State private var friendMatches: [FriendMatch] = []
    @State private var isLoading = true
    @State private var showImportSheet = false
    @State private var selectedCategory: String? = nil
    @State private var selectedPlace: Place? = nil
    @State private var showPlaceDetail = false
    
    // Filtered places based on selected category
    var filteredPlaces: [Place] {
        if let category = selectedCategory {
            if category == "trending" {
                return allPlaces.sorted { ($0.id ?? 0) > ($1.id ?? 0) }
            } else {
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
    
    // Nearby favorites (within 2km)
    var nearbyFavorites: [Place] {
        guard let userLoc = locationManager.location else { return [] }
        
        return filteredPlaces.compactMap { place in
            let distance = calculateDistance(
                lat1: userLoc.coordinate.latitude,
                lng1: userLoc.coordinate.longitude,
                lat2: place.lat,
                lng2: place.lng
            )
            return distance < 2.0 ? place : nil
        }.sorted { place1, place2 in
            let dist1 = calculateDistance(
                lat1: locationManager.location!.coordinate.latitude,
                lng1: locationManager.location!.coordinate.longitude,
                lat2: place1.lat,
                lng2: place1.lng
            )
            let dist2 = calculateDistance(
                lat1: locationManager.location!.coordinate.latitude,
                lng1: locationManager.location!.coordinate.longitude,
                lat2: place2.lat,
                lng2: place2.lng
            )
            return dist1 < dist2
        }
    }
    
    // Support local (places with local/independent tags)
    var supportLocal: [Place] {
        filteredPlaces.filter { place in
            guard let tags = place.tags else { return false }
            return tags.contains { tag in
                let lowercased = tag.lowercased()
                return lowercased.contains("local") ||
                       lowercased.contains("independent") ||
                       lowercased.contains("family") ||
                       lowercased.contains("heritage")
            }
        }
    }
    
    // From your saves (imported from Instagram/RED)
    var fromYourSaves: [Place] {
        filteredPlaces.filter { place in
            (place.source_type?.contains("instagram") == true) ||
            (place.source_type?.contains("red") == true) ||
            (place.source_url?.hasPrefix("http") == true)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            
                            // MARK: - Filter Chips
                            Spacer().frame(height: 8)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    CategoryChip(emoji: "🔥", text: "trending", isSelected: selectedCategory == "trending") {
                                        selectedCategory = selectedCategory == "trending" ? nil : "trending"
                                    }
                                    CategoryChip(emoji: "☕️", text: "coffee", isSelected: selectedCategory == "coffee") {
                                        selectedCategory = selectedCategory == "coffee" ? nil : "coffee"
                                    }
                                    CategoryChip(emoji: "🍸", text: "bars", isSelected: selectedCategory == "bars") {
                                        selectedCategory = selectedCategory == "bars" ? nil : "bars"
                                    }
                                    CategoryChip(emoji: "🍽️", text: "restaurants", isSelected: selectedCategory == "restaurants") {
                                        selectedCategory = selectedCategory == "restaurants" ? nil : "restaurants"
                                    }
                                    CategoryChip(emoji: "🎯", text: "activities", isSelected: selectedCategory == "activities") {
                                        selectedCategory = selectedCategory == "activities" ? nil : "activities"
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - Trending This Week
                            if !trendingPlaces.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Trending This Week 🔥")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(trendingPlaces) { place in
                                                TrendingCard(place: place)
                                                    .onTapGesture {
                                                        // Convert to Place and show detail
                                                        // TODO: Implement
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // MARK: - Happening Now in HK
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
                            
                            // MARK: - Nearby Favourites
                            if !nearbyFavorites.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Nearby Favourites 📍")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(nearbyFavorites) { place in
                                                PlaceCard(place: place, showDistance: true, userLocation: locationManager.location)
                                                    .onTapGesture {
                                                        selectedPlace = place
                                                        showPlaceDetail = true
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // MARK: - Support Local
                            if !supportLocal.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Support Local 💛")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(supportLocal) { place in
                                                PlaceCard(place: place, showDistance: false, userLocation: nil)
                                                    .onTapGesture {
                                                        selectedPlace = place
                                                        showPlaceDetail = true
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // MARK: - Friend's Taste Match
                            if !friendMatches.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Friend's Taste Match 🎯")
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
                            
                            // MARK: - From Your Saves
                            if !fromYourSaves.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("From Your Saves 📸")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(fromYourSaves) { place in
                                                PlaceCard(place: place, showDistance: true, userLocation: locationManager.location)
                                                    .onTapGesture {
                                                        selectedPlace = place
                                                        showPlaceDetail = true
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 32)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Profile action
                    }) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showImportSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportOptionsSheet(isPresented: $showImportSheet)
            }
            .sheet(isPresented: $showPlaceDetail) {
                if let place = selectedPlace {
                    PlaceDetailSheet(place: place, isPresented: $showPlaceDetail)
                }
            }
            .onAppear {
                locationManager.requestPermission()
                loadData()
            }
        }
    }
    
    func loadData() {
        Task {
            await loadPlaces()
            await loadEvents()
            await loadTrending()
            await loadFriendMatches()
            isLoading = false
        }
    }
    
    func loadPlaces() async {
        guard let token = KeychainHelper.shared.readAccessToken() else { return }
        
        guard let url = URL(string: "\(Config.apiBaseURL)/places") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            allPlaces = try JSONDecoder().decode([Place].self, from: data)
        } catch {
            print("Error loading places: \(error)")
        }
    }
    
    func loadEvents() async {
        guard let url = URL(string: "\(Config.apiBaseURL)/events") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            events = try JSONDecoder().decode([Event].self, from: data)
        } catch {
            print("Error loading events: \(error)")
        }
    }
    
    func loadTrending() async {
        guard let token = KeychainHelper.shared.readAccessToken() else { return }
        guard let url = URL(string: "\(Config.apiBaseURL)/trending") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            trendingPlaces = try JSONDecoder().decode([TrendingPlace].self, from: data)
        } catch {
            print("Error loading trending: \(error)")
        }
    }
    
    func loadFriendMatches() async {
        guard let token = KeychainHelper.shared.readAccessToken() else { return }
        guard let url = URL(string: "\(Config.apiBaseURL)/friend-taste-match") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            friendMatches = try JSONDecoder().decode([FriendMatch].self, from: data)
        } catch {
            print("Error loading friend matches: \(error)")
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

// MARK: - Card Views

struct TrendingCard: View {
    let place: TrendingPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: place.photo_url ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 200, height: 200)
            .clipped()
            .cornerRadius(12)
            
            Text(place.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
            
            Text(place.district ?? "")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                Text("\(place.total_saves) saves")
            }
            .font(.system(size: 13))
            .foregroundColor(.orange)
        }
        .frame(width: 200)
    }
}

struct EventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: event.photo_url ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 280, height: 140)
            .clipped()
            .cornerRadius(12)
            
            Text(event.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            
            Text("\(event.district ?? "") • \(event.time_description)")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(width: 280)
    }
}

struct PlaceCard: View {
    let place: Place
    let showDistance: Bool
    let userLocation: CLLocation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: place.photo_url ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 200, height: 200)
            .clipped()
            .cornerRadius(12)
            
            Text(place.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
            
            Text(place.district ?? "")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            if showDistance, let userLoc = userLocation {
                let distance = calculateDistance(
                    lat1: userLoc.coordinate.latitude,
                    lng1: userLoc.coordinate.longitude,
                    lat2: place.lat,
                    lng2: place.lng
                )
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                    Text(String(format: "%.1fkm away", distance))
                }
                .font(.system(size: 13))
                .foregroundColor(.orange)
            }
        }
        .frame(width: 200)
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

struct FriendMatchCard: View {
    let friend: FriendMatch
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            
            VStack(spacing: 12) {
                // Profile icon
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(friend.friend_name.prefix(1)))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // Friend name
                Text(friend.friend_name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Match percentage (BIG)
                Text("\(friend.match_percentage)%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding()
        }
        .frame(width: 160, height: 180)
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdating()
        }
    }
}
