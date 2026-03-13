import Foundation
import SwiftUI
import Combine

enum GroupBadgeContext {
    case general
    case winningPicksLeaderboard
    case totalWonLeaderboard
    case otherLeaderboard
}

@MainActor
class GroupBadgeManager: ObservableObject {
    @Published var streakBadges: [UUID: String] = [:]
    @Published var topWinners: Set<UUID> = []
    @Published var topEarners: Set<UUID> = []
    
    // Legacy mapping to prevent broken code before all views are updated
    @Published var badges: [UUID: String] = [:]
    
    func loadBadges(for group: BettingGroup) async {
        do {
            let fetchedMembers = try await SupabaseService.shared.fetchMembers(for: group.id)
            let memberIds = fetchedMembers.map { $0.id }
            let selections = try await SupabaseService.shared.fetchMySelections(memberIds: memberIds)
            
            var localWinCounts: [UUID: Int] = [:]
            var currentWinStreaks: [UUID: Int] = [:]
            var localTotalWinnings: [UUID: Double] = [:]
            
            for member in fetchedMembers {
                let memberSelections = selections.filter { $0.memberId == member.id && ($0.outcome == .win || $0.outcome == .loss) }
                let winningPicks = memberSelections.filter { $0.outcome == .win }
                
                localWinCounts[member.id] = winningPicks.count
                
                var currentWinStreakCount = 0
                
                let sortedResolved = memberSelections.sorted { a, b in
                    let dateA = a.kickoffTime ?? Date.distantPast
                    let dateB = b.kickoffTime ?? Date.distantPast
                    if dateA == dateB {
                        return a.id.uuidString < b.id.uuidString
                    }
                    return dateA < dateB
                }
                for pick in sortedResolved {
                    if pick.outcome == .win {
                        currentWinStreakCount += 1
                    } else if pick.outcome == .loss {
                        currentWinStreakCount = 0
                    }
                }
                currentWinStreaks[member.id] = currentWinStreakCount
                
                let winnings = winningPicks.reduce(0.0) { sum, pick in
                    sum + (group.stakePerPerson * pick.odds)
                }
                localTotalWinnings[member.id] = winnings
            }
            
            var maxWins = 0
            for count in localWinCounts.values {
                if count > maxWins { maxWins = count }
            }
            let topWinners = maxWins > 0 ? localWinCounts.filter { $0.value == maxWins }.map { $0.key } : []
            
            var maxWinnings = 0.0
            for w in localTotalWinnings.values {
                if w > maxWinnings { maxWinnings = w }
            }
            let topEarners = maxWinnings > 0 ? localTotalWinnings.filter { $0.value >= maxWinnings - 0.01 }.map { $0.key } : []
            
            var newStreakBadges: [UUID: String] = [:]
            var newBadges: [UUID: String] = [:]
            
            for memberId in memberIds {
                let streak = currentWinStreaks[memberId] ?? 0
                if streak >= 10 {
                    newStreakBadges[memberId] = "🐐"
                } else if streak >= 5 {
                    newStreakBadges[memberId] = "🚀"
                } else if streak >= 3 {
                    newStreakBadges[memberId] = "🔥"
                }
                
                // Keep legacy badge map working (where crown overrides)
                if topWinners.contains(memberId) {
                    newBadges[memberId] = "👑"
                } else if let sb = newStreakBadges[memberId] {
                    newBadges[memberId] = sb
                }
            }
            
            self.topWinners = Set(topWinners)
            self.topEarners = Set(topEarners)
            self.streakBadges = newStreakBadges
            self.badges = newBadges
        } catch {
            print("Failed to load badges: \(error)")
        }
    }
    
    func emoji(for memberId: UUID, context: GroupBadgeContext) -> String? {
        let isTopWinner = topWinners.contains(memberId)
        let isTopEarner = topEarners.contains(memberId)
        let streak = streakBadges[memberId]
        
        var combinedBadges: [String] = []
        
        // Assemble base tokens based on context
        switch context {
        case .general:
            if isTopWinner { combinedBadges.append("👑") }
            if isTopEarner { combinedBadges.append("💰") }
        case .winningPicksLeaderboard:
            if isTopWinner { combinedBadges.append("👑") }
            if isTopEarner { combinedBadges.append("💰") }
        case .totalWonLeaderboard:
            if isTopEarner { combinedBadges.append("💰") }
            if isTopWinner { combinedBadges.append("👑") }
        case .otherLeaderboard:
            break
        }
        
        if let s = streak {
            combinedBadges.append(s)
        }
        
        if combinedBadges.isEmpty {
            return nil
        }
        
        return combinedBadges.joined(separator: " ")
    }
}
