import SwiftUI

struct GroupLeaderboardView: View {
    let group: BettingGroup
    @State private var members: [Member] = []
    @State private var profiles: [UUID: Profile] = [:]
    
    // Metrics
    @State private var winRates: [UUID: Double] = [:]
    @State private var winningPicksCount: [UUID: Int] = [:]
    @State private var totalWinnings: [UUID: Double] = [:]
    @State private var allTimeWinStreaks: [UUID: Int] = [:]
    @State private var currentWinStreaks: [UUID: Int] = [:]
    @State private var allTimeLosingStreaks: [UUID: Int] = [:]
    @State private var currentLosingStreaks: [UUID: Int] = [:]
    
    @State private var isLoading = true
    @State private var selectedMetric: LeaderboardMetric = .winPercentage
    
    enum LeaderboardMetric: String, CaseIterable, Identifiable {
        case winPercentage = "% Won"
        case winningPicks = "Winning Picks"
        case totalWon = "Total Won"
        case allTimeWinStreak = "All-Time Win Streak"
        case currentWinStreak = "Current Win Streak"
        case allTimeLosingStreak = "All-Time Losing Streak"
        case currentLosingStreak = "Current Losing Streak"
        
        var id: String { rawValue }
    }
    
    // Sort logic
    private var sortedMembers: [Member] {
        members.sorted { m1, m2 in
            switch selectedMetric {
            case .winPercentage:
                return (winRates[m1.id] ?? 0.0) > (winRates[m2.id] ?? 0.0)
            case .winningPicks:
                return (winningPicksCount[m1.id] ?? 0) > (winningPicksCount[m2.id] ?? 0)
            case .totalWon:
                return (totalWinnings[m1.id] ?? 0.0) > (totalWinnings[m2.id] ?? 0.0)
            case .allTimeWinStreak:
                return (allTimeWinStreaks[m1.id] ?? 0) > (allTimeWinStreaks[m2.id] ?? 0)
            case .currentWinStreak:
                return (currentWinStreaks[m1.id] ?? 0) > (currentWinStreaks[m2.id] ?? 0)
            case .allTimeLosingStreak:
                return (allTimeLosingStreaks[m1.id] ?? 0) > (allTimeLosingStreaks[m2.id] ?? 0)
            case .currentLosingStreak:
                return (currentLosingStreaks[m1.id] ?? 0) > (currentLosingStreaks[m2.id] ?? 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LeaderboardMetric.allCases) { metric in
                        Button {
                            withAnimation {
                                selectedMetric = metric
                            }
                        } label: {
                            Text(metric.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedMetric == metric ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(selectedMetric == metric ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))
            
            List {
                if isLoading {
                    ProgressView()
                        .listRowBackground(Color.clear)
                } else if members.isEmpty {
                    Text("No rankings yet")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            ProfileImage(url: profiles[member.userId ?? UUID()]?.avatarUrl, size: 40)
                            
                            Text(member.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            statView(for: member)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    @ViewBuilder
    private func statView(for member: Member) -> some View {
        switch selectedMetric {
        case .winPercentage:
            if let rate = winRates[member.id] {
                Text("\(Int(rate * 100))%")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            } else {
                Text("N/A")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
        case .winningPicks:
            Text("\(winningPicksCount[member.id] ?? 0)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        case .totalWon:
            let won = totalWinnings[member.id] ?? 0.0
            Text("£\(String(format: "%.2f", won))")
                .font(.title3.bold())
                .foregroundStyle(won > 0 ? .green : .primary)
        case .allTimeWinStreak:
            Text("\(allTimeWinStreaks[member.id] ?? 0)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        case .currentWinStreak:
            Text("\(currentWinStreaks[member.id] ?? 0)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        case .allTimeLosingStreak:
            Text("\(allTimeLosingStreaks[member.id] ?? 0)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        case .currentLosingStreak:
            Text("\(currentLosingStreaks[member.id] ?? 0)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
    }
    
    private func loadData() async {
        do {
            let fetchedMembers = try await SupabaseService.shared.fetchMembers(for: group.id)
            let memberIds = fetchedMembers.map { $0.id }
            let selections = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            // Fetch profiles
            let userIds = fetchedMembers.compactMap { $0.userId }
            let fetchedProfiles = try await SupabaseService.shared.fetchProfiles(ids: userIds)
            
            var localWinRates: [UUID: Double] = [:]
            var localWinCounts: [UUID: Int] = [:]
            var localTotalWinnings: [UUID: Double] = [:]
            var localAllTimeWinStreaks: [UUID: Int] = [:]
            var localCurrentWinStreaks: [UUID: Int] = [:]
            var localAllTimeLosingStreaks: [UUID: Int] = [:]
            var localCurrentLosingStreaks: [UUID: Int] = [:]
            
            for member in fetchedMembers {
                let memberSelections = selections.filter { $0.memberId == member.id && ($0.outcome == .win || $0.outcome == .loss) }
                let winningPicks = memberSelections.filter { $0.outcome == .win }
                
                let wonCount = winningPicks.count
                let total = memberSelections.count
                
                // Win Rate
                localWinRates[member.id] = total > 0 ? Double(wonCount) / Double(total) : 0.0
                
                // Winning Picks Count
                localWinCounts[member.id] = wonCount
                
                // Total Won (Stake * Odds for each winning pick)
                let winnings = winningPicks.reduce(0.0) { sum, pick in
                    sum + (group.stakePerPerson * pick.odds)
                }
                localTotalWinnings[member.id] = winnings
                
                // Win & Loss Streak Calculation
                var maxWinStreak = 0
                var currentWinStreakCount = 0
                var maxLosingStreak = 0
                var currentLosingStreakCount = 0
                
                // Sort chronologically (assuming created_at exists, else sort by array order assuming it represents time to some degree)
                // Selections model has `kickoffTime` or we can just iterate. Kickoff is safest.
                let sortedResolved = memberSelections.sorted { ($0.kickoffTime ?? Date.distantPast) < ($1.kickoffTime ?? Date.distantPast) }
                for pick in sortedResolved {
                    if pick.outcome == .win {
                        currentWinStreakCount += 1
                        maxWinStreak = max(maxWinStreak, currentWinStreakCount)
                        currentLosingStreakCount = 0 // Reset losing streak on win
                    } else if pick.outcome == .loss {
                        currentLosingStreakCount += 1
                        maxLosingStreak = max(maxLosingStreak, currentLosingStreakCount)
                        currentWinStreakCount = 0 // Reset win streak on loss
                    }
                }
                localAllTimeWinStreaks[member.id] = maxWinStreak
                localCurrentWinStreaks[member.id] = currentWinStreakCount
                localAllTimeLosingStreaks[member.id] = maxLosingStreak
                localCurrentLosingStreaks[member.id] = currentLosingStreakCount
            }
            
            await MainActor.run {
                self.members = fetchedMembers
                self.winRates = localWinRates
                self.winningPicksCount = localWinCounts
                self.totalWinnings = localTotalWinnings
                self.allTimeWinStreaks = localAllTimeWinStreaks
                self.currentWinStreaks = localCurrentWinStreaks
                self.allTimeLosingStreaks = localAllTimeLosingStreaks
                self.currentLosingStreaks = localCurrentLosingStreaks
                
                var profileMap: [UUID: Profile] = [:]
                for p in fetchedProfiles {
                    profileMap[p.id] = p
                }
                self.profiles = profileMap
                
                self.isLoading = false
            }
        } catch {
            print("Error loading leaderboard data: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}
