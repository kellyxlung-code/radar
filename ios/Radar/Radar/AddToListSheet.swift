import SwiftUI

struct AddToListSheet: View {
    let place: Place
    @Environment(\.dismiss) var dismiss
    @State private var lists: [PlaceList] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if lists.isEmpty {
                    VStack(spacing: 20) {
                        Text("📌")
                            .font(.system(size: 64))
                        Text("No Lists Yet")
                            .font(.title2.bold())
                        Text("Create a list to add this place")
                            .foregroundColor(.gray)
                        
                        Button(action: { showCreateSheet = true }) {
                            Text("Create List")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(lists) { list in
                            Button(action: {
                                addToList(list)
                            }) {
                                HStack {
                                    Text(list.emoji)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text(list.name)
                                            .foregroundColor(.primary)
                                        Text("\(list.place_count) places")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListSheet(onCreated: {
                    loadLists()
                })
            }
            .onAppear {
                loadLists()
            }
        }
    }
    
    func loadLists() {
        isLoading = true
        Task {
            do {
                lists = try await ListsAPI.shared.getLists()
                isLoading = false
            } catch {
                print("❌ Failed to load lists: \(error)")
                isLoading = false
            }
        }
    }
    
    func addToList(_ list: PlaceList) {
        Task {
            do {
                try await ListsAPI.shared.addPlaceToList(listId: list.id, placeId: place.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Failed to add to list: \(error)")
            }
        }
    }
}
