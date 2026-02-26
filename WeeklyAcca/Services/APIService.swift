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
            urlString += "&league=\(leagueId)"
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
            print("API returned 0 fixtures for this query (results: \(apiResponse.results)).")
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
                homeTeam: item.teams.home.name,
                awayTeam: item.teams.away.name,
                date: parseDate(item.fixture.date),
                competition: competition,
                status: item.fixture.status.short, // e.g., "NS", "FT"
                odds: mockOdds,
                homeLogoUrl: item.teams.home.logo,
                awayLogoUrl: item.teams.away.logo,
                homeGoals: item.goals.home,
                awayGoals: item.goals.away
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
