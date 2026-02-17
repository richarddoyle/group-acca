import SwiftUI


struct ProfileView: View {
    @Binding var selectedGroup: BettingGroup?
    
    @State private var groups: [BettingGroup] = []
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("My Groups") {
                    if isLoading {
                        ProgressView()
                    } else if groups.isEmpty {
                        Text("No groups found")
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
                        // .onDelete(perform: deleteGroups) // TODO: Implement Supabase delete
                    }
                    
                    Button(action: { showingCreateGroup = true }) {
                        Label("Create New Group", systemImage: "plus")
                    }
                    Button(action: { showingJoinGroup = true }) {
                        Label("Join Existing Group", systemImage: "person.badge.plus")
                    }
                }
                
                Section("App Settings") {
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                    
                    Button("Sign Out") {
                        // TODO: Implement Sign Out
                        // SupabaseService.shared.signOut()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { groupName, userName in
                    // Default stake to 5.0 for now, or update UI to ask for it
                    createGroup(name: groupName, stake: 5.0, userName: userName)
                }
            }
            .sheet(isPresented: $showingJoinGroup) {
                JoinGroupView()
            }
            .task {
                await loadGroups()
            }
            .refreshable {
                await loadGroups()
            }
        }
    }
    
    private func loadGroups() async {
        isLoading = true
        do {
            let userId = SupabaseService.shared.currentUserId
            let fetchedGroups = try await SupabaseService.shared.fetchGroups(for: userId)
            await MainActor.run {
                self.groups = fetchedGroups
                isLoading = false
            }
        } catch {
            print("Error loading groups: \(error)")
            isLoading = false
        }
    }
    
    private func createGroup(name: String, stake: Double, userName: String) {
        Task {
            do {
                let newGroup = try await SupabaseService.shared.createGroup(name: name, stake: stake)
                
                // Add current user as member
                 let _ = try await SupabaseService.shared.joinGroup(
                    code: newGroup.joinCode, 
                    userName: userName, 
                    userId: SupabaseService.shared.currentUserId
                )
                
                await loadGroups()
                await MainActor.run {
                    self.selectedGroup = newGroup
                    self.showingCreateGroup = false
                }
            } catch {
                print("Error creating group: \(error)")
            }
        }
    }
}
