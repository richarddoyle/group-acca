import Foundation

// MARK: - App Models (Supabase)

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
    }
}

struct BettingGroup: Codable, Identifiable {
    let id: UUID
    let name: String
    let stakePerPerson: Double
    let joinCode: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stakePerPerson = "stake_per_person"
        case joinCode = "join_code"
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
    let allowEarlyKickoffs: Bool
    let isSettled: Bool
    let status: WeekStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case weekNumber = "week_number"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case sport
        case selectedLeagues = "selected_leagues"
        case allowEarlyKickoffs = "allow_early_kickoffs"
        case isSettled = "is_settled"
        case status
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case accaId = "acca_id"
        case memberId = "member_id"
        case teamName = "team_name"
        case league
        case outcome
        case odds
    }
}
