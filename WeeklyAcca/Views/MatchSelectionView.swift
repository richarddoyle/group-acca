import SwiftUI

struct MatchSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var selection: Selection
    let week: Week? // Pass explicitly
    
    @State private var selectedDate: Date = Date()
    @State private var fixtures: [Competition: [Fixture]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                        ContentUnavailableView("Error Loading Fixtures", systemImage: "exclamationmark.triangle", description: Text(error))
                    } else if filteredFixtures.isEmpty {
                        ContentUnavailableView("No Fixtures", systemImage: "soccerball", description: Text("No matches found for this date in your selected leagues."))
                    } else {
                        List {
                            ForEach(filteredCompetitions, id: \.self) { competition in
                                Section(header: Text(competition.name)) {
                                    ForEach(fixtures[competition] ?? []) { fixture in
                                        FixtureRow(fixture: fixture) { selectedTeam, odds in
                                            selectMatch(fixture: fixture, team: selectedTeam, odds: odds)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.grouped)
                    }
                }
            }
            .navigationTitle("Select Match")
            .navigationBarTitleDisplayMode(.inline)
            // Cancel button removed as per user request (use Back button)
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
                let newFixtures = try await APIService.shared.fetchFixtures(date: selectedDate)
                await MainActor.run {
                    self.fixtures = newFixtures
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    // Optional: Fallback to mock data if API fails completely
                    // self.fixtures = MockData.shared.getFixtures(for: selectedDate)
                }
            }
        }
    }
    
    private func selectMatch(fixture: Fixture, team: String, odds: Double) {
        isLoading = true
        
        Task {
            do {
                // Update local selection object
                selection.teamName = team
                selection.league = fixture.competition.name
                selection.odds = odds
                selection.outcome = .pending // Reset outcome if changing match
                
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

// Subview for Fixture Row
struct FixtureRow: View {
    let fixture: Fixture
    let onSelect: (String, Double) -> Void
    
    @State private var showingOutcomeSheet = false
    
    var body: some View {
        Button {
            showingOutcomeSheet = true
        } label: {
            VStack(spacing: 8) {
                Text(fixture.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    // Home
                    Text(fixture.homeTeam)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // VS
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    // Away
                    Text(fixture.awayTeam)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Select Outcome", isPresented: $showingOutcomeSheet, titleVisibility: .visible) {
            Button("\(fixture.homeTeam) to Win @ \(fixture.odds.home.formatted())") {
                onSelect(fixture.homeTeam, fixture.odds.home)
            }
            
            Button("Draw @ \(fixture.odds.draw.formatted())") {
                onSelect("Draw - \(fixture.homeTeam) vs \(fixture.awayTeam)", fixture.odds.draw)
            }
            
            Button("\(fixture.awayTeam) to Win @ \(fixture.odds.away.formatted())") {
                onSelect(fixture.awayTeam, fixture.odds.away)
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(fixture.homeTeam) vs \(fixture.awayTeam)")
        }
    }
}
