import SwiftUI

struct GroupMembersView: View {
    @EnvironmentObject var badgeManager: GroupBadgeManager
    let group: BettingGroup
    @State private var members: [Member] = []
    @State private var profiles: [UUID: Profile] = [:]
    @State private var isLoading = false
    @State private var selectedMember: Member?
    
    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if members.isEmpty {
                    Text("No members yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        Button {
                            selectedMember = member
                        } label: {
                            HStack(spacing: 12) {
                                ProfileImage(url: profiles[member.userId ?? UUID()]?.avatarUrl, size: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("\(member.name)\(badgeManager.emoji(for: member.id, context: .general).map { " \($0)" } ?? "")")
                                            .font(.headline)
                                        if member.userId == group.adminId {
                                            Text("Admin")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.1))
                                                .foregroundStyle(Color.accentColor)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: $selectedMember) { member in
            MemberProfileView(
                member: member,
                group: group,
                avatarUrl: profiles[member.userId ?? UUID()]?.avatarUrl
            )
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
