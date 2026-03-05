import SwiftUI

struct MatchesView: View {
    @State private var selectedDate: Date = Date()
    @State private var fixtures: [Competition: [Fixture]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
                // Date Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            DateTabButtonMatches(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate)) {
                                withAnimation {
                                    selectedDate = date
                                    loadFixtures()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
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
                        ForEach(sortedCompetitions, id: \.self) { competition in
                            if let compFixtures = fixtures[competition], !compFixtures.isEmpty {
                                Section {
                                    ForEach(compFixtures) { fixture in
                                        ZStack {
                                            MatchRowView(fixture: fixture)
                                                
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
                                } header: {
                                    Text(competition.name)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFixtures()
            }
            .refreshable {
                loadFixtures()
            }
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
    
    var body: some View {
        VStack(spacing: 8) {
            // Kickoff time or status
            HStack {
                Text(fixture.status == "NS" ? fixture.date.formatted(date: .omitted, time: .shortened) : fixture.status)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
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
                if showForm || showCleanSheets || showBtts || showPositions {
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
            HStack(spacing: 4) {
                Image(systemName: "list.number")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(ordinalString(for: rank))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
            }
        } else if showPositions {
            // Placeholder
            HStack(spacing: 4) {
                Image(systemName: "list.number")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.systemGray5))
                Text("-")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(.systemGray5))
            }
        }
    }
    
    private func ordinalString(for number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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

#Preview {
    MatchesView()
}
