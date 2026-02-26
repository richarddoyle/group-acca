import SwiftUI

struct GroupMembersView: View {
    let group: BettingGroup
    @State private var members: [Member] = []
    @State private var profiles: [UUID: Profile] = [:]
    @State private var isLoading = false
    
    var body: some View {
        List {
            Section("Members") {
                if isLoading {
                    ProgressView()
                } else if members.isEmpty {
                    Text("No members yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            ProfileImage(url: profiles[member.userId ?? UUID()]?.avatarUrl, size: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(member.name)
                                        .font(.headline)
                                    if member.userId == group.adminId {
                                        Text("Admin")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadMembers()
        }
        .task {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            let fetchedMembers = try await SupabaseService.shared.fetchMembers(for: group.id)
            
            // Fetch profiles for avatars
            let userIds = fetchedMembers.compactMap { $0.userId }
            let fetchedProfiles = try await SupabaseService.shared.fetchProfiles(ids: userIds)
            
            await MainActor.run {
                self.members = fetchedMembers
                var profileMap: [UUID: Profile] = [:]
                for p in fetchedProfiles {
                    profileMap[p.id] = p
                }
                self.profiles = profileMap
                isLoading = false
            }
        } catch {
            print("Error loading members: \(error)")
            isLoading = false
        }
    }
}
