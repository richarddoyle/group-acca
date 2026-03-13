import SwiftUI

struct SelectionRow: View {
    @EnvironmentObject var badgeManager: GroupBadgeManager
    let selection: Selection
    let memberName: String?
    let avatarUrl: String?
    let isLocked: Bool
    var showMatchStatus: Bool = true // defaults to true
    var hideBadge: Bool = false // defaults to false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Line 1: Member Name & Icon (Top Left, Tight Padding)
            if memberName != nil || avatarUrl != nil {
                HStack(spacing: 6) {
                    ProfileImage(url: avatarUrl, size: 24)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    
                    if let memberName = memberName {
                        Text("\(memberName)\(hideBadge ? "" : (badgeManager.emoji(for: selection.memberId, context: .general).map { " \($0)" } ?? ""))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if selection.isPaid {
                        Text("Paid")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.gray)
                    }
                }
            }
            
            // Line 2: Pick Name and Outcome
            HStack(spacing: 12) {
                if selection.teamName != "Pending" {
                    Image(systemName: marketIcon)
                        .foregroundStyle(.secondary)
                }
                    
                Text(selection.teamName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if selection.outcome != .pending {
                    SelectionOutcomeBadge(outcome: selection.outcome)
                }
            }
            
            // Line 3: Club Badges, Fixture, and Match Status
            if selection.teamName != "Pending" {
                HStack {
                    HStack(spacing: 4) {
                        // Home Team Logo
                        if let homeLogoUrl = selection.homeTeamLogoUrl {
                            ClubBadge(url: homeLogoUrl, size: 16)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
                        } else if let teamLogo = selection.teamLogoUrl, selection.teamName != selection.awayTeamName {
                             // Fallback for legacy picks (home team or market pick)
                             ClubBadge(url: teamLogo, size: 16)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
                        }
                        
                        Text(selection.homeTeamName ?? (selection.teamName.contains("Away") ? "Home" : selection.teamName))
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        if let home = selection.homeScore, let away = selection.awayScore {
                            Text("\(home) - \(away)")
                                .font(.subheadline) // Removed .bold()
                                .monospacedDigit()
                        } else {
                            Text("vs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Away Team Logo
                        if let awayLogoUrl = selection.awayTeamLogoUrl {
                            ClubBadge(url: awayLogoUrl, size: 16)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
                        } else if let teamLogo = selection.teamLogoUrl, selection.teamName == selection.awayTeamName {
                             // Fallback for legacy picks (away team pick)
                             ClubBadge(url: teamLogo, size: 16)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
                        }
                        
                        Text(selection.awayTeamName ?? (selection.teamName == selection.homeTeamName ? "Away" : (selection.teamName.contains("Win") ? "Away" : selection.teamName)))
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if showMatchStatus {
                        Group {
                            if selection.matchStatus == "FT" {
                                Text("Final")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else if let status = selection.matchStatus, status != "NS" {
                                Text("Live (\(status))")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            } else if let kickoff = selection.kickoffTime {
                                Text(kickoff, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
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
