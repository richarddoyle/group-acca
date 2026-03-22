import SwiftUI

struct MatchSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var badgeManager: GroupBadgeManager
    @State var selection: Selection
    let week: Week? // Pass explicitly
    let memberSelections: [MemberSelectionDisplay]
    
    @State private var selectedDate: Date = Date()
    @State private var fixtures: [Competition: [Fixture]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFixture: Fixture? // For sheet presentation
    @State private var isSearchPresented = false
    
    // Pill State
    enum ActivePill {
        case none, form, cleanSheet, btts, position, predBtts, predOver25
    }
    
    enum SortOption {
        case league, highToLow, lowToHigh
    }
    
    @State private var activePill: ActivePill = .none
    @State private var sortOption: SortOption = .league
    
    // Data State
    @State private var teamForms: [String: String] = [:]
    @State private var isFetchingForms: Bool = false
    
    @State private var teamCleanSheets: [String: Int] = [:]
    @State private var isFetchingCleanSheets: Bool = false
    
    @State private var teamBtts: [String: Int] = [:]
    @State private var isFetchingBtts: Bool = false
    
    @State private var teamPositions: [String: Int] = [:]
    @State private var isFetchingPositions: Bool = false
    
    @State private var fixtureBttsPredictions: [String: Double] = [:]
    @State private var fixtureOver25Predictions: [String: Double] = [:]
    @State private var isFetchingPredictions: Bool = false
    
    // Pick Validation State
    @State private var showDuplicateError = false
    @State private var duplicateErrorMessage = ""
    @State private var showFixtureWarning = false
    @State private var fixtureWarningMessage = ""
    @State private var pendingSelectionCache: (Fixture, String, Double, String?)?
    
    init(selection: Selection, week: Week? = nil, memberSelections: [MemberSelectionDisplay] = []) {
        self._selection = State(initialValue: selection)
        self.week = week
        self.memberSelections = memberSelections
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
    
    @ViewBuilder
    private var mainContent: some View {
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
                                    } else if activePill == .predBtts || activePill == .predOver25 {
                                        fixtureBttsPredictions.removeAll()
                                        fixtureOver25Predictions.removeAll()
                                        fetchPredictions()
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
                                activePill = activePill == .predBtts ? .none : .predBtts
                                if activePill == .predBtts && fixtureBttsPredictions.isEmpty {
                                    fetchPredictions()
                                }
                            }
                        } label: {
                            Text("BTTS Predict")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .predBtts ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .predBtts ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            withAnimation {
                                activePill = activePill == .predOver25 ? .none : .predOver25
                                if activePill == .predOver25 && fixtureOver25Predictions.isEmpty {
                                    fetchPredictions()
                                }
                            }
                        } label: {
                            Text("Over 2.5 Predict")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .predOver25 ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .predOver25 ? .white : .primary)
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
                    .padding(.bottom, 4)
                }
                .background(Color(.systemBackground))
                .zIndex(1)
                
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
                            List {
                                if activePill != .none {
                                    Section(content: {
                                        pillExplanationView
                                    }, footer: {
                                        if activePill == .position || activePill == .predBtts || activePill == .predOver25 {
                                            HStack {
                                                Spacer()
                                                Menu {
                                                    Picker("Sort By", selection: $sortOption) {
                                                        Text("League").tag(SortOption.league)
                                                        Text("High to Low").tag(SortOption.highToLow)
                                                        Text("Low to High").tag(SortOption.lowToHigh)
                                                    }
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "arrow.up.arrow.down")
                                                        Text("Sort: \(sortOptionText)")
                                                    }
                                                    .font(.caption.bold())
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(Capsule())
                                                }
                                            }
                                            .padding(.top, 4)
                                            .padding(.bottom, -8)
                                        }
                                    })
                                }
                                
                                if sortOption == .league || activePill == .none {
                                    ForEach(filteredCompetitions, id: \.self) { competition in
                                        if let compFixtures = fixtures[competition]?.filter({ $0.status == "NS" && $0.date > Date() }), !compFixtures.isEmpty {
                                            Section {
                                                ForEach(compFixtures) { fixture in
                                                    matchRow(for: fixture)
                                                }
                                            } header: {
                                                Text(competition.name)
                                            }
                                        }
                                    }
                                } else {
                                    let flattened = fixtures.values.flatMap { $0 }
                                        .filter { $0.status == "NS" && $0.date > Date() }
                                        .sorted { f1, f2 in
                                            let v1 = sortValue(for: f1)
                                            let v2 = sortValue(for: f2)
                                            return sortOption == .highToLow ? v1 > v2 : v1 < v2
                                        }
                                    Section {
                                        ForEach(flattened) { fixture in
                                            matchRow(for: fixture)
                                        }
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                            .padding(.top, -24)
                        }
                    }
                }
            }
    }
    
    @ViewBuilder
    private func matchRow(for fixture: Fixture) -> some View {
        Button {
            selectedFixture = fixture
        } label: {
            let takenInfo = checkTaken(fixture: fixture)
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
                showPositions: activePill == .position,
                matchBttsPredict: fixtureBttsPredictions[String(fixture.apiId ?? 0)],
                matchOver25Predict: fixtureOver25Predictions[String(fixture.apiId ?? 0)],
                showBttsPredict: activePill == .predBtts,
                showOver25Predict: activePill == .predOver25,
                isLoadingStats: activePill == .form ? isFetchingForms :
                                activePill == .cleanSheet ? isFetchingCleanSheets :
                                activePill == .btts ? isFetchingBtts :
                                activePill == .position ? isFetchingPositions :
                                (activePill == .predBtts || activePill == .predOver25) ? isFetchingPredictions : false,
                takenByMember: takenInfo?.name,
                takenByAvatarUrl: takenInfo?.avatarUrl,
                takenByBadgeEmoji: takenInfo != nil ? badgeManager.badges[takenInfo!.memberId] : nil
            )
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
            .navigationTitle("Select Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $isSearchPresented) {
                TeamSearchView(
                    dates: dates,
                    week: week,
                    memberSelections: memberSelections,
                    onSelect: { fixture in
                        isSearchPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedFixture = fixture
                        }
                    },
                    badgeManager: badgeManager
                )
            }
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
            .onChange(of: fixtures) { _, _ in
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
                case .predBtts, .predOver25:
                    fetchPredictions()
                case .none:
                    break
                }
            }
        }
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private func checkTaken(fixture: Fixture) -> (name: String, avatarUrl: String?, memberId: UUID)? {
        for memberSelection in memberSelections {
            if memberSelection.selections.contains(where: { 
                $0.fixtureId == fixture.apiId || 
                $0.homeTeamName == fixture.homeTeam && $0.awayTeamName == fixture.awayTeam 
            }) {
                return (memberSelection.member.name, memberSelection.avatarUrl, memberSelection.member.id)
            }
        }
        return nil
    }
    
    private func loadFixtures() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let rawFixtures = try await APIService.shared.fetchFixtures(date: selectedDate)
                
                var filteredFixtures: [Competition: [Fixture]] = [:]
                let deadline = week?.startDate ?? Date.distantPast
                for (comp, fixturesList) in rawFixtures {
                    let eligible = fixturesList.filter { $0.date > deadline }
                    if !eligible.isEmpty {
                        filteredFixtures[comp] = eligible
                    }
                }
                
                await MainActor.run {
                    self.fixtures = filteredFixtures
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
            
            let season = APIService.shared.getCurrentSeasonYear(for: selectedDate)
            
            await withTaskGroup(of: [String: String]?.self) { group in
                for comp in competitions {
                    guard let apiId = comp.apiId else { continue }
                    group.addTask {
                        do {
                            let standings = try await APIService.shared.fetchStandings(leagueId: apiId, season: season)
                            
                            var leagueForms: [String: String] = [:]
                            for row in standings {
                                leagueForms[row.teamName] = row.form.isEmpty ? "---" : row.form
                            }
                            return leagueForms
                        } catch {
                            print("Failed to fetch forms for league \(comp.name): \(error)")
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let result = result {
                        allForms.merge(result) { current, _ in current }
                    }
                }
            }
            
            await MainActor.run {
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
            
            let season = APIService.shared.getCurrentSeasonYear(for: selectedDate)
            
            await withTaskGroup(of: [String: Int]?.self) { group in
                for comp in competitions {
                    guard let apiId = comp.apiId else { continue }
                    group.addTask {
                        do {
                            let fixtures = try await APIService.shared.fetchFinishedFixtures(leagueId: apiId, season: season)
                            
                            var teamStats: [String: (played: Int, csCount: Int)] = [:]
                            
                            for fixture in fixtures {
                                if let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals {
                                    let homeCleanSheet = awayGoals == 0
                                    let awayCleanSheet = homeGoals == 0
                                    
                                    teamStats[fixture.homeTeam, default: (0, 0)].played += 1
                                    if homeCleanSheet { teamStats[fixture.homeTeam]?.csCount += 1 }
                                    
                                    teamStats[fixture.awayTeam, default: (0, 0)].played += 1
                                    if awayCleanSheet { teamStats[fixture.awayTeam]?.csCount += 1 }
                                }
                            }
                            
                            var leagueCleanSheets: [String: Int] = [:]
                            for (team, stats) in teamStats {
                                if stats.played > 0 {
                                    leagueCleanSheets[team] = Int((Double(stats.csCount) / Double(stats.played)) * 100)
                                }
                            }
                            return leagueCleanSheets
                        } catch {
                            print("Failed to fetch fixtures for Clean Sheets for league \(comp.name): \(error)")
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let result = result {
                        allCleanSheets.merge(result) { current, _ in current }
                    }
                }
            }
            
            await MainActor.run {
                self.teamCleanSheets = allCleanSheets
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
            
            let season = APIService.shared.getCurrentSeasonYear(for: selectedDate)
            
            await withTaskGroup(of: [String: Int]?.self) { group in
                for comp in competitions {
                    guard let apiId = comp.apiId else { continue }
                    group.addTask {
                        do {
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
                            
                            var leagueBtts: [String: Int] = [:]
                            for (team, stats) in teamStats {
                                if stats.played > 0 {
                                    leagueBtts[team] = Int((Double(stats.bttsCount) / Double(stats.played)) * 100)
                                }
                            }
                            return leagueBtts
                            
                        } catch {
                            print("Failed to fetch fixtures for BTTS for league \(comp.name): \(error)")
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let result = result {
                        allBtts.merge(result) { current, _ in current }
                    }
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
    
    private func fetchPredictions() {
        guard !isFetchingPredictions else { return }
        isFetchingPredictions = true
        
        Task {
            let competitions = filteredCompetitions
            let season = APIService.shared.getCurrentSeasonYear(for: selectedDate)
            
            // Goals scored / conceded for each team
            var homeData: [String: (goalsFor: Int, goalsAgainst: Int, played: Int)] = [:]
            var awayData: [String: (goalsFor: Int, goalsAgainst: Int, played: Int)] = [:]
            
            await withTaskGroup(of: [Fixture]?.self) { group in
                for comp in competitions {
                    guard let apiId = comp.apiId else { continue }
                    group.addTask {
                        do {
                            return try await APIService.shared.fetchFinishedFixtures(leagueId: apiId, season: season)
                        } catch {
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let leagueFixtures = result {
                        for f in leagueFixtures {
                            if let hg = f.homeGoals, let ag = f.awayGoals {
                                // Home team stats
                                homeData[f.homeTeam, default: (0, 0, 0)].goalsFor += hg
                                homeData[f.homeTeam, default: (0, 0, 0)].goalsAgainst += ag
                                homeData[f.homeTeam, default: (0, 0, 0)].played += 1
                                
                                // Away team stats
                                awayData[f.awayTeam, default: (0, 0, 0)].goalsFor += ag
                                awayData[f.awayTeam, default: (0, 0, 0)].goalsAgainst += hg
                                awayData[f.awayTeam, default: (0, 0, 0)].played += 1
                            }
                        }
                    }
                }
            }
            
            var bttsResults: [String: Double] = [:]
            var over25Results: [String: Double] = [:]
            
            let allCurrentFixtures = fixtures.values.flatMap { $0 }
            
            for fixture in allCurrentFixtures {
                guard let id = fixture.apiId else { continue }
                
                let hStats = homeData[fixture.homeTeam] ?? (0, 0, 0)
                let aStats = awayData[fixture.awayTeam] ?? (0, 0, 0)
                
                guard hStats.played > 0, aStats.played > 0 else { continue }
                
                let homeAvgScored = Double(hStats.goalsFor) / Double(hStats.played)
                let homeAvgConceded = Double(hStats.goalsAgainst) / Double(hStats.played)
                
                let awayAvgScored = Double(aStats.goalsFor) / Double(aStats.played)
                let awayAvgConceded = Double(aStats.goalsAgainst) / Double(aStats.played)
                
                let xgHome = (homeAvgScored + awayAvgConceded) / 2.0
                let xgAway = (awayAvgScored + homeAvgConceded) / 2.0
                
                // BTTS 
                let pBtts = (1.0 - exp(-xgHome)) * (1.0 - exp(-xgAway))
                bttsResults[String(id)] = pBtts
                
                // Over 2.5
                let lambdaTotal = xgHome + xgAway
                let pUnder2_5 = exp(-lambdaTotal) * (1.0 + lambdaTotal + (pow(lambdaTotal, 2) / 2.0))
                let pOver2_5 = 1.0 - pUnder2_5
                
                over25Results[String(id)] = pOver2_5
            }
            
            await MainActor.run {
                self.fixtureBttsPredictions = bttsResults
                self.fixtureOver25Predictions = over25Results
                self.isFetchingPredictions = false
            }
        }
    }
    
    private func fetchPositions() {
        guard !isFetchingPositions else { return }
        isFetchingPositions = true
        
        Task {
            let competitions = filteredCompetitions
            var allPositions: [String: Int] = [:]
            
            let season = APIService.shared.getCurrentSeasonYear(for: selectedDate)
            
            await withTaskGroup(of: [String: Int]?.self) { group in
                for comp in competitions {
                    guard let apiId = comp.apiId else { continue }
                    group.addTask {
                        do {
                            let standings = try await APIService.shared.fetchStandings(leagueId: apiId, season: season)
                            
                            var leaguePositions: [String: Int] = [:]
                            for row in standings {
                                leaguePositions[row.teamName] = row.rank
                            }
                            return leaguePositions
                        } catch {
                            print("Failed to fetch positions for league \(comp.name): \(error)")
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let result = result {
                        allPositions.merge(result) { current, _ in current }
                    }
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
                if otherMembersPicks.contains(where: { $0.fixtureId == fixture.apiId && $0.teamName == team }) {
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
        let explanationText: String? = {
            switch activePill {
            case .none: return nil
            case .form: return "Form is based on the team's last 5 league matches."
            case .cleanSheet: return "Percentage of league matches where the team conceded 0 goals."
            case .btts: return "Percentage of league matches where BOTH teams scored at least 1 goal."
            case .position: return "The team's current position in their league standings."
            case .predBtts: return "Calculated probability that BOTH teams will score based on historic goals."
            case .predOver25: return "Calculated probability that the match will have over 2.5 total goals."
            }
        }()

        if let text = explanationText {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.body)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var sortOptionText: String {
        switch sortOption {
        case .league: return "League"
        case .highToLow: return "High-Low"
        case .lowToHigh: return "Low-High"
        }
    }
    
    private func sortValue(for fixture: Fixture) -> Double {
        switch activePill {
        case .form:
            let hForms = teamForms[fixture.homeTeam]
            let aForms = teamForms[fixture.awayTeam]
            return Double(pointsForForm(hForms) + pointsForForm(aForms))
        case .cleanSheet:
            let h = teamCleanSheets[fixture.homeTeam] ?? 0
            let a = teamCleanSheets[fixture.awayTeam] ?? 0
            return Double(h + a) / 2.0
        case .btts:
            let h = teamBtts[fixture.homeTeam] ?? 0
            let a = teamBtts[fixture.awayTeam] ?? 0
            return Double(h + a) / 2.0
        case .position:
            let h = teamPositions[fixture.homeTeam] ?? 99
            let a = teamPositions[fixture.awayTeam] ?? 99
            return Double(abs(h - a))
        case .predBtts:
            return fixtureBttsPredictions[String(fixture.apiId ?? 0)] ?? 0.0
        case .predOver25:
            return fixtureOver25Predictions[String(fixture.apiId ?? 0)] ?? 0.0
        case .none:
            return 0.0
        }
    }
    
    private func pointsForForm(_ form: String?) -> Int {
        guard let form = form else { return 0 }
        return form.reduce(0) { sum, char in
            if char == "W" { return sum + 3 }
            if char == "D" { return sum + 1 }
            return sum
        }
    }
}
