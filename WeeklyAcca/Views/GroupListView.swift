import SwiftUI

struct GroupListView: View {
    @State private var groups: [BettingGroup] = []
    @Binding var selectedGroup: BettingGroup?
    
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var isLoading = false
    
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
                        // .onDelete(perform: deleteGroups) // TODO: Implement delete
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
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { groupName, userName in
                    Task {
                        do {
                            // 1. Create Group
                            let newGroup = try await SupabaseService.shared.createGroup(name: groupName, stake: 10.0)
                            
                            // 2. Add creator as member
                            // We need to implement addMember in service or use join logic logic
                            // Actually createGroup should probably add the creator automatically or we do it here
                            let _ = try await SupabaseService.shared.joinGroup(code: newGroup.joinCode, userName: userName, userId: SupabaseService.shared.currentUserId)
                            
                            await loadGroups()
                            selectedGroup = newGroup
                        } catch {
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
}
