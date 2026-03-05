import SwiftUI

struct StatsView: View {
    @State private var weeks: [Week] = []
    @State private var memberships: [Member] = []
    @State private var selections: [Selection] = []
    @State private var currentUserProfile: Profile?
    @State private var isLoading = true
    
    // Computed stats    
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
    
    private var sortedSettledSelections: [Selection] {
        selections
            .filter { $0.outcome != .pending }
            .sorted { ($0.kickoffTime ?? Date.distantPast) > ($1.kickoffTime ?? Date.distantPast) }
    }
    
    private var currentStreak: Int {
        var streak = 0
        for selection in sortedSettledSelections {
            if selection.outcome == .win {
                streak += 1
            } else if selection.outcome == .loss {
                break
            }
        }
        return streak
    }
    
    private var last10Picks: [Selection] {
        Array(sortedSettledSelections.prefix(10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My Stats")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(Color(.systemGroupedBackground))
            
            List {
                Section("Overall") {
                    StatRow(label: "Successful Picks", value: "\(successfulPicks)")
                    StatRow(label: "Successful Pick %", value: successfulPickRate.formatted(.percent.precision(.fractionLength(1))))
                    
                    StatRow(label: "Total Successful Accas", value: "\(totalSuccessfulAccas)")
                    StatRow(label: "Successful Acca %", value: successfulAccaRate.formatted(.percent.precision(.fractionLength(1))))
                }
                
                Section("Current Form") {
                    StatRow(label: "Current Win Streak", value: "\(currentStreak)")
                    
                    if !last10Picks.isEmpty {
                        ForEach(last10Picks) { pick in
                            SelectionRow(selection: pick, memberName: nil, avatarUrl: nil, isLocked: true, showMatchStatus: false)
                        }
                    } else {
                        Text("No completed picks yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
            async let fetchedProfile = SupabaseService.shared.fetchProfile(id: userId)
            
            let m = try await fetchedMemberships
            let w = try await fetchedWeeks
            let p = try? await fetchedProfile
            
            let memberIds = m.map { $0.id }
            let s = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            await MainActor.run {
                self.memberships = m
                self.weeks = w
                self.selections = s
                self.currentUserProfile = p
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
