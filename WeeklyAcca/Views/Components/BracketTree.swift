import SwiftUI

struct BracketTree: View {
    let fixtures: [Fixture]
    let highlightTeam: String
    
    // Group fixtures by their round
    private var stages: [(name: String, matches: [Fixture])] {
        let grouped = Dictionary(grouping: fixtures) { $0.round ?? "Unknown Round" }
        
        // Define a custom sort order for typical knockout rounds
        let roundOrder: [String: Int] = [
            "round of 16": 1,
            "quarter-final": 2,
            "semi-final": 3,
            "3rd place final": 4,
            "final": 5
        ]
        
        return grouped.map { (name: $0.key, matches: $0.value.sorted(by: { $0.date < $1.date })) }
            .sorted { (a, b) in
                let aKey = a.name.lowercased()
                let bKey = b.name.lowercased()
                
                // Find matching order based on substring
                let aOrder = roundOrder.first { aKey.contains($0.key) }?.value ?? 0
                let bOrder = roundOrder.first { bKey.contains($0.key) }?.value ?? 0
                
                if aOrder != bOrder {
                    return aOrder < bOrder
                }
                
                return a.name < b.name
            }
    }
    
    var body: some View {
        if stages.isEmpty {
            Text("No bracket data available.")
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 32) {
                    ForEach(stages, id: \.name) { stage in
                        VStack(spacing: 16) {
                            Text(stage.name.capitalized)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            ForEach(stage.matches) { match in
                                BracketMatchView(fixture: match, highlightTeam: highlightTeam)
                            }
                            
                            Spacer()
                        }
                        .frame(width: 240)
                    }
                }
                .padding()
            }
        }
    }
}

private struct BracketMatchView: View {
    let fixture: Fixture
    let highlightTeam: String
    
    var body: some View {
        let isHomeHighlight = fixture.homeTeam == highlightTeam
        let isAwayHighlight = fixture.awayTeam == highlightTeam
        let isMatchHighlighted = isHomeHighlight || isAwayHighlight
        
        VStack(spacing: 0) {
            // Home Team Row
            teamRow(
                name: fixture.homeTeam,
                logoUrl: fixture.homeLogoUrl,
                score: fixture.homeGoals,
                isHighlight: isHomeHighlight,
                isWinner: isWinner(team: .home)
            )
            
            Divider()
                .padding(.leading, 40)
            
            // Away Team Row
            teamRow(
                name: fixture.awayTeam,
                logoUrl: fixture.awayLogoUrl,
                score: fixture.awayGoals,
                isHighlight: isAwayHighlight,
                isWinner: isWinner(team: .away)
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMatchHighlighted ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMatchHighlighted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private enum TeamStatus {
        case home, away
    }
    
    private func isWinner(team: TeamStatus) -> Bool {
        guard let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else {
            return false // Match hasn't finished or lacks score
        }
        
        if team == .home {
            return homeGoals > awayGoals
        } else {
            return awayGoals > homeGoals
        }
    }
    
    private func teamRow(name: String, logoUrl: String?, score: Int?, isHighlight: Bool, isWinner: Bool) -> some View {
        HStack(spacing: 12) {
            ClubBadge(url: logoUrl, size: 24)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(isHighlight ? .bold : .regular)
                .foregroundStyle(isWinner ? .primary : (fixture.status == "FT" ? .secondary : .primary))
                .lineLimit(1)
            
            Spacer()
            
            if let targetScore = score, fixture.status != "NS" {
                Text("\(targetScore)")
                    .font(.subheadline)
                    .fontWeight(isWinner ? .bold : .regular)
                    .foregroundStyle(isWinner ? .primary : .secondary)
            } else if fixture.status == "NS" || fixture.status == "TBD" {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
