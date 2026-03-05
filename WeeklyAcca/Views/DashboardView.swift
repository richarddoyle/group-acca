import SwiftUI

enum DashboardTab: String, CaseIterable {
    case accas = "Accas"
    case leaderboard = "Leaderboard"
    case members = "Members"
}

struct DashboardView: View {
    @State private var currentGroup: BettingGroup
    @Binding var selectedGroup: BettingGroup?
    
    init(group: BettingGroup, selectedGroup: Binding<BettingGroup?>) {
        self._currentGroup = State(initialValue: group)
        self._selectedGroup = selectedGroup
    }
    @State private var weeks: [Week] = []
    @State private var selectedTab: DashboardTab = .accas
    @State private var showingCreateAcca = false
    @State private var showingMatchSelection = false
    @State private var showingSettings = false
    @State private var path = NavigationPath()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showCopyToast = false
    @State private var memberCount: Int = 0
    
    // Derived current week for "Make Your Pick" logic
    var currentWeek: Week? {
        weeks.sorted { $0.weekNumber > $1.weekNumber }.first
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Header Information
                HStack(spacing: 16) {
                    // Group Avatar
                    Button {
                        showingSettings = true
                    } label: {
                        Group {
                            if let urlString = currentGroup.avatarUrl {
                                CachedImage(url: urlString) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "person.3.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.title)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentGroup.name)
                            .font(.title2)
                            .bold()
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundStyle(.primary)
                        
                        HStack {
                            Text("\(memberCount) Members")
                            Text("•")
                            Text("Code: \(currentGroup.joinCode)")
                        
                            Button {
                                UIPasteboard.general.string = currentGroup.joinCode
                                withAnimation { showCopyToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopyToast = false }
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                // Tabbed Menu Navigation
                HStack(spacing: 0) {
                    ForEach(DashboardTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .bold : .medium)
                                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                
                                // Indicator bar
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemBackground))
                
                // Content Area
                Group {
                    switch selectedTab {
                    case .accas:
                    GroupWeeksView(weeks: $weeks, group: currentGroup, path: $path, onRefresh: {
                        await loadWeeks()
                    })
                case .leaderboard:
                        GroupLeaderboardView(group: currentGroup)
                    case .members:
                        GroupMembersView(group: currentGroup)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedGroup = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Groups")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateAcca = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Create")
                            Image(systemName: "plus")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showingCreateAcca) {
                CreateAccaView(group: currentGroup, nextWeekNumber: (weeks.map { $0.weekNumber }.max() ?? 0) + 1) {
                    Task {
                        await loadWeeks()
                    }
                }
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
            .navigationDestination(isPresented: $showingSettings) {
                GroupSettingsView(group: $currentGroup, onLeaveGroup: {
                    selectedGroup = nil
                })
            }
        }
        .overlay(alignment: .bottom) {
            if showCopyToast {
                Text("Copied to clipboard")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
                    .zIndex(1)
            }
        }
        .task {
            await loadWeeks()
        }
    }
    
    private func loadWeeks() async {
        isLoading = true
        do {
            async let fetchedWeeks = SupabaseService.shared.fetchWeeks(groupId: currentGroup.id)
            async let fetchedMembers = SupabaseService.shared.fetchMembers(for: currentGroup.id)
            
            let weeksResults = try await fetchedWeeks
            let membersResults = try await fetchedMembers
            
            await MainActor.run {
                self.weeks = weeksResults
                self.memberCount = membersResults.count
                isLoading = false
            }
            
            // --- Silent Sweep: Fix any weeks stuck in "pending" that should be won/lost ---
            let pendingWeekIds = weeksResults.filter { $0.status == WeekStatus.pending }.map { $0.id }
            if !pendingWeekIds.isEmpty {
                let memberIds = membersResults.map { $0.id }
                let allSelections = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
                
                for var week in weeksResults where week.status == .pending {
                    let weekSelections = allSelections.filter { $0.accaId == week.id }
                    if weekSelections.isEmpty { continue }
                    
                    let allOutcomes = weekSelections.map { $0.outcome }
                    var correctStatus: WeekStatus = WeekStatus.pending
                    
                    if allOutcomes.contains(SelectionOutcome.loss) {
                        correctStatus = WeekStatus.lost
                    } else {
                        let settledOutcomes = allOutcomes.filter { $0 != SelectionOutcome.pending }
                        if !allOutcomes.isEmpty && settledOutcomes.count == membersResults.count {
                             correctStatus = WeekStatus.won 
                        }
                    }
                    
                    if correctStatus != WeekStatus.pending {
                        week.status = correctStatus
                        // 1. Save to DB
                        try? await SupabaseService.shared.updateAcca(week)
                        
                        // 2. Update UI array
                        if let idx = self.weeks.firstIndex(where: { $0.id == week.id }) {
                            let updated = week
                            await MainActor.run {
                                self.weeks[idx] = updated
                            }
                        }
                    }
                }
            }
            // ---------------------------------------------------------------------------------
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
    @Binding var weeks: [Week]
    let group: BettingGroup
    @Binding var path: NavigationPath
    var onRefresh: () async -> Void
    
    var body: some View {
        List {
            Section {
                if weeks.isEmpty {
                ContentUnavailableView("No Accumulators", systemImage: "sportscourt", description: Text("Start a new accumulator to begin tracking bets."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(weeks) { week in
                    NavigationLink(destination: WeekDetailView(week: $weeks[weeks.firstIndex(where: { $0.id == week.id })!], group: group, path: $path)) {
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
        }
        .listStyle(.insetGrouped)
        .refreshable {
            // Need a way to trigger parent refresh... adding a closure
            await onRefresh()
        }
    }
    
    private func deleteWeeks(offsets: IndexSet) {
        let weeksToRemove = offsets.map { weeks[$0] }
        
        // Optimistically update UI
        weeks.remove(atOffsets: offsets)
        
        Task {
            for week in weeksToRemove {
                do {
                    try await SupabaseService.shared.deleteAcca(id: week.id)
                } catch {
                    print("Error deleting week: \(error)")
                    // Optionally: reload data if delete fails
                }
            }
        }
    }
}

struct WeekDetailView: View {
    @Binding var week: Week
    let group: BettingGroup
    @Binding var path: NavigationPath
    @AppStorage("userName") private var userName: String = ""
    
    @State private var currentWeek: Week
    @State private var selections: [Selection] = []
    @State private var members: [Member] = []
    @State private var profiles: [UUID: Profile] = [:]
    @State private var isLoading: Bool = true
    @State private var isCreatingPick: Bool = false
    @State private var isUpdatingPayment: Bool = false
    
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    init(week: Binding<Week>, group: BettingGroup, path: Binding<NavigationPath>) {
        self._week = week
        self.group = group
        self._path = path
        self._currentWeek = State(initialValue: week.wrappedValue)
    }
    
    @State private var fetchedUserName: String? = nil
    
    // Robustly identify the current user's Member record across auth states
    private var currentUserMember: Member? {
        let currentUserId = SupabaseService.shared.currentUserId
        if let exactMatch = members.first(where: { $0.userId == currentUserId }) {
            return exactMatch
        }
        // Fallback for migrated/anonymous users using AppStorage
        if !userName.isEmpty, let nameMatch = members.first(where: { $0.name.localizedStandardContains(userName) }) {
            return nameMatch
        }
        // Final fallback: use the fetched profile username
        if let fetchedName = fetchedUserName, let fetchedMatch = members.first(where: { $0.name.localizedStandardContains(fetchedName) }) {
            return fetchedMatch
        }
        return nil
    }
    
    // Computed property for "My Selections"
    private var mySelections: [Selection] {
        guard let myMember = currentUserMember else {
            return []
        }
        return selections.filter { $0.memberId == myMember.id }
    }
    
    // Computed property for "Member Selections"
    private var memberSelections: [MemberSelectionDisplay] {
        members
            .filter { $0.id != currentUserMember?.id } // Filter out me using exact Member ID
            .map { member in
                let memberPicks = selections.filter( { $0.memberId == member.id } )
                let avatarUrl = member.userId.flatMap { profiles[$0]?.avatarUrl }
                return MemberSelectionDisplay(member: member, selections: memberPicks, avatarUrl: avatarUrl)
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
    
    // Derived overall status
    private var liveStatus: WeekStatus {
        if currentWeek.status != .pending { return currentWeek.status } // Use currentWeek
        if currentWeek.isOpen { return .pending } // Use currentWeek
        if selections.isEmpty { return .pending }
        
        let outcomes = selections.map { $0.outcome }
        if outcomes.contains(.loss) { return .lost }
        
        let settledOutcomes = outcomes.filter { $0 != .pending }
        if !outcomes.isEmpty && settledOutcomes.count == outcomes.count {
            return .won
        }
        return .pending
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Status")
                        Spacer()
                        if liveStatus == .pending {
                            if currentWeek.isOpen {
                                StatusBadge(status: .pending, label: "Open", color: Color.accentColor)
                            } else {
                                StatusBadge(status: .pending, label: "In Progress", color: .orange)
                            }
                        } else {
                            StatusBadge(status: liveStatus)
                        }
                    }
                    
                    if currentWeek.isOpen {
                        Text("Picks lock at \(currentWeek.startDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                
                if !mySelections.isEmpty && !mySelections.contains(where: { $0.teamName == "Pending" }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Payment Confirmation")
                                .font(.headline)
                            let totalStake = group.stakePerPerson * Double(mySelections.count)
                            Text("I have paid my £\(String(format: "%.2f", totalStake)) stake")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        let isPaid = mySelections.first?.isPaid ?? false
                        Button {
                            togglePaymentStatus(to: !isPaid)
                        } label: {
                            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isPaid ? .green : .gray)
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdatingPayment)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            
            // MARK: - My Pick Section
            Section("My Pick\(mySelections.count > 1 ? "s" : "")") {
                if !mySelections.isEmpty {
                    ForEach(mySelections) { selection in
                        if currentWeek.isOpen {
                            ZStack {
                                NavigationLink(destination: MatchSelectionView(selection: selection, week: currentWeek)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                SelectionRow(selection: selection, memberName: nil, avatarUrl: nil, isLocked: false)
                            }
                        } else {
                            SelectionRow(selection: selection, memberName: nil, avatarUrl: nil, isLocked: true)
                        }
                    }
                    
                    if currentWeek.isOpen, mySelections.count < (currentWeek.maxPicksPerMember ?? 1) {
                         Button {
                             createMyPick()
                         } label: {
                             Text("Add another pick")
                                 .font(.subheadline)
                                 .foregroundColor(.blue)
                         }
                    }
                } else {
                    if currentWeek.isOpen {
                        Button {
                            createMyPick()
                        } label: {
                            HStack {
                                if isCreatingPick {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                }
                                Text(isCreatingPick ? "Creating..." : "Make Your Pick")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                StatusBadge(status: .pending)
                            }
                        }
                        .disabled(isLoading || isCreatingPick || members.isEmpty)
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
                        .italic()
                } else {
                    ForEach(memberSelections, id: \.member.id) { item in
                        if !item.selections.isEmpty {
                            ForEach(item.selections) { selection in
                                SelectionRow(selection: selection, memberName: item.member.name, avatarUrl: item.avatarUrl, isLocked: !currentWeek.isOpen)
                            }
                        } else {
                            HStack(spacing: 12) {
                                ProfileImage(url: item.avatarUrl, size: 32)
                                Text(item.member.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("No Pick")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(currentWeek.title)
        .onAppear {
            self.currentWeek = week
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .alert("Error", isPresented: $showingErrorAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage)
        })
    }
    
    private func loadData() async {
        isLoading = true
        do {
            async let fetchedSelections = SupabaseService.shared.fetchSelections(weekId: currentWeek.id)
            async let fetchedMembers = SupabaseService.shared.fetchMembers(for: group.id)
            
            let s = try await fetchedSelections
            let m = try await fetchedMembers
            
            await MainActor.run {
                self.selections = s
                self.members = m
            }
            
            // Sync match results for pending selections that should be finished or live
            await syncMatchResults()
            await updateWeekStatusIfNeeded()
            
            // Fetch profiles for avatars
            let userIds = members.compactMap { $0.userId }
            let fetchedProfiles = try await SupabaseService.shared.fetchProfiles(ids: userIds)
            
            // Fetch my own profile name just in case AppStorage is totally empty
            let myProfile = try? await SupabaseService.shared.fetchProfile(id: SupabaseService.shared.currentUserId)
            
            await MainActor.run {
                var profileMap: [UUID: Profile] = [:]
                for p in fetchedProfiles {
                    profileMap[p.id] = p
                }
                self.profiles = profileMap
                self.fetchedUserName = myProfile?.username
                self.isLoading = false
            }
        } catch {
            print("Error loading data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func createMyPick() {
        isCreatingPick = true
        Task {
            do {
                if let myMember = currentUserMember {
                     let finalSelection = Selection(
                        id: UUID(),
                        accaId: currentWeek.id,
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
                    await MainActor.run {
                        errorMessage = "Could not identify your membership in this group. You may need to ask the admin to recreate your membership."
                        showingErrorAlert = true
                    }
                }
                await MainActor.run { isCreatingPick = false }
            } catch {
                print("Error creating pick: \(error)")
                await MainActor.run { 
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    isCreatingPick = false 
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
    
    private func togglePaymentStatus(to isPaid: Bool) {
        guard !mySelections.isEmpty else { return }
        isUpdatingPayment = true
        
        Task {
            do {
                for selection in mySelections {
                    var updated = selection
                    updated.isPaid = isPaid
                    try await SupabaseService.shared.saveSelection(updated)
                }
                await loadData()
                await MainActor.run { isUpdatingPayment = false }
            } catch {
                print("Error updating payment: \(error)")
                await MainActor.run { 
                    errorMessage = "Failed to update payment status."
                    showingErrorAlert = true
                    isUpdatingPayment = false 
                }
            }
        }
    }
    
    private func syncMatchResults() async {
        let now = Date()
        let selectionsToSync = selections.filter { 
            ($0.outcome == .pending && $0.kickoffTime != nil && $0.kickoffTime! < now) || 
            ($0.homeTeamName == nil || $0.awayTeamName == nil)
        }
        
        if selectionsToSync.isEmpty { return }
        
        // Group by day to minimize API calls
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: selectionsToSync.filter { $0.kickoffTime != nil }) { 
            calendar.startOfDay(for: $0.kickoffTime!) 
        }
        
        var updatedSelections: [Selection] = []
        
        for (date, dateSelections) in groupedByDate {
            do {
                let fixturesByComp = try await APIService.shared.fetchFixtures(date: date)
                var allFixtures = fixturesByComp.values.flatMap { $0 }
                
                for var selection in dateSelections {
                    let match = allFixtures.first { fixture in
                        if let fid = selection.fixtureId, let aid = fixture.apiId {
                            return fid == aid
                        }
                        // Fallback to name matching if IDs are missing (for old records)
                        return fixture.homeTeam.localizedCaseInsensitiveContains(selection.teamName) ||
                               fixture.awayTeam.localizedCaseInsensitiveContains(selection.teamName) ||
                               selection.teamName.localizedCaseInsensitiveContains(fixture.homeTeam) ||
                               selection.teamName.localizedCaseInsensitiveContains(fixture.awayTeam)
                    }
                    
                    if let fixture = match {
                        var changed = false
                        
                        // Update basic info if missing
                        if selection.homeTeamName == nil { selection.homeTeamName = fixture.homeTeam; changed = true }
                        if selection.awayTeamName == nil { selection.awayTeamName = fixture.awayTeam; changed = true }
                        if selection.fixtureId == nil { selection.fixtureId = fixture.apiId; changed = true }
                        
                        // Update scores and status
                        if selection.homeScore != fixture.homeGoals { selection.homeScore = fixture.homeGoals; changed = true }
                        if selection.awayScore != fixture.awayGoals { selection.awayScore = fixture.awayGoals; changed = true }
                        if selection.matchStatus != fixture.status { selection.matchStatus = fixture.status; changed = true }
                        
                        // Calculate outcome if finished
                        if ["FT", "AET", "PEN"].contains(fixture.status) {
                            let newOutcome = calculateOutcome(selection: selection, homeGoals: fixture.homeGoals ?? 0, awayGoals: fixture.awayGoals ?? 0)
                            if selection.outcome != newOutcome {
                                selection.outcome = newOutcome
                                changed = true
                            }
                        }
                        
                        if changed {
                            updatedSelections.append(selection)
                        }
                    }
                }
            } catch {
                print("Error syncing results for date \(date): \(error)")
            }
        }
        
        // Save updates to Supabase
        for s in updatedSelections {
            do {
                try await SupabaseService.shared.saveSelection(s)
            } catch {
                print("Error saving synced selection \(s.id): \(error)")
            }
        }
        
        if !updatedSelections.isEmpty {
            await MainActor.run {
                // Refresh local state
                for s in updatedSelections {
                    if let index = selections.firstIndex(where: { $0.id == s.id }) {
                        selections[index] = s
                    }
                }
            }
        }
    }
    
    private func updateWeekStatusIfNeeded() async {
        let allOutcomes = selections.map { $0.outcome }
        var newWeekStatus: WeekStatus = .pending
        
        if allOutcomes.contains(.loss) {
            newWeekStatus = .lost
        } else {
            let settledOutcomes = allOutcomes.filter { $0 != .pending }
            // Only mark as won if ALL members have made a pick and ALL are settled as won/void
            if !allOutcomes.isEmpty && settledOutcomes.count == members.count {
                 newWeekStatus = .won 
            }
        }
        
        if newWeekStatus != currentWeek.status {
            var updatedWeek = currentWeek
            updatedWeek.status = newWeekStatus
            
            // Save to database
            do {
                try await SupabaseService.shared.updateAcca(updatedWeek)
                
                await MainActor.run {
                    self.currentWeek = updatedWeek
                    self.week = updatedWeek // Update the binding to reflect back up to GroupWeeksView
                }
            } catch {
                print("Error updating week status: \(error)")
            }
        }
    }
    
    private func calculateOutcome(selection: Selection, homeGoals: Int, awayGoals: Int) -> SelectionOutcome {
        let name = selection.teamName
        let homeName = selection.homeTeamName ?? ""
        let awayName = selection.awayTeamName ?? ""
        
        // Draw Market
        if name == "Draw" {
            return homeGoals == awayGoals ? .win : .loss
        }
        
        // Result Market
        if name == homeName || name.contains(homeName + " Win") {
             return homeGoals > awayGoals ? .win : .loss
        } else if name == awayName || name.contains(awayName + " Win") {
             return awayGoals > homeGoals ? .win : .loss
        }
        
        // BTTS Market
        if name.contains("BTTS") {
            let bothScored = homeGoals > 0 && awayGoals > 0
            if name.contains("Yes") {
                return bothScored ? .win : .loss
            } else {
                return !bothScored ? .win : .loss
            }
        }
        
        // Total Goals
        if name.contains("Goals") {
            let total = homeGoals + awayGoals
            if name.contains("Over 2.5") {
                return total > 2 ? .win : .loss
            } else if name.contains("Under 2.5") {
                return total < 3 ? .win : .loss
            }
        }
        
        return .pending
    }
}
    

// Helper struct for display to avoid complex logic in view
struct MemberSelectionDisplay {
    let member: Member
    let selections: [Selection]
    let avatarUrl: String?
}
