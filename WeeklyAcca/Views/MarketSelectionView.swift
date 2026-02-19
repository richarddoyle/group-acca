import SwiftUI

struct MarketSelectionView: View {
    let fixture: Fixture
    let onSelect: (String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(spacing: 8) {
                        Text(fixture.timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(fixture.homeTeam)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            Text("vs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            Text(fixture.awayTeam)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                
                // Result Market
                Section("Result") {
                    MarketButton(label: "\(fixture.homeTeam) to Win", odds: fixture.odds.home) {
                        selectAndDismiss(team: fixture.homeTeam, odds: fixture.odds.home)
                    }
                    
                    MarketButton(label: "Draw", odds: fixture.odds.draw) {
                        selectAndDismiss(team: "Draw - \(fixture.homeTeam) vs \(fixture.awayTeam)", odds: fixture.odds.draw)
                    }
                    
                    MarketButton(label: "\(fixture.awayTeam) to Win", odds: fixture.odds.away) {
                        selectAndDismiss(team: fixture.awayTeam, odds: fixture.odds.away)
                    }
                }
                
                // Both Teams To Score Market
                if let yes = fixture.odds.bttsYes, let no = fixture.odds.bttsNo {
                    Section("Both Teams To Score") {
                        MarketButton(label: "Yes", odds: yes) {
                            selectAndDismiss(team: "BTTS - Yes (\(fixture.homeTeam) vs \(fixture.awayTeam))", odds: yes)
                        }
                        
                        MarketButton(label: "No", odds: no) {
                            selectAndDismiss(team: "BTTS - No (\(fixture.homeTeam) vs \(fixture.awayTeam))", odds: no)
                        }
                    }
                }
            }
            .navigationTitle("Select Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func selectAndDismiss(team: String, odds: Double) {
        onSelect(team, odds)
        dismiss()
    }
}

struct MarketButton: View {
    let label: String
    let odds: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(odds.formatted())
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
            }
        }
    }
}
