import Foundation

struct Competition: Identifiable, Hashable, Sendable {
    let id: UUID
    let apiId: Int?
    let name: String
    let country: String
    
    init(id: UUID = UUID(), apiId: Int? = nil, name: String, country: String) {
        self.id = id
        self.apiId = apiId
        self.name = name
        self.country = country
    }
}

struct MatchOdds: Hashable, Sendable {
    let home: Double
    let draw: Double
    let away: Double
    var bttsYes: Double?
    var bttsNo: Double?
    var over25: Double?
    var under25: Double?
}

struct Fixture: Identifiable, Hashable, Sendable {
    let id: UUID
    let apiId: Int?
    let homeTeamId: Int?
    let awayTeamId: Int?
    let homeTeam: String
    let awayTeam: String
    let date: Date
    let competition: Competition
    let status: String
    let odds: MatchOdds
    let homeLogoUrl: String?
    let awayLogoUrl: String?
    let homeGoals: Int?
    let awayGoals: Int?
    let round: String?
    
    var timeString: String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    init(id: UUID = UUID(), apiId: Int? = nil, homeTeamId: Int? = nil, awayTeamId: Int? = nil, homeTeam: String, awayTeam: String, date: Date, competition: Competition, status: String = "NS", odds: MatchOdds, homeLogoUrl: String? = nil, awayLogoUrl: String? = nil, homeGoals: Int? = nil, awayGoals: Int? = nil, round: String? = nil) {
        self.id = id
        self.apiId = apiId
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.date = date
        self.competition = competition
        self.status = status
        self.odds = odds
        self.homeLogoUrl = homeLogoUrl
        self.awayLogoUrl = awayLogoUrl
        self.homeGoals = homeGoals
        self.awayGoals = awayGoals
        self.round = round
    }
    
    // Check if the fixture is part of a knockout phase based on round string
    var isKnockout: Bool {
        guard let round = round?.lowercased() else { return false }
        return round.contains("round of") || 
               round.contains("quarter-final") || 
               round.contains("semi-final") || 
               round.contains("final") || 
               round.contains("knockout") ||
               round.contains("play-off")
    }
}


