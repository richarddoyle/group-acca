import SwiftUI

struct GroupListView: View {
    @State private var groups: [BettingGroup] = []
    @Binding var selectedGroup: BettingGroup?
    
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var isLoading = false
    
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoading && groups.isEmpty {
                        ProgressView()
                    } else if groups.isEmpty {
                        Text("No groups found. Create or join one!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groups) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(group.name)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    if selectedGroup?.id == group.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteGroups)
                    }
                } header: {
                    Text("Your Groups")
                }
                
                Section {
                    Button(action: { showingCreateGroup = true }) {
                        Label("Create New Group", systemImage: "plus")
                    }
                    Button(action: { showingJoinGroup = true }) {
                        Label("Join Existing Group", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("My Groups")
            .refreshable {
                await loadGroups()
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView { groupName in
                Task {
                    do {
                        let userId = SupabaseService.shared.currentUserId
                        let profile = try await SupabaseService.shared.fetchProfile(id: userId)
                        // 1. Create Group (now also automatically adds creator as admin)
                        let newGroup = try await SupabaseService.shared.createGroup(name: groupName, stake: 5.0)
                        
                        // 2. Update UI on Main Thread
                        await MainActor.run {
                            self.groups.insert(newGroup, at: 0) // Optimistic add to top
                            self.selectedGroup = newGroup       // Trigger navigation
                            self.showingCreateGroup = false     // Dismiss sheet
                        }
                        
                        // Full refresh in background
                        await loadGroups()
                        
                    } catch {
                        await MainActor.run {
                            self.errorTitle = "Failed to Create Group"
                            self.errorMessage = error.localizedDescription
                            self.showingError = true
                        }
                        print("Error creating group: \(error)")
                    }
                }
            }
        }
            .sheet(isPresented: $showingJoinGroup) {
                JoinGroupView(onJoinSuccess: {
                    Task {
                        await loadGroups()
                    }
                })
            }
            .task {
                await loadGroups()
            }
        }
    }
    
    private func loadGroups() async {
        isLoading = true
        do {
            let fetchedGroups = try await SupabaseService.shared.fetchGroups(for: SupabaseService.shared.currentUserId)
            await MainActor.run {
                self.groups = fetchedGroups
                // Auto-select first if none selected
                self.groups = fetchedGroups
                isLoading = false
            }
        } catch {
            print("Error loading groups: \(error)")
            isLoading = false
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        let groupsToRemove = offsets.map { groups[$0] }
        
        // Optimistically update UI
        groups.remove(atOffsets: offsets)
        
        Task {
            for group in groupsToRemove {
                do {
                    try await SupabaseService.shared.deleteGroup(id: group.id)
                } catch {
                    print("Error deleting group: \(error)")
                    // Optionally: rollback UI or show error
                }
            }
        }
    }
}
