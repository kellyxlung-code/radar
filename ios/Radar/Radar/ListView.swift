import SwiftUI

struct ListView: View {
    @State private var lists: [PlaceList] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var selectedList: PlaceList?
    
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
                        Text("Create lists to organize your places")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showCreateSheet = true }) {
                            Text("Create Your First List")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(lists) { list in
                                ListCard(list: list)
                                    .onTapGesture {
                                        selectedList = list
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListSheet(onCreated: {
                    loadLists()
                })
            }
            .sheet(item: $selectedList) { list in
                ListDetailView(list: list)
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
}

struct ListCard: View {
    let list: PlaceList
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji
            Text(list.emoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                
                if let description = list.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Text("\(list.place_count) places")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CreateListSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var selectedEmoji = "📌"
    @State private var isCreating = false
    
    let onCreated: () -> Void
    
    let emojis = ["📌", "🍽️", "☕", "🍸", "🛍️", "🎭", "🌳", "🎨", "💪", "✨", "🌃", "💕", "🎉", "🏖️", "🍜"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("List Name") {
                    TextField("e.g., Best Coffee in Central", text: $name)
                }
                
                Section("Description (Optional)") {
                    TextField("Add a description", text: $description)
                }
                
                Section("Choose an Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(emojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .padding(8)
                                    .background(selectedEmoji == emoji ? Color.orange.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedEmoji = emoji
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }
    
    func createList() {
        isCreating = true
        Task {
            do {
                _ = try await ListsAPI.shared.createList(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    emoji: selectedEmoji
                )
                await MainActor.run {
                    onCreated()
                    dismiss()
                }
            } catch {
                print("❌ Failed to create list: \(error)")
                isCreating = false
            }
        }
    }
}
