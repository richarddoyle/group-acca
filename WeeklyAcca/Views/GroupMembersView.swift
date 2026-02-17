import SwiftUI

struct GroupMembersView: View {
    let group: BettingGroup
    @State private var members: [Member] = []
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
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.gray)
                            VStack(alignment: .leading) {
                                Text(member.name)
                                    .font(.body)
                                Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
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
            await MainActor.run {
                self.members = fetchedMembers
                isLoading = false
            }
        } catch {
            print("Error loading members: \(error)")
            isLoading = false
        }
    }
}
