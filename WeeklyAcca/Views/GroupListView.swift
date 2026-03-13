import SwiftUI

struct GroupDisplayState: Identifiable {
    var id: UUID { group.id }
    let group: BettingGroup
    let adminName: String
    let memberCount: Int
}

struct GroupListView: View {
    @State private var groupStates: [GroupDisplayState] = []
    @Binding var selectedGroup: BettingGroup?
    
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var isLoading = false
    
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Groups")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
                List {
                Section {
                    if isLoading && groupStates.isEmpty {
                        ProgressView()
                    } else if groupStates.isEmpty {
                        Text("No groups found. Create or join one!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groupStates) { state in
                            Button {
                                selectedGroup = state.group
                            } label: {
                                HStack(spacing: 16) {
                                    // Group Avatar
                                     if let urlString = state.group.avatarUrl {
                                        CachedImage(url: urlString) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Image(systemName: "person.3.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Image(systemName: "person.3.fill")
                                                    .foregroundStyle(.secondary)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(state.group.name)
                                            .font(.headline)
                                        
                                        HStack {
                                            Text("Admin: \(state.adminName)")
                                            Text("•")
                                            Text("\(state.memberCount) Member\(state.memberCount == 1 ? "" : "s")")
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedGroup?.id == state.group.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
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
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadGroups()
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView { groupName, imageData in
                Task {
                    do {
                        let userId = SupabaseService.shared.currentUserId
                        _ = try await SupabaseService.shared.fetchProfile(id: userId)
                        
                        var avatarUrl: String? = nil
                        if let data = imageData {
                            avatarUrl = try await SupabaseService.shared.uploadAvatar(imageData: data, userId: userId)
                        }
                        
                        // 1. Create Group (now also automatically adds creator as admin)
                        let newGroup = try await SupabaseService.shared.createGroup(name: groupName, stake: 5.0, avatarUrl: avatarUrl)
                        
                        // 2. Fetch its fresh display state
                        let members = try await SupabaseService.shared.fetchMembers(for: newGroup.id)
                        var adminName = "Unknown"
                        if let adminProfile = try? await SupabaseService.shared.fetchProfile(id: newGroup.adminId) {
                            adminName = adminProfile.username
                        }
                        let newState = GroupDisplayState(group: newGroup, adminName: adminName, memberCount: members.count)
                        
                        // 3. Update UI on Main Thread
                        await MainActor.run {
                            self.groupStates.insert(newState, at: 0) // Optimistic add to top
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
            
            // Build states concurrently
            var states: [GroupDisplayState] = []
            for group in fetchedGroups {
                // In a production app, this N+1 problem would be solved in the Supabase query via joins.
                // For now, we fetch properties concurrently per group.
                async let members = SupabaseService.shared.fetchMembers(for: group.id)
                async let adminProfile = SupabaseService.shared.fetchProfile(id: group.adminId)
                
                var adminName = "Unknown"
                if let profile = try? await adminProfile {
                    adminName = profile.username
                }
                
                let count = (try? await members.count) ?? 0
                states.append(GroupDisplayState(group: group, adminName: adminName, memberCount: count))
            }
            
            let finalStates = states
            
            await MainActor.run {
                self.groupStates = finalStates
                isLoading = false
            }
        } catch {
            print("Error loading groups: \(error)")
            isLoading = false
        }
    }
}
