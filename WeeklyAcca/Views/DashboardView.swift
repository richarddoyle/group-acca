import SwiftUI

enum DashboardTab: String, CaseIterable {
    case accas = "Accas"
    case stats = "Stats"
    case members = "Members"

}

struct DashboardView: View {
    let group: BettingGroup
    @Binding var selectedGroup: BettingGroup?
    @State private var weeks: [Week] = []
    @State private var selectedTab: DashboardTab = .accas
    @State private var showingCreateAcca = false
    @State private var showingMatchSelection = false
    @State private var path = NavigationPath()
    @State private var isLoading = false
    @State private var memberCount: Int = 0
    
    // Derived current week for "Make Your Pick" logic
    var currentWeek: Week? {
        weeks.sorted { $0.weekNumber > $1.weekNumber }.first
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Header Information
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.name)
                        .font(.largeTitle)
                        .bold()
                    
                    HStack {
                        Text("\(memberCount) Members")
                        Text("•")
                        Text("Code: \(group.joinCode)")
                        
                        Button {
                            UIPasteboard.general.string = group.joinCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Native Segmented Control
                Picker("View", selection: $selectedTab) {
                    ForEach(DashboardTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                
                // Content Area
                Group {
                    switch selectedTab {
                    case .accas:
                        GroupWeeksView(weeks: weeks, group: group, path: $path)
                    case .stats:
                        StatsView(group: group)
                    case .members:
                        GroupMembersView(group: group)

                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedGroup = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("My Groups")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateAcca = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateAcca) {
                CreateAccaView(group: group, nextWeekNumber: (weeks.map { $0.weekNumber }.max() ?? 0) + 1)
            }
            .navigationDestination(isPresented: $showingMatchSelection) {
                if let week = currentWeek {
                     MatchSelectionView(
                        selection: Selection(
                            id: UUID(), 
                            accaId: week.id, 
                            memberId: SupabaseService.shared.currentUserId, 
                            teamName: "Pending", 
                            league: "", 
                            outcome: .pending, 
                            odds: 0.0
                        ),
                        week: week
                     )
                }
            }
        }
        .task {
            await loadWeeks()
        }
    }
    
    private func loadWeeks() async {
        isLoading = true
        do {
            async let fetchedWeeks = SupabaseService.shared.fetchWeeks(groupId: group.id)
            async let fetchedMembers = SupabaseService.shared.fetchMembers(for: group.id)
            
            let weeksResults = try await fetchedWeeks
            let membersResults = try await fetchedMembers
            
            await MainActor.run {
                self.weeks = weeksResults
                self.memberCount = membersResults.count
                isLoading = false
            }
        } catch {
            print("Error loading weeks: \(error)")
            isLoading = false
        }
    }
}

struct EditSelectionWrapper: Hashable {
    let selection: Selection
}

struct GroupWeeksView: View {
    let weeks: [Week]
    let group: BettingGroup
    @Binding var path: NavigationPath
    
    var body: some View {
        List {
            if weeks.isEmpty {
                ContentUnavailableView("No Accumulators", systemImage: "sportscourt", description: Text("Start a new accumulator to begin tracking bets."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(weeks) { week in
                    NavigationLink(destination: WeekDetailView(week: week, group: group, path: $path)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(week.title)
                                    .font(.headline)
                                Text(week.startDate, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            WeekStatusBadge(week: week)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteWeeks)
            }
        }
        .listStyle(.plain)
    }
    
    private func deleteWeeks(offsets: IndexSet) {
        // TODO: Implement delete
    }
}

struct WeekStatusBadge: View {
    let week: Week
    
    var body: some View {
        if week.status == .pending {
            if week.isOpen {
                Text("Open")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.blue)
            } else {
                Text("In Progress")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.orange)
            }
        } else {
            StatusBadge(status: week.status)
        }
    }
}

struct StatusBadge: View {
    let status: WeekStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }
    
    var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .won: return .green
        case .lost: return .red
        }
    }
}

struct WeekDetailView: View {
    let week: Week
    let group: BettingGroup
    @Binding var path: NavigationPath
    @AppStorage("userName") private var userName: String = ""
    
    @State private var selections: [Selection] = []
    @State private var members: [Member] = []
    
    // Computed property for "My Selection"
    private var mySelection: Selection? {
        guard let myMember = members.first(where: { $0.userId == SupabaseService.shared.currentUserId }) else {
            return nil
        }
        return selections.first { $0.memberId == myMember.id }
    }
    
    // Computed property for "Member Selections"
    private var memberSelections: [MemberSelectionDisplay] {
        members
            .filter { $0.userId != SupabaseService.shared.currentUserId } // Filter out me
            .map { member in
                let selection = selections.first(where: { $0.memberId == member.id })
                return MemberSelectionDisplay(member: member, selection: selection)
            }
    }
    
    // Financials
    private var totalStake: Double {
        Double(selections.count) * group.stakePerPerson
    }
    
    private var potentialWinnings: Double {
        let combinedOdds = selections.reduce(1.0) { result, selection in
            let odds = selection.odds > 0 ? selection.odds : 1.0
            return result * odds
        }
        return totalStake * combinedOdds
    }
    
    var body: some View {
        List {
            Section("Week \(week.weekNumber) Summary") {
                HStack {
                    Text("Status")
                    Spacer()
                    WeekStatusBadge(week: week)
                }
                HStack {
                    Text("Total Stake")
                    Spacer()
                    Text(totalStake, format: .currency(code: "GBP"))
                }
                HStack {
                    Text("Potential Winnings")
                    Spacer()
                    
                    Text(potentialWinnings, format: .currency(code: "GBP"))
                        .foregroundStyle(.green)
                        .bold()
                }
            }
            
            // MARK: - My Pick Section
            Section("My Pick") {
                if let selection = mySelection {
                    // Only allow navigation if Week is open OR if we just want to view details (we can disable editing inside)
                    // Better UX: Always navigate, but handle "Edit" vs "View" inside Detail or change destination.
                    // For now, let's keep it simple: If Locked, show row but maybe change destination or disable interaction if it was just an edit flow.
                    // Actually, the requirement says "users can no longer edit their picks".
                    
                    if week.isOpen {
                        NavigationLink(destination: MatchSelectionView(selection: selection, week: week)) {
                            SelectionRow(selection: selection, isLocked: false)
                        }
                    } else {
                        // Locked view
                         HStack {
                            VStack(alignment: .leading) {
                                Text(selection.teamName)
                                    .font(.headline)
                                Text("@ \(selection.odds.formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let status = selection.matchStatus, status != "NS" {
                                Text(status)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Scores
                            if let home = selection.homeScore, let away = selection.awayScore {
                                Text("\(home) - \(away)")
                                    .font(.headline)
                                    .monospacedDigit()
                            } else {
                                StatusBadge(status: mapOutcomeToStatus(selection.outcome))
                            }
                        }
                    }
                } else {
                    if week.isOpen {
                        Button {
                            createMyPick()
                        } label: {
                            HStack {
                                Text("Make Your Pick")
                                    .foregroundStyle(Color.blue)
                                Spacer()
                                Text("Pick needed")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                    } else {
                         Text("Locked - no pick made")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
            
            // MARK: - Member Picks Section
            Section("Member Picks") {
                if memberSelections.isEmpty {
                    Text("No other members")
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(memberSelections, id: \.member.id) { item in
                        HStack {
                            Text(item.member.name)
                            Spacer()
                            if let selection = item.selection {
                                Text(selection.teamName)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Pending")
                                    .foregroundStyle(.orange)
                                    .italic()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Week \(week.weekNumber)")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        do {
            async let fetchedSelections = SupabaseService.shared.fetchSelections(weekId: week.id)
            async let fetchedMembers = SupabaseService.shared.fetchMembers(for: group.id)
            
            self.selections = try await fetchedSelections
            self.members = try await fetchedMembers
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func createMyPick() {
        Task {
            do {
                let currentUserId = SupabaseService.shared.currentUserId
                
                if let myMember = members.first(where: { $0.userId == currentUserId }) {
                     let finalSelection = Selection(
                        id: UUID(),
                        accaId: week.id,
                        memberId: myMember.id,
                        teamName: "Pending",
                        league: "Pending",
                        outcome: .pending,
                        odds: 0.0
                     )
                     try await SupabaseService.shared.saveSelection(finalSelection)
                     await loadData()
                } else {
                    print("Could not find member record for current user")
                }
            } catch {
                print("Error creating pick: \(error)")
            }
        }
    }
    
    private func mapOutcomeToStatus(_ outcome: SelectionOutcome) -> WeekStatus {
        switch outcome {
        case .pending: return .pending
        case .win: return .won
        case .loss: return .lost
        case .void: return .pending 
        }
    }
}

// Helper struct for display to avoid complex logic in view
struct MemberSelectionDisplay {
    let member: Member
    let selection: Selection?
}

struct SelectionRow: View {
    let selection: Selection
    let isLocked: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(selection.teamName)
                    .font(.headline)
                Text("@ \(selection.odds.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            if let status = selection.matchStatus, status != "NS" {
                // Match is Live or Finished
                VStack(alignment: .trailing) {
                    Text(status)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    if let home = selection.homeScore, let away = selection.awayScore {
                         Text("\(home) - \(away)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            } else {
                // Pre-match or no status info
                if selection.outcome == .pending {
                    if isLocked {
                        // Locked & Pending & NS -> Show Kickoff Time
                        if let kickoff = selection.kickoffTime {
                            Text(kickoff, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not Started")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Open -> Pending Badge
                        StatusBadge(status: .pending)
                    }
                } else {
                    StatusBadge(status: mapOutcomeToStatus(selection.outcome))
                }
            }
        }
    }
    
    private func mapOutcomeToStatus(_ outcome: SelectionOutcome) -> WeekStatus {
        switch outcome {
        case .pending: return .pending
        case .win: return .won
        case .loss: return .lost
        case .void: return .pending 
        }
    }
}
