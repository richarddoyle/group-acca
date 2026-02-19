import Foundation

class APIService {
    static let shared = APIService()
    private let apiKey = "f9c66d71cf81e7d8f1960a1bd4d0cbc4"
    private let baseURL = "https://v3.football.api-sports.io"
    
    private init() {}
    
    func fetchFixtures(date: Date) async throws -> [Competition: [Fixture]] {
        let dateString = formatDate(date)
        
        // Ensure URL is valid
        guard let url = URL(string: "\(baseURL)/fixtures?date=\(dateString)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        request.addValue("v3.football.api-sports.io", forHTTPHeaderField: "x-rapidapi-host")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Decode logic
        let response = try JSONDecoder().decode(APIFixtureResponse.self, from: data)
        
        // Fallback to Mock Data if API returns no results (likely due to free plan limits)
        if response.response.isEmpty {
            print("API returned 0 fixtures. Falling back to Mock Data.")
            return await MockData.shared.getFixtures(for: date)
        }
        
        // Map to Domain Models
        return mapToDomain(response: response)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
                bttsNo: Double.random(in: 1.5...2.2).rounded(toPlaces: 2)
            )
            
            let fixture = Fixture(
                apiId: item.fixture.id,
                homeTeam: item.teams.home.name,
                awayTeam: item.teams.away.name,
                date: parseDate(item.fixture.date),
                competition: competition,
                status: item.fixture.status.short, // e.g., "NS", "FT"
                odds: mockOdds
            )
            
            if result[competition] != nil {
                result[competition]?.append(fixture)
            } else {
                result[competition] = [fixture]
            }
        }
        
        return result
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
    let response: [APIFixtureItem]
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
