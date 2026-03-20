import Foundation
import SwiftUI
import SwiftUI

// MARK: - App Models (Supabase)

struct Profile: Codable, Identifiable {
    let id: UUID
    var username: String
    var avatarUrl: String?
    let createdAt: Date
    var apnsToken: String?
    var monzoUsername: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case apnsToken = "apns_token"
        case monzoUsername = "monzo_username"
    }
}

struct BettingGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var avatarUrl: String?
    let stakePerPerson: Double
    let joinCode: String
    let adminId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
        case stakePerPerson = "stake_per_person"
        case joinCode = "join_code"
        case adminId = "admin_id"
        case createdAt = "created_at"
    }
}

struct Member: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let name: String
    let balance: Double
    let joinedAt: Date
    let userId: UUID? 
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case name
        case balance
        case joinedAt = "joined_at"
        case userId = "user_id"
    }
}

// MARK: - Enums

enum WeekStatus: String, Codable {
    case pending = "Pending"
    case won = "Won"
    case lost = "Lost"
}

enum SelectionOutcome: String, Codable, CaseIterable {
    case pending = "Pending"
    case win = "Win"
    case loss = "Loss"
    case void = "Void"
}

// Renamed from 'Acca' to 'Week' to minimize refactoring, or we can embrace 'Acca'
struct Week: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let weekNumber: Int
    let title: String
    let startDate: Date
    let endDate: Date
    let sport: String
    let selectedLeagues: [String]
    var stakePerPick: Double?
    var maxPicksPerMember: Int?
    let isSettled: Bool
    var status: WeekStatus
    var monzoUsername: String?
    let creatorId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case weekNumber = "week_number"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case sport
        case selectedLeagues = "selected_leagues"
        case stakePerPick = "stake_per_pick"
        case maxPicksPerMember = "max_picks_per_member"
        case isSettled = "is_settled"
        case status
        case monzoUsername = "monzo_username"
        case creatorId = "creator_id"
    }
}

struct Selection: Codable, Identifiable, Hashable {
    let id: UUID
    let accaId: UUID
    let memberId: UUID
    var teamName: String
    var league: String
    var outcome: SelectionOutcome 
    var odds: Double
    var kickoffTime: Date?
    var homeScore: Int?
    var awayScore: Int?
    var matchStatus: String? // e.g., "NS", "FT"
    var teamLogoUrl: String?
    var homeTeamName: String?
    var awayTeamName: String?
    var fixtureId: Int?
    var homeTeamLogoUrl: String?
    var awayTeamLogoUrl: String?
    var isPaid: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case accaId = "acca_id"
        case memberId = "member_id"
        case teamName = "team_name"
        case league
        case outcome
        case odds
        case kickoffTime = "kickoff_time"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case matchStatus = "match_status"
        case teamLogoUrl = "team_logo_url"
        case homeTeamName = "home_team_name"
        case awayTeamName = "away_team_name"
        case fixtureId = "fixture_id"
        case homeTeamLogoUrl = "home_team_logo_url"
        case awayTeamLogoUrl = "away_team_logo_url"
        case isPaid = "is_paid"
    }
}

extension Week {
    var isOpen: Bool {
        Date() < startDate
    }
    
    var isLocked: Bool {
        !isOpen
    }
}

// Helper struct for display to avoid complex logic in view
struct MemberSelectionDisplay: Identifiable {
    var id: UUID { member.id }
    let member: Member
    let selections: [Selection]
    let avatarUrl: String?
}
