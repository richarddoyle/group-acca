import SwiftUI

struct ActiveAward: Identifiable, Hashable {
    let id = UUID()
    let emoji: String
    let groupName: String
    let description: String
}

struct StatsView: View {
    @State private var weeks: [Week] = []
    @State private var memberships: [Member] = []
    @State private var selections: [Selection] = []
    @State private var activeAwards: [ActiveAward] = []
    @State private var groups: [BettingGroup] = []
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
            .sorted { a, b in
                let dateA = a.kickoffTime ?? Date.distantPast
                let dateB = b.kickoffTime ?? Date.distantPast
                if dateA == dateB {
                    return a.id.uuidString > b.id.uuidString
                }
                return dateA > dateB
            }
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
        List {
                Section("Overall") {
                    StatRow(label: "Successful Picks", value: "\(successfulPicks)")
                    StatRow(label: "Successful Pick %", value: successfulPickRate.formatted(.percent.precision(.fractionLength(1))))
                    
                    StatRow(label: "Total Successful Accas", value: "\(totalSuccessfulAccas)")
                    StatRow(label: "Successful Acca %", value: successfulAccaRate.formatted(.percent.precision(.fractionLength(1))))
                }
                
                Section("Active Awards") {
                    if activeAwards.isEmpty {
                        Text("No active awards. Make some winning picks to earn some!")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        let groupedAwards = Dictionary(grouping: activeAwards, by: { $0.groupName })
                        let sortedGroups = groupedAwards.keys.sorted()
                        
                        ForEach(sortedGroups, id: \.self) { groupName in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(groupName)
                                    .font(.headline)
                                
                                if let awardsInGroup = groupedAwards[groupName] {
                                    ForEach(awardsInGroup) { award in
                                        HStack(spacing: 8) {
                                            Text(award.emoji)
                                                .font(.system(size: 24))
                                            
                                            Text(award.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 0)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section("Current Form") {
                    StatRow(label: "Current Win Streak", value: "\(currentStreak)")
                    
                    if !last10Picks.isEmpty {
                        ForEach(last10Picks) { pick in
                            let groupName = groupName(for: pick)
                            SelectionRow(selection: pick, memberName: groupName, avatarUrl: nil, isLocked: true, showMatchStatus: false, hideBadge: true)
                        }
                    } else {
                        Text("No completed picks yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        .navigationTitle("My Stats")
        .navigationBarTitleDisplayMode(.large)
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
            async let fetchedGroups = SupabaseService.shared.fetchGroups(for: userId)
            
            let m = try await fetchedMemberships
            let w = try await fetchedWeeks
            let p = try? await fetchedProfile
            let g = try await fetchedGroups
            
            let memberIds = m.map { $0.id }
            let s = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            var newAwards: [ActiveAward] = []
            for group in g {
                guard let myMemberId = m.first(where: { $0.groupId == group.id })?.id else { continue }
                
                let badgeManager = GroupBadgeManager()
                await badgeManager.loadBadges(for: group)
                
                let topWinners = badgeManager.topWinners
                let topEarners = badgeManager.topEarners
                let streakBadges = badgeManager.streakBadges
                
                if topWinners.contains(myMemberId) {
                    newAwards.append(ActiveAward(emoji: "👑", groupName: group.name, description: "Most successful picks in the group."))
                }
                
                if topEarners.contains(myMemberId) {
                    newAwards.append(ActiveAward(emoji: "💰", groupName: group.name, description: "Highest total winnings in the group."))
                }
                
                if let streakBadge = streakBadges[myMemberId] {
                    let desc: String
                    if streakBadge == "🐐" { desc = "On a 10+ win streak." }
                    else if streakBadge == "🚀" { desc = "On a 5+ win streak." }
                    else if streakBadge == "🔥" { desc = "On a 3+ win streak." }
                    else { desc = "On a win streak." }
                    
                    newAwards.append(ActiveAward(emoji: streakBadge, groupName: group.name, description: desc))
                }
            }
            
            await MainActor.run {
                self.memberships = m
                self.weeks = w
                self.selections = s
                self.activeAwards = newAwards
                self.currentUserProfile = p
                self.groups = g
                self.isLoading = false
            }
        } catch {
            print("Error loading stats: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    // Helper to find the group name for a given selection
    private func groupName(for selection: Selection) -> String? {
        guard let week = weeks.first(where: { $0.id == selection.accaId }) else { return nil }
        guard let group = groups.first(where: { $0.id == week.groupId }) else { return nil }
        return group.name
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
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    StatsView()
}
