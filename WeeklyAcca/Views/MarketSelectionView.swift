import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MarketSelectionView: View {
    let fixture: Fixture
    let onSelect: (String, Double, String?) -> Void
    var isReadOnly: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTopTab: TopTab
    @State private var matchEvents: [MatchEvent] = []
    @State private var lineups: [TeamLineup] = []
    @State private var standings: [LeagueStandingRow] = []
    @State private var homeStats: TeamStatistics?
    @State private var awayStats: TeamStatistics?
    
    @State private var homeBttsPercentage: Double?
    @State private var awayBttsPercentage: Double?
    
    @State private var recentHomeFixtures: [Fixture] = []
    @State private var recentAwayFixtures: [Fixture] = []
    @State private var isLoadingStats = true
    
    @State private var scrollOffset: CGFloat = 0
    
    // Dynamically generated based on read-only state and match status
    private var tabs: [TopTab] {
        var availableTabs: [TopTab] = []
        if !isReadOnly {
            availableTabs.append(.picks)
        }
        
        let isFutureMatch = (fixture.status == "NS" || fixture.status == "TBD")
        
        if !isFutureMatch {
            availableTabs.append(.details)
        }
        
        availableTabs.append(.table)
        
        if !isFutureMatch {
            availableTabs.append(.lineups)
        }
        
        availableTabs.append(.stats)
        
        return availableTabs
    }
    
    enum TopTab: String, CaseIterable, Equatable {
        case picks = "Picks"
        case details = "Game Details"
        case table = "Table"
        case lineups = "Lineup"
        case stats = "Pick Stats"
    }
    
    init(fixture: Fixture, onSelect: @escaping (String, Double, String?) -> Void, isReadOnly: Bool = false) {
        self.fixture = fixture
        self.onSelect = onSelect
        self.isReadOnly = isReadOnly
        
        let isFutureMatch = (fixture.status == "NS" || fixture.status == "TBD")
        let defaultTab: TopTab
        if !isReadOnly {
            defaultTab = .picks
        } else if !isFutureMatch {
            defaultTab = .details
        } else {
            defaultTab = .stats
        }
        
        _selectedTopTab = State(initialValue: defaultTab)
    }
    
    private let glassBackground = Color.black.opacity(0.05)
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                headerView
                
                // Top Level Tabs (Scrollable)
                topTabBar
                
                // Content Area
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTopTab {
                        case .picks:
                            allMarketsContent
                        case .details:
                            gameDetailsTab
                        case .table:
                            tableTab
                        case .lineups:
                            lineupTab
                        case .stats:
                            pickStatsTab
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    self.scrollOffset = value
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar) // Hide tab bar if presented here
        .task {
            await loadMatchData()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(glassBackground, in: Circle())
                }
                
                Spacer()
                
                Text(fixture.competition.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Placeholder to balance the back button
                Circle().fill(.clear).frame(width: 44, height: 44)
            }
            .padding(.horizontal)
            
            // Match Header (Animates on Scroll)
            let progress = min(1.0, max(0.0, -scrollOffset / 40.0))
            
            HStack(spacing: 16 - (4 * progress)) {
                teamHeader(name: fixture.homeTeam, logo: fixture.homeLogoUrl, alignment: .trailing, progress: progress)
                
                VStack(spacing: 4) {
                    if fixture.status == "NS" || fixture.status == "TBD" {
                        Text(fixture.timeString)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .opacity(1.0 - progress)
                            .frame(height: 15 * (1.0 - progress))
                            .clipped()
                        
                        Text("VS")
                            .font(.system(size: 22 - (6 * progress), weight: .bold))
                            .italic()
                            .foregroundStyle(Color.accentColor)
                    } else {
                        // Match has started or finished
                        Text(fixture.status)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(fixture.status == "FT" ? Color.gray : Color.red, in: Capsule())
                        
                        Text("\(fixture.homeGoals ?? 0) - \(fixture.awayGoals ?? 0)")
                            .font(.system(size: 22 - (6 * progress), weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 80 - (20 * progress))
                
                teamHeader(name: fixture.awayTeam, logo: fixture.awayLogoUrl, alignment: .leading, progress: progress)
            }
            .padding(.horizontal)
            .padding(.bottom, 10 - (6 * progress))
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
    }
    
    private func teamHeader(name: String, logo: String?, alignment: HorizontalAlignment, progress: Double) -> some View {
        VStack(spacing: 12 * (1.0 - progress)) {
            ClubBadge(url: logo, size: 64 - (32 * progress))
                .shadow(color: .black.opacity(0.1), radius: 8 * (1.0 - progress), y: 4 * (1.0 - progress))
            
            Text(name)
                .font(.subheadline)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .lineLimit(2)
                .opacity(1.0 - progress)
                .frame(height: 35 * (1.0 - progress))
                .clipped()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var topTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedTopTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.headline)
                                .foregroundColor(selectedTopTab == tab ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTopTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
    }
    
    @ViewBuilder
    private var allMarketsContent: some View {
        marketSection(title: "Match Result") {
            resultMarket
        }
        
        marketSection(title: "Both Teams To Score") {
            bttsMarket
        }
        
        marketSection(title: "Total Goals") {
            totalGoalsMarket
        }
    }
    
    // MARK: - New Tab Views
    
    @ViewBuilder
    private var gameDetailsTab: some View {
        if matchEvents.isEmpty {
            Text("No match events available.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(matchEvents) { event in
                    HStack(spacing: 12) {
                        Text("\(event.elapsed)'")
                            .font(.subheadline.bold())
                            .frame(width: 35, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        
                        // Icon based on type
                        Group {
                            if event.type == "Goal" {
                                Image(systemName: "soccerball")
                            } else if event.type == "Card" {
                                Image(systemName: "lanyardcard.fill")
                                    .foregroundStyle(event.detail.contains("Yellow") ? .yellow : .red)
                            } else if event.type == "subst" {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "flag.fill")
                            }
                        }
                        .frame(width: 20)
                        
                        VStack(alignment: .leading) {
                            Text(event.playerName)
                                .font(.subheadline.bold())
                            if let assist = event.assistName {
                                Text("Assist: \(assist)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if event.type == "subst" {
                                Text(event.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(event.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(event.teamName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    @ViewBuilder
    private var tableTab: some View {
        if standings.isEmpty {
            Text("Standings not available.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("#").frame(width: 30, alignment: .leading)
                    Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                    Text("P").frame(width: 30)
                    Text("GD").frame(width: 30)
                    Text("Pts").frame(width: 35, alignment: .trailing)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                
                Divider()
                
                // Rows
                ForEach(standings) { row(for: $0) }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func row(for standing: LeagueStandingRow) -> some View {
        let isHome = standing.teamName == fixture.homeTeam
        let isAway = standing.teamName == fixture.awayTeam
        let isHighlight = isHome || isAway
        
        return HStack {
            Text("\(standing.rank)")
                .frame(width: 30, alignment: .leading)
                .font(.subheadline)
            
            HStack {
                if let url = standing.teamLogo {
                    CachedImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "shield").foregroundStyle(.secondary)
                    }
                    .frame(width: 20, height: 20)
                }
                Text(standing.teamName)
                    .font(.subheadline)
                    .fontWeight(isHighlight ? .bold : .regular)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(standing.played)").frame(width: 30).font(.subheadline)
            Text("\(standing.goalDifference)").frame(width: 30).font(.subheadline)
            Text("\(standing.points)").frame(width: 35, alignment: .trailing).font(.subheadline.bold())
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
        .background(isHighlight ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(isHighlight ? 8 : 0)
    }
    
    @ViewBuilder
    private var lineupTab: some View {
        if lineups.isEmpty {
            Text("Lineups not available.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            HStack(alignment: .top, spacing: 16) {
                if let homeLineup = lineups.first(where: { $0.teamName == fixture.homeTeam }) {
                    lineupColumn(for: homeLineup)
                }
                
                Divider()
                
                if let awayLineup = lineups.first(where: { $0.teamName == fixture.awayTeam }) {
                    lineupColumn(for: awayLineup)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func lineupColumn(for lineup: TeamLineup) -> some View {
        VStack(spacing: 12) {
            Text(lineup.teamName)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(lineup.formation)
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            
            Divider()
            
            Text("Starting XI")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            ForEach(lineup.startingXI, id: \.name) { player in
                HStack {
                    Text("\(player.number)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(player.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(player.pos)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
            }
            
            Divider()
            Text("Substitutes")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            ForEach(lineup.subs, id: \.name) { player in
                HStack {
                    Text("\(player.number)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(player.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var pickStatsTab: some View {
        if isLoadingStats {
            ProgressView("Loading Stats...")
                .padding()
        } else if let home = homeStats, let away = awayStats {
            VStack(spacing: 24) {
                // Recent Form
                marketSection(title: "Recent Form") {
                    HStack(spacing: 16) {
                        TeamFormView(
                            teamName: fixture.homeTeam,
                            recentFixtures: recentHomeFixtures,
                            isHome: true
                        )
                        
                        Text("-")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TeamFormView(
                            teamName: fixture.awayTeam,
                            recentFixtures: recentAwayFixtures,
                            isHome: false
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                // Clean Sheets
                marketSection(title: "Clean Sheets") {
                    statRowWithLogos(
                        homeVal: "\(Int(home.cleanSheetPercentage * 100))%",
                        awayVal: "\(Int(away.cleanSheetPercentage * 100))%"
                    )
                }
                
                // Failed To Score
                marketSection(title: "Failed To Score") {
                    statRowWithLogos(
                        homeVal: "\(Int(home.failedToScorePercentage * 100))%",
                        awayVal: "\(Int(away.failedToScorePercentage * 100))%"
                    )
                }
                
                // Both Teams To Score
                marketSection(title: "Both Teams To Score") {
                    statRowWithLogos(
                        homeVal: homeBttsPercentage != nil ? "\(Int(homeBttsPercentage! * 100))%" : "--%",
                        awayVal: awayBttsPercentage != nil ? "\(Int(awayBttsPercentage! * 100))%" : "--%"
                    )
                }
            }
            .padding(.top, 8)
        } else {
            Text("Team statistics not available.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }
    
    private func statRowWithLogos(homeVal: String, awayVal: String) -> some View {
        HStack(spacing: 16) {
            ClubBadge(url: fixture.homeLogoUrl, size: 24)
            
            Text(homeVal)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text("-")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(awayVal)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ClubBadge(url: fixture.awayLogoUrl, size: 24)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Data Fetching
    
    private func loadMatchData() async {
        do {
            guard let fixtureId = fixture.apiId else {
                await MainActor.run { self.isLoadingStats = false }
                return
            }
            
            // Fetch events and lineups
            async let eventsTask = APIService.shared.fetchMatchEvents(fixtureId: fixtureId)
            async let lineupsTask = APIService.shared.fetchLineups(fixtureId: fixtureId)
            
            let (fetchedEvents, fetchedLineups) = try await (eventsTask, lineupsTask)
            
            // For standings/stats we need the league id and season
            // If the match is not listed with a league ID in constants, we might have to infer or just fetch from fixtures
            // But we have `competition.apiId` in Fixture
            
            // Using current year as rough season fallback for now, ideally `Fixture` has season
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date())
            let season = calendar.component(.month, from: Date()) < 8 ? year - 1 : year
            
            var fetchedStandings: [LeagueStandingRow] = []
            var fetchedHomeStats: TeamStatistics? = nil
            var fetchedAwayStats: TeamStatistics? = nil
            var fetchedHomeFixtures: [Fixture] = []
            var fetchedAwayFixtures: [Fixture] = []
            var fetchedHomeBtts: Double? = nil
            var fetchedAwayBtts: Double? = nil
            
            if let leagueId = fixture.competition.apiId {
                // Try fetch standings
                if let st = try? await APIService.shared.fetchStandings(leagueId: leagueId, season: season) {
                    fetchedStandings = st
                }
                
                // Fetch team stats and recent fixtures
                let homeIdFromLineup = fetchedLineups.first(where: { $0.teamName == fixture.homeTeam })?.teamId
                let awayIdFromLineup = fetchedLineups.first(where: { $0.teamName == fixture.awayTeam })?.teamId
                
                let homeIdFromLogo = Int(fixture.homeLogoUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: ".png", with: "") ?? "")
                let awayIdFromLogo = Int(fixture.awayLogoUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: ".png", with: "") ?? "")
                
                if let homeTeamId = homeIdFromLineup ?? homeIdFromLogo,
                   let awayTeamId = awayIdFromLineup ?? awayIdFromLogo {
                    
                    async let homeStatsTask = APIService.shared.fetchTeamStatistics(leagueId: leagueId, season: season, teamId: homeTeamId)
                    async let awayStatsTask = APIService.shared.fetchTeamStatistics(leagueId: leagueId, season: season, teamId: awayTeamId)
                    async let homeRecentTask = APIService.shared.fetchTeamRecentFixtures(teamId: homeTeamId)
                    async let awayRecentTask = APIService.shared.fetchTeamRecentFixtures(teamId: awayTeamId)
                    async let fullLeagueTask = APIService.shared.fetchFinishedFixtures(leagueId: leagueId, season: season)
                    
                    if let home = try? await homeStatsTask { fetchedHomeStats = home }
                    if let away = try? await awayStatsTask { fetchedAwayStats = away }
                    if let homeF = try? await homeRecentTask { fetchedHomeFixtures = homeF }
                    if let awayF = try? await awayRecentTask { fetchedAwayFixtures = awayF }
                    if let fullFixtures = try? await fullLeagueTask {
                        var homePlayed = 0
                        var homeBttsCount = 0
                        var awayPlayed = 0
                        var awayBttsCount = 0
                        
                        for f in fullFixtures {
                            if let hg = f.homeGoals, let ag = f.awayGoals {
                                let isBtts = hg > 0 && ag > 0
                                
                                if f.homeTeam == fixture.homeTeam || f.awayTeam == fixture.homeTeam {
                                    homePlayed += 1
                                    if isBtts { homeBttsCount += 1 }
                                }
                                
                                if f.homeTeam == fixture.awayTeam || f.awayTeam == fixture.awayTeam {
                                    awayPlayed += 1
                                    if isBtts { awayBttsCount += 1 }
                                }
                            }
                        }
                        
                        if homePlayed > 0 { fetchedHomeBtts = Double(homeBttsCount) / Double(homePlayed) }
                        if awayPlayed > 0 { fetchedAwayBtts = Double(awayBttsCount) / Double(awayPlayed) }
                    }
                }
            }
            
            let finalEvents = fetchedEvents
            let finalLineups = fetchedLineups
            let finalStandings = fetchedStandings
            let finalHomeStats = fetchedHomeStats
            let finalAwayStats = fetchedAwayStats
            let finalHomeFixtures = fetchedHomeFixtures
            let finalAwayFixtures = fetchedAwayFixtures
            let finalHomeBtts = fetchedHomeBtts
            let finalAwayBtts = fetchedAwayBtts
            
            await MainActor.run {
                self.matchEvents = finalEvents.sorted(by: { $0.elapsed > $1.elapsed }) // Newest first
                self.lineups = finalLineups
                self.standings = finalStandings
                self.homeStats = finalHomeStats
                self.awayStats = finalAwayStats
                self.recentHomeFixtures = finalHomeFixtures
                self.recentAwayFixtures = finalAwayFixtures
                self.homeBttsPercentage = finalHomeBtts
                self.awayBttsPercentage = finalAwayBtts
                self.isLoadingStats = false
            }
            
        } catch {
            print("Failed to load fixture data: \(error)")
            await MainActor.run {
                self.isLoadingStats = false
            }
        }
    }
    
    private func marketSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .textCase(nil) // Ensure it isn't coerced to uppercase by any environment
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            
            content()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var resultMarket: some View {
        VStack(spacing: 0) {
            marketOption(label: "\(fixture.homeTeam) Win", odds: fixture.odds.home) {
                selectAndDismiss(team: fixture.homeTeam, odds: fixture.odds.home, logo: fixture.homeLogoUrl)
            }
            Divider()
                .padding(.leading)
            marketOption(label: "Draw", odds: fixture.odds.draw) {
                selectAndDismiss(team: "Draw", odds: fixture.odds.draw, logo: fixture.homeLogoUrl)
            }
            Divider()
                .padding(.leading)
            marketOption(label: "\(fixture.awayTeam) Win", odds: fixture.odds.away) {
                selectAndDismiss(team: fixture.awayTeam, odds: fixture.odds.away, logo: fixture.awayLogoUrl)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var bttsMarket: some View {
        VStack(spacing: 0) {
            if let yes = fixture.odds.bttsYes, let no = fixture.odds.bttsNo {
                marketOption(label: "BTTS - Yes", odds: yes) {
                    selectAndDismiss(team: "BTTS - Yes", odds: yes, logo: fixture.homeLogoUrl)
                }
                Divider()
                    .padding(.leading)
                marketOption(label: "BTTS - No", odds: no) {
                    selectAndDismiss(team: "BTTS - No", odds: no, logo: fixture.homeLogoUrl)
                }
            } else {
                Text("Markets not available for this match")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var totalGoalsMarket: some View {
        VStack(spacing: 0) {
            if let over = fixture.odds.over25, let under = fixture.odds.under25 {
                marketOption(label: "Over 2.5 Goals", odds: over) {
                    selectAndDismiss(team: "Over 2.5 Goals", odds: over, logo: fixture.homeLogoUrl)
                }
                Divider()
                    .padding(.leading)
                marketOption(label: "Under 2.5 Goals", odds: under) {
                    selectAndDismiss(team: "Under 2.5 Goals", odds: under, logo: fixture.homeLogoUrl)
                }
            } else {
                Text("Markets not available for this match")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func marketOption(label: String, odds: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                Spacer()
                Text(odds.formatted())
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func selectAndDismiss(team: String, odds: Double, logo: String?) {
        onSelect(team, odds, logo)
        dismiss()
    }
}

// MARK: - Team Form View for FotMob-style Recent Matches
struct TeamFormView: View {
    let teamName: String
    let recentFixtures: [Fixture]
    let isHome: Bool // No longer determines layout order, but kept for context if needed later
    
    var body: some View {
        VStack(spacing: 8) {
            if recentFixtures.isEmpty {
                Text("No recent matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(recentFixtures) { match in
                        let isTeamHome = match.homeTeam == teamName
                        let outcome = matchOutcome(for: match, isTeamHome: isTeamHome)
                        let scoreText = "\(match.homeGoals ?? 0) - \(match.awayGoals ?? 0)"
                        
                        HStack(spacing: 8) {
                            ClubBadge(url: match.homeLogoUrl, size: 20)
                            matchPill(outcome: outcome, score: scoreText)
                            ClubBadge(url: match.awayLogoUrl, size: 20)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func matchOutcome(for match: Fixture, isTeamHome: Bool) -> SelectionOutcome {
        let homeGoals = match.homeGoals ?? 0
        let awayGoals = match.awayGoals ?? 0
        
        if homeGoals == awayGoals { return .pending } // Using pending for Draw temporarily
        
        if isTeamHome {
            return homeGoals > awayGoals ? .win : .loss
        } else {
            return awayGoals > homeGoals ? .win : .loss
        }
    }
    
    @ViewBuilder
    private func matchPill(outcome: SelectionOutcome, score: String) -> some View {
        let bgColor: Color = {
            switch outcome {
            case .win: return .green
            case .loss: return .red
            case .pending, .void: return .gray // Draw or Void
            }
        }()
        
        Text(score)
            .font(.caption.bold())
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 4))
            .frame(width: 45) // Fixed width for alignment
    }
}
