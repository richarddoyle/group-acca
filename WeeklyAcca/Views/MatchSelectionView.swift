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
        fixtures.keys.filter { isCompetitionAllowed($0) }.sorted(by: { $0.name < $1.name })
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
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
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
                        List {
                            ForEach(filteredCompetitions, id: \.self) { competition in
                                Section(header: Text(competition.name).font(.subheadline.bold())) {
                                    ForEach((fixtures[competition] ?? []).filter { $0.status == "NS" && $0.date > Date() }) { fixture in
                                        FixtureCard(fixture: fixture) {
                                            selectedFixture = fixture
                                        }
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                }
                            }
                        }
                        .listStyle(.grouped)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGroupedBackground))
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
                if let allowedLeagues = week?.selectedLeagues, !allowedLeagues.isEmpty {
                    let leagueIDs = allowedLeagues.compactMap { LeagueConstants.getID(for: $0) }
                    
                    if leagueIDs.isEmpty {
                        await MainActor.run {
                            self.fixtures = [:]
                            self.isLoading = false
                        }
                        return
                    }
                    
                    var combinedFixtures: [Competition: [Fixture]] = [:]
                    
                    try await withThrowingTaskGroup(of: [Competition: [Fixture]].self) { group in
                        for id in leagueIDs {
                            group.addTask {
                                return try await APIService.shared.fetchFixtures(date: selectedDate, leagueId: id)
                            }
                        }
                        
                        for try await result in group {
                            for (comp, fixtures) in result {
                                combinedFixtures[comp] = fixtures
                            }
                        }
                    }
                    
                    await MainActor.run {
                        self.fixtures = combinedFixtures
                        self.isLoading = false
                    }
                } else {
                    // Fallback to fetching all (though likely truncated by API)
                    let newFixtures = try await APIService.shared.fetchFixtures(date: selectedDate)
                    await MainActor.run {
                        self.fixtures = newFixtures
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectMatch(fixture: Fixture, team: String, odds: Double, logo: String?) {
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
                selection.awayScore = nil
                selection.homeTeamName = fixture.homeTeam
                selection.awayTeamName = fixture.awayTeam
                selection.fixtureId = fixture.apiId
                
                // Save to Supabase
                try await SupabaseService.shared.saveSelection(selection)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Error saving selection: \(error)")
                    errorMessage = "Failed to save selection. Please try again."
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
            .background(isSelected ? Color.blue : Color.clear)
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
