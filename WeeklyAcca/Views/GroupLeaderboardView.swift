import SwiftUI

struct GroupLeaderboardView: View {
    let group: BettingGroup
    @State private var members: [Member] = []
    @State private var winRates: [UUID: Double] = [:]
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(members.sorted(by: { (winRates[$0.id] ?? 0.0) > (winRates[$1.id] ?? 0.0) }).enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        Text(member.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        if let rate = winRates[member.id] {
                            Text("\(Int(rate * 100))%")
                                .font(.title3.bold())
                                .foregroundStyle((rate >= 0.5 || rate.isNaN) ? .green : .orange) // Green if 50%+
                        } else {
                            Text("N/A")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await loadMembers()
        }
        .refreshable {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        do {
            let fetchedMembers = try await SupabaseService.shared.fetchMembers(for: group.id)
            let memberIds = fetchedMembers.map { $0.id }
            let selections = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            var localWinRates: [UUID: Double] = [:]
            for member in fetchedMembers {
                let memberSelections = selections.filter { $0.memberId == member.id && ($0.outcome == .win || $0.outcome == .loss) }
                let wonCount = memberSelections.filter { $0.outcome == .win }.count
                let total = memberSelections.count
                localWinRates[member.id] = total > 0 ? Double(wonCount) / Double(total) : 0.0
            }
            
            await MainActor.run {
                self.members = fetchedMembers
                self.winRates = localWinRates
                self.isLoading = false
            }
        } catch {
            print("Error loading members for leaderboard: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}
