import SwiftUI

// Deprecated: No longer using PreferenceKey due to iOS 16 simulator bugs
// We are extracting geometry frame min Y directly via .onChange now

struct MarketSelectionView: View {
    let fixture: Fixture
    let onSelect: (String, Double, String?) -> Void
    var isReadOnly: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTopTab: TopTab
    @State private var matchEvents: [MatchEvent] = []
    @State private var lineups: [TeamLineup] = []
    @State private var injuries: [Injury] = []
    @State private var standings: [LeagueStandingRow] = []
    @State private var homeStats: TeamStatistics?
    @State private var awayStats: TeamStatistics?
    
    @State private var homeBttsPercentage: Double?
    @State private var awayBttsPercentage: Double?
    
    @State private var knockoutFixtures: [Fixture] = []
    
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
        
        if fixture.isKnockout {
            availableTabs.append(.bracket)
        } else {
            availableTabs.append(.table)
        }
        
        if !isFutureMatch {
            availableTabs.append(.lineups)
        }
        
        availableTabs.append(.injuries)
        availableTabs.append(.stats)
        
        return availableTabs
    }
    
    enum TopTab: String, CaseIterable, Equatable {
        case picks = "Picks"
        case details = "Game Details"
        case table = "Table"
        case bracket = "Knockout Bracket"
        case lineups = "Lineup"
        case injuries = "Injuries"
        case stats = "Stats"
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
            defaultTab = fixture.isKnockout ? .bracket : .table
        }
        
        _selectedTopTab = State(initialValue: defaultTab)
    }
    
    private let glassBackground = Color.black.opacity(0.05)
    
    // Navigation bar background color blend progress
    private var progress: Double {
        min(1.0, max(0.0, -scrollOffset / 60.0))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Top Navigation Bar
            customNavigationBar
                .zIndex(1)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Tracking node
                    Color.clear
                        .frame(height: 0)
                        .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .onChange(of: geo.frame(in: .global).minY) { _, newMinY in
                                        // The initial position of the view when not scrolled is the baseline
                                        // We want to track how far UP (negative) it has scrolled from its baseline
                                        // But we need the initial Y position to act as 0. 
                                        // To simplify, we track the frame directly inside .named("scroll") coordinate space
                                    }
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onChange(of: geo.frame(in: .named("scroll")).minY) { _, newValue in
                                        self.scrollOffset = newValue
                                    }
                                    .onAppear {
                                        self.scrollOffset = geo.frame(in: .named("scroll")).minY
                                    }
                            }
                        )
                    
                    // Match Header (Scrolls naturally up)
                    matchHeaderView
                    
                    // Pinned Tabs & Content
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section(header: topTabBar) {
                            VStack(spacing: 24) {
                                switch selectedTopTab {
                                case .picks: allMarketsContent
                                case .details: gameDetailsTab
                                case .table: tableTab
                                case .bracket: bracketTab
                                case .lineups: lineupTab
                                case .injuries: injuriesTab
                                case .stats: pickStatsTab
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await loadMatchData()
        }
    }
    
    private var customNavigationBar: some View {
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
            
            ZStack {
                Text(fixture.competition.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .opacity(1.0 - progress)
                
                HStack(spacing: 12) {
                    ClubBadge(url: fixture.homeLogoUrl, size: 24)
                    
                    if fixture.status == "NS" || fixture.status == "TBD" {
                        Text("VS")
                            .font(.headline.bold())
                    } else {
                        Text("\(fixture.homeGoals ?? 0) - \(fixture.awayGoals ?? 0)")
                            .font(.headline.bold())
                    }
                    
                    ClubBadge(url: fixture.awayLogoUrl, size: 24)
                }
                .opacity(progress)
            }
            
            Spacer()
            
            Circle().fill(.clear).frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
    }
    
    private var matchHeaderView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                teamHeader(name: fixture.homeTeam, logo: fixture.homeLogoUrl, alignment: .trailing)
                
                VStack(spacing: 4) {
                    if fixture.status == "NS" || fixture.status == "TBD" {
                        Text(fixture.timeString)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        Text("VS")
                            .font(.system(size: 22, weight: .bold))
                            .italic()
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(fixture.status)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(fixture.status == "FT" ? Color.gray : Color.red, in: Capsule())
                        
                        Text("\(fixture.homeGoals ?? 0) - \(fixture.awayGoals ?? 0)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 80)
                
                teamHeader(name: fixture.awayTeam, logo: fixture.awayLogoUrl, alignment: .leading)
            }
            .padding(.horizontal)
            
            // Goal Scorers List
            if !goalEventsForHeader.home.isEmpty || !goalEventsForHeader.away.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    // Home Goals
                    VStack(alignment: .trailing, spacing: 6) {
                        if goalEventsForHeader.home.isEmpty {
                            Color.clear.frame(height: 0)
                        } else {
                            ForEach(goalEventsForHeader.home) { event in
                                HStack(spacing: 6) {
                                    Text("\(event.playerName) \(event.elapsed)'\(event.extra != nil ? "+\(event.extra!)'" : "")")
                                        .font(.caption)
                                        .foregroundStyle(Color.gray)
                                    Image(systemName: "soccerball")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.gray)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // Spacer for the center "VS / Score" column
                    Color.clear.frame(width: 80)
                    
                    // Away Goals
                    VStack(alignment: .leading, spacing: 6) {
                        if goalEventsForHeader.away.isEmpty {
                            Color.clear.frame(height: 0)
                        } else {
                            ForEach(goalEventsForHeader.away) { event in
                                HStack(spacing: 6) {
                                    Image(systemName: "soccerball")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.gray)
                                    Text("\(event.playerName) \(event.elapsed)'\(event.extra != nil ? "+\(event.extra!)'" : "")")
                                        .font(.caption)
                                        .foregroundStyle(Color.gray)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
        }
        .opacity(1.0 - progress)
        .padding(.vertical, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private func teamHeader(name: String, logo: String?, alignment: HorizontalAlignment) -> some View {
        VStack(spacing: 8) {
            ClubBadge(url: logo, size: 64)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            Text(name)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 35)
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
        .shadow(color: .black.opacity(progress > 0.8 ? 0.05 : 0.0), radius: 2, y: 2)
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
    
    // Processed Goals for Header
    private var goalEventsForHeader: (home: [MatchEvent], away: [MatchEvent]) {
        let goals = matchEvents.filter { $0.type == "Goal" && $0.detail != "Missed Penalty" }
        
        let homeGoals = goals.filter { $0.teamName == fixture.homeTeam }
        let awayGoals = goals.filter { $0.teamName == fixture.awayTeam }
        
        return (homeGoals, awayGoals)
    }
    
    // MARK: - New Tab Views
    
    @ViewBuilder
    private var gameDetailsTab: some View {
        if matchEvents.isEmpty {
            Text("No match events available.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            VStack(alignment: .center, spacing: 0) {
                // Reverse chronological order for timeline format
                ForEach(matchEvents.reversed()) { event in
                    let isHome = event.teamName == fixture.homeTeam
                    
                    HStack(spacing: 8) {
                        // Left side (Home)
                        if isHome {
                            eventDetailsView(for: event, isHome: true)
                            eventIconWrapper(for: event)
                        } else {
                            Spacer()
                        }
                        
                        // Center (Time)
                        HStack(alignment: .top, spacing: 1) {
                            Text("\(event.elapsed)'")
                                .font(.caption2.bold())
                                .foregroundStyle(.primary)
                            if let extra = event.extra {
                                Text("+\(extra)'")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 32, alignment: .center)
                        
                        // Right side (Away)
                        if !isHome {
                            eventIconWrapper(for: event)
                            eventDetailsView(for: event, isHome: false)
                        } else {
                            Spacer()
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    
                    if event.id != matchEvents.reversed().last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func eventIconWrapper(for event: MatchEvent) -> some View {
        VStack(alignment: .center, spacing: event.type == "subst" ? 2 : 0) {
            if event.type == "subst" {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else {
                eventIcon(for: event)
                    .font(.system(size: 12))
            }
        }
        .frame(width: 16)
    }

    @ViewBuilder
    private func eventDetailsView(for event: MatchEvent, isHome: Bool) -> some View {
        let align = isHome ? HorizontalAlignment.trailing : HorizontalAlignment.leading
        VStack(alignment: align, spacing: event.type == "subst" ? 2 : 1) {
            if event.type == "subst" {
                Text(event.assistName ?? "Unknown")
                    .font(.caption.bold())
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
                Text(event.playerName)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
            } else {
                Text(event.playerName)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let assist = event.assistName {
                    Text("Assist: \(assist)")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                } else if event.type == "Goal" {
                    Text(event.detail)
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isHome ? .trailing : .leading)
    }
    
    @ViewBuilder
    private func eventIcon(for event: MatchEvent) -> some View {
        if event.type == "Goal" {
            Image(systemName: "soccerball")
        } else if event.type == "Card" {
            Image(systemName: "rectangle.portrait.fill")
                .foregroundStyle(event.detail.contains("Yellow") ? .yellow : .red)
                .rotationEffect(.degrees(10))
        } else {
            Image(systemName: "flag.fill")
                .foregroundStyle(.secondary)
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
            .padding(.horizontal)
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
    private var bracketTab: some View {
        if knockoutFixtures.isEmpty && !isLoadingStats {
            Text("Bracket data not available.")
                .foregroundStyle(.secondary)
                .padding()
        } else if knockoutFixtures.isEmpty {
            ProgressView("Loading Bracket...")
                .padding()
        } else {
            BracketTree(fixtures: knockoutFixtures, highlightTeam: fixture.homeTeam)
                .padding()
        }
    }
    
    @ViewBuilder
    private var injuriesTab: some View {
        if injuries.isEmpty {
            Text("No injuries reported.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            HStack(alignment: .top, spacing: 16) {
                // Home Injuries
                VStack(alignment: .leading, spacing: 12) {
                    let homeTeamLower = fixture.homeTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let homeInjuries = injuries.filter { $0.teamName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).contains(homeTeamLower) || homeTeamLower.contains($0.teamName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if homeInjuries.isEmpty {
                        Text("None").foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(homeInjuries) { injury in
                            injuryRow(injury)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Away Injuries
                VStack(alignment: .leading, spacing: 12) {
                    let awayTeamLower = fixture.awayTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let awayInjuries = injuries.filter { $0.teamName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).contains(awayTeamLower) || awayTeamLower.contains($0.teamName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if awayInjuries.isEmpty {
                        Text("None").foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(awayInjuries) { injury in
                            injuryRow(injury)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    
    private func injuryRow(_ injury: Injury) -> some View {
        HStack(spacing: 12) {
            CachedImage(url: injury.playerPhoto) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .background(Color(.systemGray6))
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(injury.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(injury.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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
            .padding(.horizontal)
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
            
            // Fetch events, lineups, and injuries concurrently but safely
            async let eventsTask = APIService.shared.fetchMatchEvents(fixtureId: fixtureId)
            async let lineupsTask = APIService.shared.fetchLineups(fixtureId: fixtureId)
            async let injuriesTask = APIService.shared.fetchInjuries(fixtureId: fixtureId)
            
            let fetchedEvents = (try? await eventsTask) ?? []
            let fetchedLineups = (try? await lineupsTask) ?? []
            let fetchedInjuries = (try? await injuriesTask) ?? []
            
            if fixture.isKnockout, let leagueId = fixture.competition.apiId {
                let season = APIService.shared.getCurrentSeasonYear(for: fixture.date) // Temporarily accessing from within MarketSelectionView requires making getCurrentSeasonYear internal, or we can use calendar logic here.
                let calendar = Calendar.current
                let year = calendar.component(.year, from: fixture.date)
                let month = calendar.component(.month, from: fixture.date)
                let seasonYear = month < 8 ? year - 1 : year
                
                if let bracketMatches = try? await APIService.shared.fetchTournamentFixtures(leagueId: leagueId, season: seasonYear) {
                    await MainActor.run {
                        self.knockoutFixtures = bracketMatches
                    }
                }
            }
            
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
            let finalInjuries = fetchedInjuries
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
                self.injuries = finalInjuries
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
                VStack(spacing: 12) {
                    ForEach(recentFixtures) { match in
                        let isTeamHome = match.homeTeam == teamName
                        let outcome = matchOutcome(for: match, isTeamHome: isTeamHome)
                        let scoreText = "\(match.homeGoals ?? 0) - \(match.awayGoals ?? 0)"
                        
                        HStack(spacing: 16) {
                            ClubBadge(url: match.homeLogoUrl, size: 28)
                            matchPill(outcome: outcome, score: scoreText)
                            ClubBadge(url: match.awayLogoUrl, size: 28)
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
            .font(.subheadline.bold())
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 6))
            .frame(width: 55) // Fixed width for alignment
    }
}
