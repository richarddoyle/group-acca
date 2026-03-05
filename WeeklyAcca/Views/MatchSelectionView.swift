import SwiftUI

struct MatchSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var selection: Selection
    let week: Week? // Pass explicitly
    
    @State private var selectedDate: Date = Date()
    @State private var fixtures: [Competition: [Fixture]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFixture: Fixture? // For sheet presentation
    
    // Pill State
    enum ActivePill {
        case none, form, cleanSheet, btts, position
    }
    @State private var activePill: ActivePill = .none
    
    // Data State
    @State private var teamForms: [String: String] = [:]
    @State private var isFetchingForms: Bool = false
    
    @State private var teamCleanSheets: [String: Int] = [:]
    @State private var isFetchingCleanSheets: Bool = false
    
    @State private var teamBtts: [String: Int] = [:]
    @State private var isFetchingBtts: Bool = false
    
    @State private var teamPositions: [String: Int] = [:]
    @State private var isFetchingPositions: Bool = false
    
    // Pick Validation State
    @State private var showDuplicateError = false
    @State private var duplicateErrorMessage = ""
    @State private var showFixtureWarning = false
    @State private var fixtureWarningMessage = ""
    @State private var pendingSelectionCache: (Fixture, String, Double, String?)?
    
    init(selection: Selection, week: Week? = nil) {
        self._selection = State(initialValue: selection)
        self.week = week
    }
    
    // Generate dates based on Week constraints
    private var dates: [Date] {
        guard let week = week else {
            return generateNext7Days()
        }
        
        let calendar = Calendar.current
        var dates: [Date] = []
        
        // Start from the week's start date
        var currentDate = calendar.startOfDay(for: week.startDate)
        let endDate = calendar.startOfDay(for: week.endDate)
        
        // Safety Break: Limit to 30 days max to prevent infinite loops if dates are bad
        var count = 0
        while currentDate <= endDate && count < 30 {
            dates.append(currentDate)
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
            count += 1
        }
        
        return dates.isEmpty ? generateNext7Days() : dates
    }
    
    private func generateNext7Days() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var days: [Date] = []
        for i in 0...6 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                days.append(date)
            }
        }
        return days
    }
    
    // Filtered Content
    private var filteredCompetitions: [Competition] {
        let order = LeagueConstants.supportedLeagues.enumerated().reduce(into: [Int: Int]()) { result, item in
            result[item.element.id] = item.offset
        }
        
        return fixtures.keys.filter { isCompetitionAllowed($0) }.sorted(by: {
            let id1 = $0.apiId ?? Int.max
            let id2 = $1.apiId ?? Int.max
            let order1 = order[id1] ?? Int.max
            let order2 = order[id2] ?? Int.max
            return order1 < order2
        })
    }
    
    private var filteredFixtures: [Competition: [Fixture]] {
        fixtures.filter { isCompetitionAllowed($0.key) }
    }
    
    private func isCompetitionAllowed(_ competition: Competition) -> Bool {
        guard let allowedLeagues = week?.selectedLeagues, !allowedLeagues.isEmpty else {
            return true
        }
        
        // 1. Resolve allowed IDs from the user's selection
        let allowedIDs = allowedLeagues.compactMap { LeagueConstants.getID(for: $0) }
        
        // 2. If the fixture has a known API ID, STRICTLY check against allowed IDs
        if let apiId = competition.apiId {
            if !allowedIDs.isEmpty {
                return allowedIDs.contains(apiId)
            }
        }
        
        // 3. Fallback to name matching
        return allowedLeagues.contains { allowed in
            competition.name.localizedCaseInsensitiveContains(allowed) ||
            allowed.localizedCaseInsensitiveContains(competition.name)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            DateTabButton(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate)) {
                                withAnimation {
                                    selectedDate = date
                                    loadFixtures()
                                    // Reset pill toggle when changing dates, or fetch immediately if pill is active
                                    if activePill == .form {
                                        teamForms.removeAll()
                                        fetchForms()
                                    } else if activePill == .cleanSheet {
                                        teamCleanSheets.removeAll()
                                        fetchCleanSheets()
                                    } else if activePill == .btts {
                                        teamBtts.removeAll()
                                        fetchBtts()
                                    } else if activePill == .position {
                                        teamPositions.removeAll()
                                        fetchPositions()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Form Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                activePill = activePill == .form ? .none : .form
                                if activePill == .form && teamForms.isEmpty {
                                    fetchForms()
                                }
                            }
                        } label: {
                            Text("Form")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .form ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .form ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            withAnimation {
                                activePill = activePill == .position ? .none : .position
                                if activePill == .position && teamPositions.isEmpty {
                                    fetchPositions()
                                }
                            }
                        } label: {
                            Text("League Position")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .position ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .position ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            withAnimation {
                                activePill = activePill == .cleanSheet ? .none : .cleanSheet
                                if activePill == .cleanSheet && teamCleanSheets.isEmpty {
                                    fetchCleanSheets()
                                }
                            }
                        } label: {
                            Text("Clean Sheet %")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .cleanSheet ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .cleanSheet ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            withAnimation {
                                activePill = activePill == .btts ? .none : .btts
                                if activePill == .btts && teamBtts.isEmpty {
                                    fetchBtts()
                                }
                            }
                        } label: {
                            Text("BTTS %")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .btts ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .btts ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Fixtures List
                Group {
                    if isLoading {
                        ProgressView("Loading fixtures...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 20) {
                            ContentUnavailableView("Selection Error", systemImage: "exclamationmark.triangle", description: Text(error))
                            Button("Try Again") {
                                errorMessage = nil
                                loadFixtures()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if filteredFixtures.isEmpty {
                        ContentUnavailableView("No Fixtures", systemImage: "soccerball", description: Text("No matches found for this date in your selected leagues."))
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if activePill != .none {
                                pillExplanationView
                                    .padding(.bottom, 8)
                            }
                            
                            List {
                            ForEach(filteredCompetitions, id: \.self) { competition in
                                if let compFixtures = fixtures[competition]?.filter({ $0.status == "NS" && $0.date > Date() }), !compFixtures.isEmpty {
                                    Section {
                                        ForEach(compFixtures) { fixture in
                                            Button {
                                                selectedFixture = fixture
                                            } label: {
                                                MatchRowView(
                                                    fixture: fixture,
                                                    homeForm: teamForms[fixture.homeTeam],
                                                    awayForm: teamForms[fixture.awayTeam],
                                                    showForm: activePill == .form,
                                                    homeCleanSheet: teamCleanSheets[fixture.homeTeam],
                                                    awayCleanSheet: teamCleanSheets[fixture.awayTeam],
                                                    showCleanSheets: activePill == .cleanSheet,
                                                    homeBtts: teamBtts[fixture.homeTeam],
                                                    awayBtts: teamBtts[fixture.awayTeam],
                                                    showBtts: activePill == .btts,
                                                    homePosition: teamPositions[fixture.homeTeam],
                                                    awayPosition: teamPositions[fixture.awayTeam],
                                                    showPositions: activePill == .position
                                                )
                                                    .padding(.vertical, 4)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    } header: {
                                        Text(competition.name)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        }
                    }
                }
            }
            .navigationTitle("Select Match")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedFixture) { fixture in
                MarketSelectionView(fixture: fixture) { team, odds, logo in
                    selectMatch(fixture: fixture, team: team, odds: odds, logo: logo)
                }
            }
            .alert("Duplicate Pick", isPresented: $showDuplicateError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(duplicateErrorMessage)
            }
            .alert("Same Match Picked", isPresented: $showFixtureWarning) {
                Button("Cancel", role: .cancel) {
                    pendingSelectionCache = nil
                }
                Button("Continue") {
                    if let cache = pendingSelectionCache {
                        confirmSelection(fixture: cache.0, team: cache.1, odds: cache.2, logo: cache.3)
                    }
                }
            } message: {
                Text(fixtureWarningMessage)
            }
            .onAppear {
                // Ensure selectedDate is within range
                if let week = week {
                    let start = calendar.startOfDay(for: week.startDate)
                    let end = calendar.startOfDay(for: week.endDate)
                    let current = calendar.startOfDay(for: selectedDate)
                    
                    if current < start || current > end {
                        selectedDate = start
                    }
                }
                loadFixtures()
            }
            .onChange(of: fixtures) { _ in
                // Re-fetch stats for the new fixtures if a pill is currently active
                switch activePill {
                case .form:
                    fetchForms()
                case .cleanSheet:
                    fetchCleanSheets()
                case .btts:
                    fetchBtts()
                case .position:
                    fetchPositions()
                case .none:
                    break
                }
            }
        }
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private func loadFixtures() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let newFixtures = try await APIService.shared.fetchFixtures(date: selectedDate)
                await MainActor.run {
                    self.fixtures = newFixtures
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    private func fetchForms() {
        guard !isFetchingForms else { return }
        isFetchingForms = true
        
        Task {
            let competitions = filteredCompetitions
            var allForms: [String: String] = [:]
            
            for comp in competitions {
                guard let apiId = comp.apiId else { continue }
                do {
                    let season = getCurrentSeasonYear(for: selectedDate)
                    let standings = try await APIService.shared.fetchStandings(leagueId: apiId, season: season)
                    
                    for row in standings {
                        if !row.form.isEmpty {
                            allForms[row.teamName] = row.form
                        }
                    }
                } catch {
                    print("Failed to fetch forms for league \(comp.name): \(error)")
                }
            }
            
            await MainActor.run {
                // Merge into existing dictionary to keep previous fetches if applicable
                for (team, form) in allForms {
                    self.teamForms[team] = form
                }
                self.isFetchingForms = false
            }
        }
    }
    
    private func fetchCleanSheets() {
        guard !isFetchingCleanSheets else { return }
        isFetchingCleanSheets = true
        
        Task {
            let competitions = filteredCompetitions
            var allCleanSheets: [String: Int] = [:]
            
            for comp in competitions {
                guard let apiId = comp.apiId else { continue }
                do {
                    let season = getCurrentSeasonYear(for: selectedDate)
                    let fixtures = try await APIService.shared.fetchFinishedFixtures(leagueId: apiId, season: season)
                    
                    var teamStats: [String: (played: Int, cleanSheets: Int)] = [:]
                    
                    // Aggregate stats for each team
                    for fixture in fixtures {
                        // Home team stats
                        if let awayGoals = fixture.awayGoals {
                            teamStats[fixture.homeTeam, default: (0, 0)].played += 1
                            if awayGoals == 0 {
                                teamStats[fixture.homeTeam]?.cleanSheets += 1
                            }
                        }
                        
                        // Away team stats
                        if let homeGoals = fixture.homeGoals {
                            teamStats[fixture.awayTeam, default: (0, 0)].played += 1
                            if homeGoals == 0 {
                                teamStats[fixture.awayTeam]?.cleanSheets += 1
                            }
                        }
                    }
                    
                    // Calculate percentage
                    for (team, stats) in teamStats {
                        if stats.played > 0 {
                            let percentage = Int((Double(stats.cleanSheets) / Double(stats.played)) * 100)
                            allCleanSheets[team] = percentage
                        }
                    }
                    
                } catch {
                    print("Failed to fetch fixtures for clean sheets for league \(comp.name): \(error)")
                }
            }
            
            await MainActor.run {
                for (team, cleanSheetPercentage) in allCleanSheets {
                    self.teamCleanSheets[team] = cleanSheetPercentage
                }
                self.isFetchingCleanSheets = false
            }
        }
    }

    private func fetchBtts() {
        guard !isFetchingBtts else { return }
        isFetchingBtts = true
        
        Task {
            let competitions = filteredCompetitions
            var allBtts: [String: Int] = [:]
            
            for comp in competitions {
                guard let apiId = comp.apiId else { continue }
                do {
                    let season = getCurrentSeasonYear(for: selectedDate)
                    let fixtures = try await APIService.shared.fetchFinishedFixtures(leagueId: apiId, season: season)
                    
                    var teamStats: [String: (played: Int, bttsCount: Int)] = [:]
                    
                    for fixture in fixtures {
                        if let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals {
                            let isBtts = homeGoals > 0 && awayGoals > 0
                            
                            teamStats[fixture.homeTeam, default: (0, 0)].played += 1
                            if isBtts { teamStats[fixture.homeTeam]?.bttsCount += 1 }
                            
                            teamStats[fixture.awayTeam, default: (0, 0)].played += 1
                            if isBtts { teamStats[fixture.awayTeam]?.bttsCount += 1 }
                        }
                    }
                    
                    for (team, stats) in teamStats {
                        if stats.played > 0 {
                            let percentage = Int((Double(stats.bttsCount) / Double(stats.played)) * 100)
                            allBtts[team] = percentage
                        }
                    }
                    
                } catch {
                    print("Failed to fetch fixtures for BTTS for league \(comp.name): \(error)")
                }
            }
            
            await MainActor.run {
                for (team, bttsPercentage) in allBtts {
                    self.teamBtts[team] = bttsPercentage
                }
                self.isFetchingBtts = false
            }
        }
    }
    
    private func fetchPositions() {
        guard !isFetchingPositions else { return }
        isFetchingPositions = true
        
        Task {
            let competitions = filteredCompetitions
            var allPositions: [String: Int] = [:]
            
            for comp in competitions {
                guard let apiId = comp.apiId else { continue }
                do {
                    let season = getCurrentSeasonYear(for: selectedDate)
                    let standings = try await APIService.shared.fetchStandings(leagueId: apiId, season: season)
                    
                    for row in standings {
                        allPositions[row.teamName] = row.rank
                    }
                } catch {
                    print("Failed to fetch positions for league \(comp.name): \(error)")
                }
            }
            
            await MainActor.run {
                for (team, rank) in allPositions {
                    self.teamPositions[team] = rank
                }
                self.isFetchingPositions = false
            }
        }
    }
    
    private func getCurrentSeasonYear(for targetDate: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: targetDate)
        let month = calendar.component(.month, from: targetDate)
        return month < 8 ? year - 1 : year
    }
    
    private func selectMatch(fixture: Fixture, team: String, odds: Double, logo: String?) {
        let weekId = selection.accaId
        
        isLoading = true
        Task {
            do {
                // Fetch existing picks for this week
                let allSelections = try await SupabaseService.shared.fetchSelections(weekId: weekId)
                
                // Filter to picks made by *other* members
                let otherMembersPicks = allSelections.filter { $0.memberId != selection.memberId }
                
                // 1. Check for Exact Duplicate
                if let duplicate = otherMembersPicks.first(where: { $0.fixtureId == fixture.apiId && $0.teamName == team }) {
                    await MainActor.run {
                        isLoading = false
                        duplicateErrorMessage = "Another member has already selected \(team) for this match. Please make a different pick."
                        showDuplicateError = true
                    }
                    return
                }
                
                // 2. Check for Same Fixture Warning
                if let sameFixturePick = otherMembersPicks.first(where: { $0.fixtureId == fixture.apiId }) {
                    await MainActor.run {
                        isLoading = false
                        let home = sameFixturePick.homeTeamName ?? "Home"
                        let away = sameFixturePick.awayTeamName ?? "Away"
                        fixtureWarningMessage = "Another member has already chosen a pick from this match (\(home) vs \(away)). Are you sure you want to proceed?"
                        pendingSelectionCache = (fixture, team, odds, logo)
                        showFixtureWarning = true
                    }
                    return
                }
                
                // If safe, save immediately
                await MainActor.run {
                    confirmSelection(fixture: fixture, team: team, odds: odds, logo: logo)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to validate selection. \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func confirmSelection(fixture: Fixture, team: String, odds: Double, logo: String?) {
        isLoading = true
        
        Task {
            do {
                // Update local selection object
                selection.teamName = team
                selection.league = fixture.competition.name
                selection.odds = odds
                selection.outcome = .pending
                selection.kickoffTime = fixture.date
                selection.matchStatus = "NS" // Not Started default
                selection.teamLogoUrl = logo
                selection.homeScore = nil
                selection.homeTeamName = fixture.homeTeam
                selection.awayTeamName = fixture.awayTeam
                selection.fixtureId = fixture.apiId
                selection.homeTeamLogoUrl = fixture.homeLogoUrl
                selection.awayTeamLogoUrl = fixture.awayLogoUrl
                
                // Save to Supabase
                try await SupabaseService.shared.saveSelection(selection)
                
                await MainActor.run {
                    isLoading = false
                    pendingSelectionCache = nil
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Error saving selection: \(error)")
                    errorMessage = "Failed to save selection. \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Subview for Date Tab
struct DateTabButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE" // Mon, Tue
        return f
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "d MMM" // 15 Feb
        return f
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date).uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Text(Calendar.current.component(.day, from: date).description)
                    .font(.title3)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .frame(width: 50, height: 60)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// Subview for Fixture Card
struct FixtureCard: View {
    let fixture: Fixture
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(fixture.timeString)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 12) {
                    // Home
                    VStack(spacing: 8) {
                        ClubBadge(url: fixture.homeLogoUrl, size: 44)
                        Text(fixture.homeTeam)
                            .font(.subheadline.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // VS
                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 14, weight: .black))
                            .italic()
                            .foregroundStyle(.blue.opacity(0.8))
                        
                        // Small divider lines
                        Rectangle().fill(.blue.opacity(0.2)).frame(width: 20, height: 1)
                    }
                    .frame(width: 40)
                    
                    // Away
                    VStack(spacing: 8) {
                        ClubBadge(url: fixture.awayLogoUrl, size: 44)
                        Text(fixture.awayTeam)
                            .font(.subheadline.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subviews
extension MatchSelectionView {
    @ViewBuilder
    private var pillExplanationView: some View {
        switch activePill {
        case .none:
            EmptyView()
        case .form:
            Text("Form is based on the result of the team's last 5 league matches.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
        case .cleanSheet:
            Text("Percentage of league matches where the team conceded 0 goals.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
        case .btts:
            Text("Percentage of league matches where BOTH teams scored at least 1 goal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
        case .position:
            Text("The team's current position in their league standings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
}
