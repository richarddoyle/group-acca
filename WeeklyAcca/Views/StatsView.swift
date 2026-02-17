import SwiftUI

struct StatsView: View {
    let group: BettingGroup?
    @State private var weeks: [Week] = []
    @State private var isLoading = false
    
    // Computed stats
    private var totalWeeks: Int { weeks.count }
    private var weeksWon: Int {
        weeks.filter { $0.status == .won }.count
    }
    private var winRate: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(weeksWon) / Double(totalWeeks)
    }
    
    // Financials (Simplified)
    private var totalStaked: Double {
        return 0.0 // Placeholder
    }
    
    var body: some View {
        List {
            if let group = group {
                Section("Group: \(group.name)") {
                    // Group specific header logic if needed
                }
            } else {
                Section("All Groups") {
                    Text("Aggregated Stats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Performance") {
                HStack {
                    Text("Weeks Won")
                    Spacer()
                    Text("\(weeksWon)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Win Rate")
                    Spacer()
                    Text(winRate, format: .percent)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Financials") {
                HStack {
                    Text("Total Staked")
                    Spacer()
                    Text(totalStaked, format: .currency(code: "GBP"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Total Returns")
                    Spacer()
                    Text(0, format: .currency(code: "GBP"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: group?.id) {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        isLoading = true
        do {
            if let group = group {
                let fetchedWeeks = try await SupabaseService.shared.fetchWeeks(groupId: group.id)
                await MainActor.run {
                    self.weeks = fetchedWeeks
                    isLoading = false
                }
            } else {
                // Fetch stats for ALL groups the user is in
                // 1. Fetch user's groups
                let userId = SupabaseService.shared.currentUserId
                let userGroups = try await SupabaseService.shared.fetchGroups(for: userId)
                
                // 2. Fetch weeks for all groups (concurrently)
                var allWeeks: [Week] = []
                for grp in userGroups {
                    let groupWeeks = try await SupabaseService.shared.fetchWeeks(groupId: grp.id)
                    allWeeks.append(contentsOf: groupWeeks)
                }
                
                await MainActor.run {
                    self.weeks = allWeeks
                    isLoading = false
                }
            }
        } catch {
            print("Error loading stats: \(error)")
            isLoading = false
        }
    }
}
