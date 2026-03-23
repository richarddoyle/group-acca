import SwiftUI

struct MatchesView: View {
    @State private var selectedDate: Date = Date()
    @State private var fixtures: [Competition: [Fixture]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var activeFixtureIds: Set<Int> = []
    @State private var isSearchPresented = false
    
    // Pill State
    enum ActivePill {
        case none, form, cleanSheet, btts, position, predBtts, predOver25, predResult
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
    @State private var fixtureResultPredictions: [String: (home: Double, draw: Double, away: Double)] = [:]
    @State private var isFetchingPredictions: Bool = false
    
    // Generate next 7 days starting from today
    private var dates: [Date] {
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
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var sortedCompetitions: [Competition] {
        let order = LeagueConstants.supportedLeagues.enumerated().reduce(into: [Int: Int]()) { result, item in
            result[item.element.id] = item.offset
        }
        
        return fixtures.keys.sorted(by: {
            let id1 = $0.apiId ?? Int.max
            let id2 = $1.apiId ?? Int.max
            let order1 = order[id1] ?? Int.max
            let order2 = order[id2] ?? Int.max
            return order1 < order2
        })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Matches")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                
                // Date Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            DateTabButtonMatches(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate)) {
                                withAnimation {
                                    selectedDate = date
                                    loadFixtures()
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
                                    } else if activePill == .predBtts || activePill == .predOver25 || activePill == .predResult {
                                        fixtureBttsPredictions.removeAll()
                                        fixtureOver25Predictions.removeAll()
                                        fixtureResultPredictions.removeAll()
                                        fetchPredictions()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
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
                                activePill = activePill == .predResult ? .none : .predResult
                                if activePill == .predResult && fixtureResultPredictions.isEmpty {
                                    fetchPredictions()
                                }
                            }
                        } label: {
                            Text("Result Predict")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(activePill == .predResult ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(activePill == .predResult ? .white : .primary)
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
                
                // Matches List
                if isLoading {
                    Spacer()
                    ProgressView("Loading matches...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            loadFixtures()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if fixtures.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "sportscourt")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Fixtures")
                            .font(.headline)
                        Text("No major matches found for this date.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        if activePill != .none {
                            Section(content: {
                                pillExplanationView
                            }, footer: {
                                if activePill == .position || activePill == .predBtts || activePill == .predOver25 || activePill == .predResult {
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
                            ForEach(sortedCompetitions, id: \.self) { competition in
                                if let compFixtures = fixtures[competition], !compFixtures.isEmpty {
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
                            let flattened = fixtures.values.flatMap { $0 }.sorted { f1, f2 in
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
                    .padding(.top, activePill == .none ? 0 : -24)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSearchPresented) {
                TeamSearchView(
                    dates: dates,
                    week: nil,
                    memberSelections: nil,
                    onSelect: nil,
                    badgeManager: nil
                )
            }
            .onAppear {
                loadFixtures()
            }
            .refreshable {
                loadFixtures()
            }
        }
    }
    
    @ViewBuilder
    private func matchRow(for fixture: Fixture) -> some View {
        ZStack {
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
                matchResultPredict: fixtureResultPredictions[String(fixture.apiId ?? 0)],
                showBttsPredict: activePill == .predBtts,
                showOver25Predict: activePill == .predOver25,
                showResultPredict: activePill == .predResult,
                isLoadingStats: activePill == .form ? isFetchingForms :
                                activePill == .cleanSheet ? isFetchingCleanSheets :
                                activePill == .btts ? isFetchingBtts :
                                activePill == .position ? isFetchingPositions :
                                (activePill == .predBtts || activePill == .predOver25 || activePill == .predResult) ? isFetchingPredictions : false,
                isPartOfAcca: activeFixtureIds.contains(fixture.apiId ?? -1)
            )
                
            NavigationLink(destination: MarketSelectionView(
                fixture: fixture,
                onSelect: { _, _, _ in }, // No-op, picks disabled
                isReadOnly: true
            )) {
                EmptyView()
            }
            .opacity(0)
        }
    }
    
    private func loadFixtures() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // 1. Get the list of allowed League IDs
            let allowedIDs = LeagueConstants.supportedLeagues.map { $0.id }
            
            // 2. Fetch concurrently
            do {
                let allFixtures = try await APIService.shared.fetchFixtures(date: selectedDate)
                
                // 3. Filter locally
                var filteredFixtures: [Competition: [Fixture]] = [:]
                for (competition, fixtureList) in allFixtures {
                    if let apiId = competition.apiId, allowedIDs.contains(apiId) {
                        filteredFixtures[competition] = fixtureList
                    } else if allowedIDs.isEmpty {
                        // If no allowed IDs are defined, show all
                        filteredFixtures[competition] = fixtureList
                    }
                }
                
                // 4. Fetch Active Fixture IDs
                let activeIds = try? await SupabaseService.shared.fetchActiveFixtureIds(for: SupabaseService.shared.currentUserId)
                
                await MainActor.run {
                    self.fixtures = filteredFixtures
                    self.activeFixtureIds = activeIds ?? []
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
}

// Reusing a similar date tab button but named differently to avoid global conflict if not already public
struct DateTabButtonMatches: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday()).uppercased())
                    .font(.caption2.bold())
                Text(date.formatted(.dateTime.day()))
                    .font(.title3.bold())
            }
            .frame(width: 50, height: 60)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Optional: add a border for unselected state to make it look like a nice button
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// A read-only row for a match
struct MatchRowView: View {
    let fixture: Fixture
    var homeForm: String? = nil
    var awayForm: String? = nil
    var showForm: Bool = false
    
    var homeCleanSheet: Int? = nil
    var awayCleanSheet: Int? = nil
    var showCleanSheets: Bool = false
    
    var homeBtts: Int? = nil
    var awayBtts: Int? = nil
    var showBtts: Bool = false
    
    var homePosition: Int? = nil
    var awayPosition: Int? = nil
    var showPositions: Bool = false
    
    var matchBttsPredict: Double? = nil
    var matchOver25Predict: Double? = nil
    var matchResultPredict: (home: Double, draw: Double, away: Double)? = nil
    var showBttsPredict: Bool = false
    var showOver25Predict: Bool = false
    var showResultPredict: Bool = false
    
    var isLoadingStats: Bool = false
    
    var takenByMember: String? = nil
    var takenByAvatarUrl: String? = nil
    var takenByBadgeEmoji: String? = nil
    
    var isPartOfAcca: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Kickoff time or status + Taken Indicator
            HStack {
                Text(fixture.status == "NS" ? fixture.date.formatted(date: .omitted, time: .shortened) : fixture.status)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                
                HStack(spacing: 8) {
                    if isPartOfAcca {
                        Text("In Acca")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    if takenByMember != nil {
                        HStack(spacing: 4) {
                            ProfileImage(url: takenByAvatarUrl, size: 16)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
                        
                        if let emoji = takenByBadgeEmoji {
                            Text(emoji)
                                .font(.caption)
                        }
                        
                        Text("Taken")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Teams and Score Layer
            VStack(spacing: 6) {
                // Top Row: Teams + Badges + VS
                HStack(spacing: 8) {
                    // Home Team
                    HStack(alignment: .center, spacing: 8) {
                        Spacer(minLength: 0)
                        Text(fixture.homeTeam)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                        
                        if let url = fixture.homeLogoUrl {
                            CachedImage(url: url) { image in
                                image.resizable()
                                     .scaledToFit()
                            } placeholder: {
                                Image(systemName: "shield")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "shield")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // Score or VS
                    VStack {
                        if fixture.status == "NS" {
                            Text("vs")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        } else {
                            Text("\(fixture.homeGoals ?? 0) - \(fixture.awayGoals ?? 0)")
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Away Team
                    HStack(alignment: .center, spacing: 8) {
                        if let url = fixture.awayLogoUrl {
                            CachedImage(url: url) { image in
                                image.resizable()
                                     .scaledToFit()
                            } placeholder: {
                                Image(systemName: "shield")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "shield")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(fixture.awayTeam)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Bottom Row: Pills horizontally aligned
                if showForm || showCleanSheets || showBtts || showPositions || showBttsPredict || showOver25Predict || showResultPredict {
                    if isLoadingStats {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                                .padding(.vertical, 4)
                            Spacer()
                        }
                        .frame(minHeight: 24)
                    } else if showBttsPredict || showOver25Predict || showResultPredict {
                        HStack {
                            Spacer()
                            if showBttsPredict, let prob = matchBttsPredict {
                                predictionView(percentage: prob, label: "BTTS Predict")
                            } else if showOver25Predict, let prob = matchOver25Predict {
                                predictionView(percentage: prob, label: "Over 2.5 Predict")
                            } else if showResultPredict, let prob = matchResultPredict {
                                predictionResultView(home: prob.home, draw: prob.draw, away: prob.away)
                            } else {
                                predictionView(percentage: nil, label: "Predict")
                            }
                            Spacer()
                        }
                    } else {
                        HStack(spacing: 8) {
                            // Home Pill (right aligned to text = padding for badge)
                            HStack(spacing: 8) {
                                Spacer(minLength: 0)
                            if showForm {
                                formCircles(for: homeForm)
                            } else if showCleanSheets {
                                cleanSheetView(percentage: homeCleanSheet)
                            } else if showBtts {
                                bttsView(percentage: homeBtts)
                            } else if showPositions {
                                positionView(rank: homePosition)
                            }
                            
                            // Visual offset replacing badge element
                            Color.clear.frame(width: 24, height: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        // Fake center padding
                        VStack {
                            if fixture.status == "NS" {
                                Text("vs")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            } else {
                                Text("\(fixture.homeGoals ?? 0) - \(fixture.awayGoals ?? 0)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }
                        .hidden()
                        
                        // Away Pill (left aligned to text = padding for badge)
                        HStack(spacing: 8) {
                            // Visual offset replacing badge element
                            Color.clear.frame(width: 24, height: 0)
                            
                            if showForm {
                                formCircles(for: awayForm)
                            } else if showCleanSheets {
                                cleanSheetView(percentage: awayCleanSheet)
                            } else if showBtts {
                                bttsView(percentage: awayBtts)
                            } else if showPositions {
                                positionView(rank: awayPosition)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func formCircles(for formString: String?) -> some View {
        if let form = formString {
            HStack(spacing: 3) {
                ForEach(Array(form.prefix(5)), id: \.self) { char in
                    Circle()
                        .fill(colorForFormChar(char))
                        .frame(width: 8, height: 8)
                }
            }
        } else if showForm {
            // Placeholder while loading
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
    
    @ViewBuilder
    private func cleanSheetView(percentage: Int?) -> some View {
        if let percentage = percentage {
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(colorForPercentage(percentage))
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorForPercentage(percentage))
            }
        } else if showCleanSheets {
            // Placeholder
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.systemGray5))
                Text("--%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(.systemGray5))
            }
        }
    }
    
    @ViewBuilder
    private func bttsView(percentage: Int?) -> some View {
        if let percentage = percentage {
            HStack(spacing: 4) {
                Image(systemName: "soccerball.inverse")
                    .font(.system(size: 10))
                    .foregroundColor(colorForBttsPercentage(percentage))
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorForBttsPercentage(percentage))
            }
        } else if showBtts {
            // Placeholder
            HStack(spacing: 4) {
                Image(systemName: "soccerball.inverse")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.systemGray5))
                Text("--%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(.systemGray5))
            }
        }
    }
    
    @ViewBuilder
    private func positionView(rank: Int?) -> some View {
        if let rank = rank {
            Text("\(rank)\(ordinalSuffix(for: rank))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else if showPositions {
            Text("-")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(.systemGray4))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func predictionView(percentage: Double?, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundColor(.accentColor)
                .font(.system(size: 10))
            if let percentage = percentage {
                Text("\(label): \(Int(percentage * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
            } else {
                Text("\(label): --%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(.systemGray5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func predictionResultView(home: Double, draw: Double, away: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.accentColor)
                .font(.system(size: 10))
            
            HStack(spacing: 8) {
                Text("1: \(Int((home * 100).rounded()))%")
                Text("X: \(Int((draw * 100).rounded()))%")
                Text("2: \(Int((away * 100).rounded()))%")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private func ordinalSuffix(for number: Int) -> String {
        let s = "\(number)"
        if s.hasSuffix("11") || s.hasSuffix("12") || s.hasSuffix("13") {
            return "th"
        }
        switch number % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        if percentage >= 50 {
            return .green
        } else if percentage >= 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func colorForBttsPercentage(_ percentage: Int) -> Color {
        if percentage >= 60 {
            return .green
        } else if percentage >= 45 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func colorForFormChar(_ char: Character) -> Color {
        switch char {
        case "W": return .green
        case "D": return .gray
        case "L": return .red
        default: return .gray
        }
    }

}

// MARK: - Extracted Fetch Logic
extension MatchesView {
    private func fetchForms() {
            guard !isFetchingForms else { return }
            isFetchingForms = true
            
            Task {
                let competitions = sortedCompetitions
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
                let competitions = sortedCompetitions
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
                let competitions = sortedCompetitions
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
                let competitions = sortedCompetitions
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
                var resultPredictions: [String: (home: Double, draw: Double, away: Double)] = [:]
                
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
                    
                    // Result 1X2 Exact calculation (up to 10 goals each to cover 99.9% probability)
                    var pHome = 0.0
                    var pDraw = 0.0
                    var pAway = 0.0
                    
                    for h in 0...10 {
                        for a in 0...10 {
                            let probH = exp(-xgHome) * pow(xgHome, Double(h)) / Double((1...max(1, h)).reduce(1, *))
                            let probA = exp(-xgAway) * pow(xgAway, Double(a)) / Double((1...max(1, a)).reduce(1, *))
                            let prob = probH * probA
                            
                            if h > a {
                                pHome += prob
                            } else if h == a {
                                pDraw += prob
                            } else {
                                pAway += prob
                            }
                        }
                    }
                    
                    // Normalize probabilities just in case
                    let totalP = pHome + pDraw + pAway
                    if totalP > 0 {
                        pHome /= totalP
                        pDraw /= totalP
                        pAway /= totalP
                    }
                    
                    resultPredictions[String(id)] = (home: pHome, draw: pDraw, away: pAway)
                }
                
                await MainActor.run {
                    self.fixtureBttsPredictions = bttsResults
                    self.fixtureOver25Predictions = over25Results
                    self.fixtureResultPredictions = resultPredictions
                    self.isFetchingPredictions = false
                }
            }
        }
        
        private func fetchPositions() {
            guard !isFetchingPositions else { return }
            isFetchingPositions = true
            
            Task {
                let competitions = sortedCompetitions
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
            case .predResult: return "Calculated likelihood of a Home win (1), Draw (X), or Away win (2) based on past scoring."
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
        case .predResult:
            if let probs = fixtureResultPredictions[String(fixture.apiId ?? 0)] {
                return max(probs.home, probs.away)
            }
            return 0.0
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

#Preview {
    MatchesView()
}
