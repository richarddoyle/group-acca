import SwiftUI

struct TeamSearchView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Inputs
    let dates: [Date]
    let week: Week?
    let memberSelections: [MemberSelectionDisplay]? // if nil, read-only mode, if not nil, pick mode
    let onSelect: ((Fixture) -> Void)?
    
    // Pick mode deps
    let badgeManager: GroupBadgeManager?
    
    @State private var searchText = ""
    @State private var allFixtures: [Fixture] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // For fast display of acca badges
    @State private var activeFixtureIds: Set<Int> = []
    
    // Derived
    private var isReadOnly: Bool {
        memberSelections == nil
    }
    
    var filteredFixtures: [Fixture] {
        if searchText.isEmpty {
            return []
        }
        return allFixtures.filter { fixture in
            fixture.homeTeam.localizedCaseInsensitiveContains(searchText) ||
            fixture.awayTeam.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching fixtures...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadAllFixtures()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredFixtures.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No matches found for \"\(searchText)\"."))
                } else {
                    List {
                        ForEach(filteredFixtures) { fixture in
                            if isReadOnly {
                                ZStack {
                                    MatchRowView(fixture: fixture, isPartOfAcca: activeFixtureIds.contains(fixture.apiId ?? -1))
                                    NavigationLink(destination: MarketSelectionView(
                                        fixture: fixture,
                                        onSelect: { _, _, _ in }, // No-op, picks disabled
                                        isReadOnly: true
                                    )) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                }
                                .listRowInsets(EdgeInsets())
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            } else {
                                Button {
                                    if let onSelect = onSelect {
                                        onSelect(fixture)
                                    }
                                } label: {
                                    let takenInfo = checkTaken(fixture: fixture)
                                    MatchRowView(
                                        fixture: fixture,
                                        takenByMember: takenInfo?.name,
                                        takenByAvatarUrl: takenInfo?.avatarUrl,
                                        takenByBadgeEmoji: takenInfo != nil ? badgeManager?.badges[takenInfo!.memberId] : nil
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Search Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search team name")
            .onAppear {
                loadAllFixtures()
            }
        }
    }
    
    private func loadAllFixtures() {
        guard allFixtures.isEmpty && !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            // 1. Get allowed leagues
            let allowedIDs: [Int]
            if let params = week?.selectedLeagues, !params.isEmpty {
                allowedIDs = params.compactMap { LeagueConstants.getID(for: $0) }
            } else {
                allowedIDs = LeagueConstants.supportedLeagues.map { $0.id }
            }
            
            // 2. Fetch Active Fixture IDs (only needed for matches view)
            var activeIds: Set<Int> = []
            if isReadOnly {
                if let ids = try? await SupabaseService.shared.fetchActiveFixtureIds(for: SupabaseService.shared.currentUserId) {
                    activeIds = ids
                }
            }
            let fetchedActiveIds = activeIds
            
            // 3. Fetch fixtures concurrently for all dates
            await withTaskGroup(of: [Fixture]?.self) { group in
                for date in dates {
                    group.addTask {
                        do {
                            let rawFixtures = try await APIService.shared.fetchFixtures(date: date)
                            var validFixtures: [Fixture] = []
                            
                            for (comp, list) in rawFixtures {
                                if let apiId = comp.apiId, allowedIDs.isEmpty || allowedIDs.contains(apiId) {
                                    validFixtures.append(contentsOf: list)
                                }
                            }
                            return validFixtures
                        } catch {
                            print("Error fetching dates: \(error)")
                            return nil
                        }
                    }
                }
                
                var results: [Fixture] = []
                for await result in group {
                    if let result = result {
                        results.append(contentsOf: result)
                    }
                }
                
                // Final filtering
                let deadline = week?.startDate ?? Date.distantPast
                let finalFixtures = results
                    .filter { $0.date > deadline }
                    .filter { isReadOnly || $0.status == "NS" } // Pick selection view only shows "NS"
                    .sorted { $0.date < $1.date }
                
                await MainActor.run {
                    self.allFixtures = finalFixtures
                    self.activeFixtureIds = fetchedActiveIds
                    self.isLoading = false
                }
            }
        }
    }
    
    private func checkTaken(fixture: Fixture) -> (name: String, avatarUrl: String?, memberId: UUID)? {
        guard let selections = memberSelections else { return nil }
        for memberSelection in selections {
            if memberSelection.selections.contains(where: { 
                $0.fixtureId == fixture.apiId || 
                $0.homeTeamName == fixture.homeTeam && $0.awayTeamName == fixture.awayTeam 
            }) {
                return (memberSelection.member.name, memberSelection.avatarUrl, memberSelection.member.id)
            }
        }
        return nil
    }
}
