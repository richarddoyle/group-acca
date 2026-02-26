import SwiftUI

struct StatsView: View {
    @State private var weeks: [Week] = []
    @State private var memberships: [Member] = []
    @State private var selections: [Selection] = []
    @State private var isLoading = true
    
    // Computed stats
    private var groupsMemberOf: Int { memberships.count }
    
    // Total picks from closed/resolved accas
    private var totalPicks: Int {
        let closedWeekIds = Set(weeks.filter { $0.status != .pending }.map { $0.id })
        return selections.filter { closedWeekIds.contains($0.accaId) && $0.outcome != .pending }.count
    }
    
    private var successfulPicks: Int {
        let closedWeekIds = Set(weeks.filter { $0.status != .pending }.map { $0.id })
        return selections.filter { closedWeekIds.contains($0.accaId) && $0.outcome == .win }.count
    }
    
    private var successfulPickRate: Double {
        guard totalPicks > 0 else { return 0 }
        return Double(successfulPicks) / Double(totalPicks)
    }
    
    // Total resolved and closed accas the user was part of
    private var totalAccas: Int {
        // Filter weeks that are not pending and where user had a SETTLED selection
        let userSettledWeekIds = Set(selections.filter { $0.outcome != .pending }.map { $0.accaId })
        return weeks.filter { $0.status != .pending && userSettledWeekIds.contains($0.id) }.count
    }
    
    private var totalSuccessfulAccas: Int {
        let userSettledWeekIds = Set(selections.filter { $0.outcome != .pending }.map { $0.accaId })
        return weeks.filter { $0.status == .won && userSettledWeekIds.contains($0.id) }.count
    }
    
    private var successfulAccaRate: Double {
        guard totalAccas > 0 else { return 0 }
        return Double(totalSuccessfulAccas) / Double(totalAccas)
    }
    
    var body: some View {
        List {
            Section("Overall") {
                StatRow(label: "Groups Member Of", value: "\(groupsMemberOf)")
                StatRow(label: "Total Picks", value: "\(totalPicks)")
                StatRow(label: "Successful Picks", value: "\(successfulPicks)")
                StatRow(label: "Successful Pick %", value: successfulPickRate.formatted(.percent.precision(.fractionLength(1))))
                
                StatRow(label: "Total Accas", value: "\(totalAccas)")
                StatRow(label: "Total Successful Accas", value: "\(totalSuccessfulAccas)")
                StatRow(label: "Successful Acca %", value: successfulAccaRate.formatted(.percent.precision(.fractionLength(1))))
            }
        }
        .navigationTitle("My Stats")
        .refreshable {
            await loadStats()
        }
        .overlay {
            if isLoading {
                ProgressView()
            } else if memberships.isEmpty && !isLoading {
                ContentUnavailableView("No Stats Yet", systemImage: "chart.bar.fill", description: Text("Join a group and make some picks to see your stats!"))
            }
        }
        .task {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        let userId = SupabaseService.shared.currentUserId
        
        do {
            async let fetchedMemberships = SupabaseService.shared.fetchMyMemberships(userId: userId)
            async let fetchedWeeks = SupabaseService.shared.fetchAllMyWeeks(userId: userId)
            
            let m = try await fetchedMemberships
            let w = try await fetchedWeeks
            
            let memberIds = m.map { $0.id }
            let s = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            await MainActor.run {
                self.memberships = m
                self.weeks = w
                self.selections = s
                self.isLoading = false
            }
        } catch {
            print("Error loading stats: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .bold()
        }
    }
}

#Preview {
    StatsView()
}
