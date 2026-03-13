import Foundation

class APIService {
    static let shared = APIService()
    private let apiKey = "f9c66d71cf81e7d8f1960a1bd4d0cbc4"
    private let baseURL = "https://v3.football.api-sports.io"
    
    private init() {}
    
    func fetchFixtures(date: Date, leagueId: Int? = nil) async throws -> [Competition: [Fixture]] {
        let dateString = formatDate(date)
        
        // Ensure URL is valid
        var urlString = "\(baseURL)/fixtures?date=\(dateString)"
        if let leagueId = leagueId {
            let season = getCurrentSeasonYear(for: date)
            urlString += "&league=\(leagueId)&season=\(season)"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        // No need for x-rapidapi-host when calling the direct endpoint
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("API Status Code: \(httpResponse.statusCode)")
            if let remaining = httpResponse.allHeaderFields["x-requests-remaining"] as? String {
                print("API Requests Remaining: \(remaining)")
            }
            
            if httpResponse.statusCode == 429 {
                throw NSError(domain: "APIService", code: 429, userInfo: [NSLocalizedDescriptionKey: "API Rate limit exceeded. Please try again tomorrow or upgrade your plan."])
            }
        }
        
        // Decode logic
        let apiResponse: APIFixtureResponse
        do {
            apiResponse = try JSONDecoder().decode(APIFixtureResponse.self, from: data)
        } catch let decodingError as DecodingError {
            print("Decoding Error: \(decodingError)")
            // Provide a very specific error to the UI
            var details = "Unknown decoding error"
            switch decodingError {
            case .keyNotFound(let key, _): details = "Missing key: \(key.stringValue)"
            case .typeMismatch(let type, let context): details = "Type mismatch for \(type): \(context.debugDescription)"
            case .valueNotFound(let type, let context): details = "Value not found for \(type): \(context.debugDescription)"
            case .dataCorrupted(let context): details = "Data corrupted: \(context.debugDescription)"
            @unknown default: details = "Decode error: \(decodingError.localizedDescription)"
            }
            throw NSError(domain: "APIService", code: 422, userInfo: [NSLocalizedDescriptionKey: "API Response Format Error: \(details)"])
        } catch {
            throw error
        }
        
        // Handle API Errors
        if let errors = apiResponse.errors, !errors.isEmpty {
            if let firstError = errors.values.first {
                 print("API Error: \(firstError)")
                 throw NSError(domain: "APIService", code: 429, userInfo: [NSLocalizedDescriptionKey: "API Error: \(firstError)"])
            }
        }
        
        if apiResponse.response.isEmpty {
            let resultsCount = apiResponse.results ?? 0
            print("API returned 0 fixtures for this query (results: \(resultsCount)).")
            return [:]
        }
        
        // Map to Domain Models
        return mapToDomain(response: apiResponse)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // api-sports.io requires a season parameter when filtering by league.
    // The European season typically starts in August.
    // E.g., Matches in May 2025 belong to the 2024 season. Matches in Sept 2025 belong to the 2025 season.
    func getCurrentSeasonYear(for targetDate: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: targetDate)
        let month = calendar.component(.month, from: targetDate)
        
        // If the match is before August, it belongs to the previous year's season schedule
        if month < 8 {
            return year - 1
        } else {
            return year
        }
    }
    
    private func mapToDomain(response: APIFixtureResponse) -> [Competition: [Fixture]] {
        var result: [Competition: [Fixture]] = [:]
        var competitionsCache: [Int: Competition] = [:]
        
        for item in response.response {
            // Reuse competition instance if already created for this API ID
            let competition: Competition
            if let cached = competitionsCache[item.league.id] {
                competition = cached
            } else {
                competition = Competition(apiId: item.league.id, name: item.league.name, country: item.league.country)
                competitionsCache[item.league.id] = competition
            }
            
            // Mock odds for now as they aren't in the standard fixtures endpoint freely/easily without extra calls
            // We'll randomize them slightly to look realistic
            let mockOdds = MatchOdds(
                home: Double.random(in: 1.5...4.0).rounded(toPlaces: 2),
                draw: Double.random(in: 2.5...4.5).rounded(toPlaces: 2),
                away: Double.random(in: 1.5...5.0).rounded(toPlaces: 2),
                bttsYes: Double.random(in: 1.5...2.2).rounded(toPlaces: 2),
                bttsNo: Double.random(in: 1.5...2.2).rounded(toPlaces: 2),
                over25: Double.random(in: 1.5...2.5).rounded(toPlaces: 2),
                under25: Double.random(in: 1.5...2.5).rounded(toPlaces: 2)
            )
            
            let fixture = Fixture(
                apiId: item.fixture.id,
                homeTeamId: item.teams.home.id,
                awayTeamId: item.teams.away.id,
                homeTeam: item.teams.home.name,
                awayTeam: item.teams.away.name,
                date: parseDate(item.fixture.date),
                competition: competition,
                status: item.fixture.status.short, // e.g., "NS", "FT"
                odds: mockOdds,
                homeLogoUrl: item.teams.home.logo,
                awayLogoUrl: item.teams.away.logo,
                homeGoals: item.goals.home,
                awayGoals: item.goals.away,
                round: item.league.round
            )
            
            if result[competition] != nil {
                result[competition]?.append(fixture)
            } else {
                result[competition] = [fixture]
            }
        }
        
        return result
    }
    
    // MARK: - New Endpoints (Events, Lineups, Standings, Stats)
    
    func fetchMatchEvents(fixtureId: Int) async throws -> [MatchEvent] {
        let urlString = "\(baseURL)/fixtures/events?fixture=\(fixtureId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIEventResponse.self, from: data)
        
        return response.response.map { MatchEvent(apiEvent: $0) }
    }
    
    func fetchInjuries(fixtureId: Int) async throws -> [Injury] {
        let urlString = "\(baseURL)/injuries?fixture=\(fixtureId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIInjuryResponse.self, from: data)
        
        return response.response.map { Injury(apiInjury: $0) }
    }
    
    func fetchLineups(fixtureId: Int) async throws -> [TeamLineup] {
        let urlString = "\(baseURL)/fixtures/lineups?fixture=\(fixtureId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APILineupResponse.self, from: data)
        
        return response.response.map { TeamLineup(apiLineup: $0) }
    }
    
    // Fetch last 5 fixtures for a specific team
    func fetchTeamRecentFixtures(teamId: Int) async throws -> [Fixture] {
        let urlString = "\(baseURL)/fixtures?team=\(teamId)&last=5"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIFixtureResponse.self, from: data)
        
        // Flatten the mapToDomain dictionary to just a single array of Fixtures
        let dictionary = mapToDomain(response: response)
        let fixtures = dictionary.values.flatMap { $0 }
        
        // Sort descending by date (most recent first)
        return fixtures.sorted { $0.date > $1.date }
    }
    
    // Fetch all finished fixtures for a specific league and season to locally calculate stats
    func fetchFinishedFixtures(leagueId: Int, season: Int) async throws -> [Fixture] {
        let urlString = "\(baseURL)/fixtures?league=\(leagueId)&season=\(season)&status=FT"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIFixtureResponse.self, from: data)
        
        // Flatten the mapToDomain dictionary to just a single array of Fixtures
        let dictionary = mapToDomain(response: response)
        return dictionary.values.flatMap { $0 }
    }
    
    // Fetch all knockout fixtures for a specific league and season to build the bracket
    func fetchTournamentFixtures(leagueId: Int, season: Int) async throws -> [Fixture] {
        let urlString = "\(baseURL)/fixtures?league=\(leagueId)&season=\(season)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIFixtureResponse.self, from: data)
        
        let dictionary = mapToDomain(response: response)
        let allFixtures = dictionary.values.flatMap { $0 }
        
        // Filter to only include knockout stage matches
        return allFixtures.filter { $0.isKnockout }
    }
    
    func fetchStandings(leagueId: Int, season: Int) async throws -> [LeagueStandingRow] {
        let urlString = "\(baseURL)/standings?league=\(leagueId)&season=\(season)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIStandingsResponse.self, from: data)
        
        // Return the first group of standings (usually the main table)
        guard let firstLeague = response.response.first?.league,
              let firstStandingGroup = firstLeague.standings.first else {
            return []
        }
        
        return firstStandingGroup.map { LeagueStandingRow(apiStanding: $0) }
    }
    
    func fetchTeamStatistics(leagueId: Int, season: Int, teamId: Int) async throws -> TeamStatistics {
        let urlString = "\(baseURL)/teams/statistics?league=\(leagueId)&season=\(season)&team=\(teamId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APITeamStatisticsResponse.self, from: data)
        
        guard let stats = response.response else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return TeamStatistics(apiStats: stats)
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] 
        // Try standard ISO first
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback for dates without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Extension for rounding
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - API Models
struct APIFixtureResponse: Codable {
    let results: Int?
    let errors: [String: String]?
    let response: [APIFixtureItem]

    enum CodingKeys: String, CodingKey {
        case results, errors, response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent(Int.self, forKey: .results)
        response = try container.decode([APIFixtureItem].self, forKey: .response)

        // Handle errors field being either an empty array [] or a dictionary [String: String]
        if let dict = try? container.decodeIfPresent([String: String].self, forKey: .errors) {
            errors = dict
        } else {
            // If it's not a dictionary, it's likely an empty array or missing
            errors = nil
        }
    }
}

struct APIFixtureItem: Codable {
    let fixture: APIFixtureDetails
    let league: APILeague
    let teams: APITeams
    let goals: APIGoals
}

struct APIFixtureDetails: Codable {
    let id: Int
    let date: String
    let status: APIStatus
}

struct APIStatus: Codable {
    let long: String
    let short: String
}

struct APILeague: Codable {
    let id: Int
    let name: String
    let country: String
    let round: String?
}

struct APITeams: Codable {
    let home: APITeam
    let away: APITeam
}

struct APITeam: Codable {
    let id: Int
    let name: String
    let logo: String?
    let winner: Bool?
}

struct APIGoals: Codable {
    let home: Int?
    let away: Int?
}

// MARK: - API Models (Events)
struct APIEventResponse: Codable {
    let response: [APIEventItem]
}

struct APIEventItem: Codable {
    let time: APIEventTime
    let team: APITeam
    let player: APIEventPlayer
    let assist: APIEventPlayer?
    let type: String
    let detail: String
    let comments: String?
}

struct APIEventTime: Codable {
    let elapsed: Int
    let extra: Int?
}

struct APIEventPlayer: Codable {
    let id: Int?
    let name: String?
}

// MARK: - API Models (Lineups)
struct APILineupResponse: Codable {
    let response: [APILineupItem]
}

struct APILineupItem: Codable {
    let team: APITeam
    let formation: String?
    let startXI: [APIPlayerWrapper]
    let substitutes: [APIPlayerWrapper]
}

struct APIPlayerWrapper: Codable {
    let player: APILineupPlayer
}

struct APILineupPlayer: Codable {
    let id: Int
    let name: String
    let number: Int
    let pos: String
}

// MARK: - API Models (Standings)
struct APIStandingsResponse: Codable {
    let response: [APIStandingsLeagueWrapper]
}

struct APIStandingsLeagueWrapper: Codable {
    let league: APIStandingsLeague
}

struct APIStandingsLeague: Codable {
    let id: Int
    let name: String
    let country: String
    let logo: String
    let flag: String?
    let season: Int
    let standings: [[APIStandingRow]]
}

struct APIStandingRow: Codable {
    let rank: Int
    let team: APITeam
    let points: Int
    let goalsDiff: Int
    let group: String
    let form: String?
    let status: String
    let description: String?
    let all: APIStandingRecords
}

struct APIStandingRecords: Codable {
    let played: Int
    let win: Int
    let draw: Int
    let lose: Int
    let goals: APIStandingGoals
}

struct APIStandingGoals: Codable {
    let `for`: Int
    let against: Int
}

// MARK: - API Models (Team Statistics)
struct APITeamStatisticsResponse: Codable {
    let response: APITeamStatistics?
}

struct APITeamStatistics: Codable {
    let league: APILeague
    let team: APITeam
    let form: String?
    let fixtures: APIStatsFixtures
    let goals: APIStatsGoals
    let clean_sheet: APIStatsCounters
    let failed_to_score: APIStatsCounters
}

struct APIStatsFixtures: Codable {
    let played: APIStatsCounters
    let wins: APIStatsCounters
    let draws: APIStatsCounters
    let loses: APIStatsCounters
}

struct APIStatsCounters: Codable {
    let home: Int
    let away: Int
    let total: Int
}

struct APIStatsGoals: Codable {
    let `for`: APIStatsGoalsDetail
    let against: APIStatsGoalsDetail
}

struct APIStatsGoalsDetail: Codable {
    let total: APIStatsCounters
    let average: APIStatsAverageCounters
}

struct APIStatsAverageCounters: Codable {
    let home: String
    let away: String
    let total: String
}

// MARK: - Domain Models for View Use
struct MatchEvent: Identifiable {
    let id = UUID()
    let elapsed: Int
    let extra: Int?
    let teamId: Int
    let teamName: String
    let playerName: String
    let assistName: String?
    let type: String
    let detail: String
    
    init(apiEvent: APIEventItem) {
        self.elapsed = apiEvent.time.elapsed
        self.extra = apiEvent.time.extra
        self.teamId = apiEvent.team.id
        self.teamName = apiEvent.team.name
        self.playerName = apiEvent.player.name ?? "Unknown"
        self.assistName = apiEvent.assist?.name
        self.type = apiEvent.type
        self.detail = apiEvent.detail
    }
}

struct TeamLineup {
    let teamId: Int
    let teamName: String
    let teamLogo: String?
    let formation: String
    let startingXI: [(number: Int, name: String, pos: String)]
    let subs: [(number: Int, name: String, pos: String)]
    
    init(apiLineup: APILineupItem) {
        self.teamId = apiLineup.team.id
        self.teamName = apiLineup.team.name
        self.teamLogo = apiLineup.team.logo
        self.formation = apiLineup.formation ?? "Unknown"
        self.startingXI = apiLineup.startXI.map { ($0.player.number, $0.player.name, $0.player.pos) }
        self.subs = apiLineup.substitutes.map { ($0.player.number, $0.player.name, $0.player.pos) }
    }
}

struct LeagueStandingRow: Identifiable {
    let id = UUID()
    let rank: Int
    let teamId: Int
    let teamName: String
    let teamLogo: String?
    let played: Int
    let points: Int
    let goalDifference: Int
    let form: String
    let description: String?
    
    init(apiStanding: APIStandingRow) {
        self.rank = apiStanding.rank
        self.teamId = apiStanding.team.id
        self.teamName = apiStanding.team.name
        self.teamLogo = apiStanding.team.logo
        self.played = apiStanding.all.played
        self.points = apiStanding.points
        self.goalDifference = apiStanding.goalsDiff
        self.form = apiStanding.form ?? ""
        self.description = apiStanding.description
    }
}

struct TeamStatistics {
    let form: String
    let playedTotal: Int
    let cleanSheetTotal: Int
    let failedToScoreTotal: Int
    
    init(apiStats: APITeamStatistics) {
        self.form = apiStats.form ?? ""
        self.playedTotal = apiStats.fixtures.played.total
        self.cleanSheetTotal = apiStats.clean_sheet.total
        self.failedToScoreTotal = apiStats.failed_to_score.total
    }
    
    var cleanSheetPercentage: Double {
        guard playedTotal > 0 else { return 0 }
        return Double(cleanSheetTotal) / Double(playedTotal)
    }
    
    var failedToScorePercentage: Double {
        guard playedTotal > 0 else { return 0 }
        return Double(failedToScoreTotal) / Double(playedTotal)
    }
}

// MARK: - Injury Models

struct APIPaging: Codable {
    let current: Int
    let total: Int
}

struct APIInjuryResponse: Codable {
    let get: String
    let parameters: [String: String]?
    let errors: [String: String]?
    let results: Int
    let paging: APIPaging
    let response: [APIInjuryItem]
    
    enum CodingKeys: String, CodingKey {
        case get, parameters, errors, results, paging, response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        get = try container.decode(String.self, forKey: .get)
        parameters = try container.decodeIfPresent([String: String].self, forKey: .parameters)
        results = try container.decode(Int.self, forKey: .results)
        paging = try container.decode(APIPaging.self, forKey: .paging)
        response = try container.decode([APIInjuryItem].self, forKey: .response)

        // Handle errors field being either an empty array [] or a dictionary [String: String]
        if let dictionary = try? container.decode([String: String].self, forKey: .errors) {
            self.errors = dictionary
        } else {
            // It might be an empty array [] if there are no errors
            self.errors = nil
        }
    }
}

struct APIInjuryItem: Codable {
    let player: APIInjuryPlayer
    let team: APIInjuryTeam
    let fixture: APIInjuryFixture
    let league: APIInjuryLeague
}

struct APIInjuryPlayer: Codable {
    let id: Int
    let name: String
    let type: String
    let reason: String
    let photo: String?
}

struct APIInjuryTeam: Codable {
    let id: Int
    let name: String
    let logo: String?
}

struct APIInjuryFixture: Codable {
    let id: Int
    let timezone: String
    let date: String
    let timestamp: Int
}

struct APIInjuryLeague: Codable {
    let id: Int
    let season: Int
    let name: String
    let logo: String?
}

struct Injury: Identifiable {
    let id = UUID()
    let playerId: Int
    let playerName: String
    let playerPhoto: String?
    let type: String
    let reason: String
    let teamId: Int
    let teamName: String
    let teamLogo: String?
    
    init(apiInjury: APIInjuryItem) {
        self.playerId = apiInjury.player.id
        self.playerName = apiInjury.player.name
        self.playerPhoto = apiInjury.player.photo
        self.type = apiInjury.player.type
        self.reason = apiInjury.player.reason
        self.teamId = apiInjury.team.id
        self.teamName = apiInjury.team.name
        self.teamLogo = apiInjury.team.logo
    }
}
