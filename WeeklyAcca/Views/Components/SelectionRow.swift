import SwiftUI

struct SelectionRow: View {
    let selection: Selection
    let avatarUrl: String?
    let isLocked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Top Section (Steps 1-5)
            HStack(spacing: 12) {
                // 1. Profile Picture
                ProfileImage(url: avatarUrl, size: 40)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                
                // 2. Club Badge
                if let logo = selection.teamLogoUrl {
                    ClubBadge(url: logo, size: 40)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // 3. Header: Pick
                    Text(selection.teamName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // 4. Competition
                    Text(selection.league)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 5. Odds
                    Text("@ \(selection.odds.formatted())")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
            }
            
            // 6. Dividing Line
            Divider()
                .background(Color.secondary.opacity(0.2))
            
            // 7. Results Section
            HStack {
                // [Home Team] 2 vs 1 [Away Team]
                HStack(spacing: 4) {
                    Text(selection.homeTeamName ?? (selection.teamName.contains("Away") ? "Home" : selection.teamName))
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    if let home = selection.homeScore, let away = selection.awayScore {
                        Text("\(home) - \(away)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    } else {
                        Text("vs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(selection.awayTeamName ?? (selection.teamName == selection.homeTeamName ? "Away" : (selection.teamName.contains("Win") ? "Away" : selection.teamName)))
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status Area: Won/Lost + Final/Live/Time
                HStack(spacing: 8) {
                    if selection.outcome != .pending {
                        SelectionOutcomeBadge(outcome: selection.outcome)
                    }
                    
                    Group {
                        if selection.matchStatus == "FT" {
                            Text("Final")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        } else if let status = selection.matchStatus, status != "NS" {
                            Text("Live (\(status))")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        } else if let kickoff = selection.kickoffTime {
                            Text(kickoff, style: .time)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4) // Subtle horizontal breathing room
    }
    
    private var marketIcon: String {
        if selection.teamName.contains("BTTS") { return "arrow.up.arrow.down.circle" }
        if selection.teamName.contains("Goals") { return "number.circle" }
        if selection.teamName == "Draw" { return "equal.circle" }
        return "star.circle"
    }
    
    private var statusColor: Color {
        if selection.matchStatus == "FT" { return .secondary }
        return .red // Live
    }
}
