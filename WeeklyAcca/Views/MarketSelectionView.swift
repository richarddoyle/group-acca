import SwiftUI

struct MarketSelectionView: View {
    let fixture: Fixture
    let onSelect: (String, Double, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTopTab: TopTab = .picks
    
    enum TopTab: String, CaseIterable {
        case picks = "Picks"
        case stats = "Stats"
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
                
                // Top Level Tabs (Picks / Stats)
                topTabBar
                
                // Content Area
                if selectedTopTab == .picks {
                    ScrollView {
                        VStack(spacing: 24) {
                            allMarketsContent
                        }
                        .padding()
                    }
                } else {
                    // Stats View Placeholder
                    ScrollView {
                        statsPlaceholderView
                    }
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
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
            
            // Match Header
            HStack(spacing: 16) {
                teamHeader(name: fixture.homeTeam, logo: fixture.homeLogoUrl, alignment: .trailing)
                
                VStack(spacing: 4) {
                    Text(fixture.timeString)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text("VS")
                        .font(.title2.bold())
                        .italic()
                        .foregroundStyle(.blue)
                }
                .frame(width: 60)
                
                teamHeader(name: fixture.awayTeam, logo: fixture.awayLogoUrl, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
    }
    
    private func teamHeader(name: String, logo: String?, alignment: HorizontalAlignment) -> some View {
        VStack(spacing: 12) {
            ClubBadge(url: logo, size: 64)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            Text(name)
                .font(.subheadline.bold())
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var topTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TopTab.allCases, id: \.self) { tab in
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
                            .fill(selectedTopTab == tab ? Color.blue : Color.clear)
                            .frame(height: 3)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
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
    
    private func marketSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            content()
        }
    }
    
    private var statsPlaceholderView: some View {
        VStack(spacing: 20) {
            statCard(title: "Recent Form", placeholder: "W D L W W   vs   L D L D L")
            statCard(title: "Clean Sheets", placeholder: "Home: 40%   Away: 15%")
            statCard(title: "Failed To Score", placeholder: "Home: 10%   Away: 30%")
            statCard(title: "Head to Head", placeholder: "Last 5: Home 3, Draw 1, Away 1")
            statCard(title: "Injuries & Suspensions", placeholder: "3 Players Out")
        }
        .padding()
    }
    
    private func statCard(title: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            HStack {
                Spacer()
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private var resultMarket: some View {
        VStack(spacing: 12) {
            marketOption(label: "\(fixture.homeTeam) Win", odds: fixture.odds.home) {
                selectAndDismiss(team: fixture.homeTeam, odds: fixture.odds.home, logo: fixture.homeLogoUrl)
            }
            marketOption(label: "Draw", odds: fixture.odds.draw) {
                selectAndDismiss(team: "Draw", odds: fixture.odds.draw, logo: fixture.homeLogoUrl)
            }
            marketOption(label: "\(fixture.awayTeam) Win", odds: fixture.odds.away) {
                selectAndDismiss(team: fixture.awayTeam, odds: fixture.odds.away, logo: fixture.awayLogoUrl)
            }
        }
    }
    
    private var bttsMarket: some View {
        VStack(spacing: 12) {
            if let yes = fixture.odds.bttsYes, let no = fixture.odds.bttsNo {
                marketOption(label: "BTTS - Yes", odds: yes) {
                    selectAndDismiss(team: "BTTS - Yes", odds: yes, logo: fixture.homeLogoUrl)
                }
                marketOption(label: "BTTS - No", odds: no) {
                    selectAndDismiss(team: "BTTS - No", odds: no, logo: fixture.homeLogoUrl)
                }
            } else {
                Text("Markets not available for this match").foregroundStyle(.secondary)
            }
        }
    }
    
    private var totalGoalsMarket: some View {
        VStack(spacing: 12) {
            if let over = fixture.odds.over25, let under = fixture.odds.under25 {
                marketOption(label: "Over 2.5 Goals", odds: over) {
                    selectAndDismiss(team: "Over 2.5 Goals", odds: over, logo: fixture.homeLogoUrl)
                }
                marketOption(label: "Under 2.5 Goals", odds: under) {
                    selectAndDismiss(team: "Under 2.5 Goals", odds: under, logo: fixture.homeLogoUrl)
                }
            } else {
                Text("Markets not available for this match").foregroundStyle(.secondary)
            }
        }
    }
    
    private func marketOption(label: String, odds: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body.bold())
                Spacer()
                Text(odds.formatted())
                    .font(.body.monospacedDigit().bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func selectAndDismiss(team: String, odds: Double, logo: String?) {
        onSelect(team, odds, logo)
        dismiss()
    }
}
