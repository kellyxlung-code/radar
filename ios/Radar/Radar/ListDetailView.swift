import SwiftUI
import MapKit

struct ListDetailView: View {
    let list: PlaceList
    @State private var listDetail: ListDetail?
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let detail = listDetail {
                    if detail.places.isEmpty {
                        VStack(spacing: 20) {
                            Text(detail.emoji)
                                .font(.system(size: 64))
                            Text("No Places Yet")
                                .font(.title2.bold())
                            Text("Add places from your saved collection")
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Header
                                VStack(spacing: 8) {
                                    Text(detail.emoji)
                                        .font(.system(size: 48))
                                    Text(detail.name)
                                        .font(.title.bold())
                                    if let description = detail.description {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                    }
                                    Text("\(detail.places.count) places")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                
                                // Places
                                ForEach(detail.places) { place in
                                    ListPlaceCard(place: place, listId: detail.id, onRemove: {
                                        loadDetail()
                                    })
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadDetail()
            }
        }
    }
    
    func loadDetail() {
        isLoading = true
        Task {
            do {
                listDetail = try await ListsAPI.shared.getListDetail(listId: list.id)
                isLoading = false
            } catch {
                print("❌ Failed to load list detail: \(error)")
                isLoading = false
            }
        }
    }
}

struct ListPlaceCard: View {
    let place: ListPlace
    let listId: Int
    let onRemove: () -> Void
    
    @State private var showRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo or emoji
            if let photoUrl = place.photo_url, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Text(place.emoji ?? "📍")
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                
                if let category = place.category {
                    Text(category.capitalized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Remove button
            Button(action: { showRemoveAlert = true }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .alert("Remove from list?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                removePlace()
            }
        }
    }
    
    func removePlace() {
        Task {
            do {
                try await ListsAPI.shared.removePlaceFromList(listId: listId, placeId: place.id)
                await MainActor.run {
                    onRemove()
                }
            } catch {
                print("❌ Failed to remove place: \(error)")
            }
        }
    }
}
