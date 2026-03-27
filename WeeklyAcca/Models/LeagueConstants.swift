import Foundation

struct LeagueConstants {
    struct LeagueInfo: Hashable, Identifiable {
        let id: Int
        let name: String
        let country: String
    }

    static let supportedLeagues: [LeagueInfo] = [
        LeagueInfo(id: 39, name: "Premier League", country: "England"),
        LeagueInfo(id: 2, name: "Champions League", country: "World"),
        LeagueInfo(id: 3, name: "Europa League", country: "World"),
        LeagueInfo(id: 848, name: "Europa Conference League", country: "World"),
        LeagueInfo(id: 1,   name: "World Cup",                         country: "World"),
        LeagueInfo(id: 4,   name: "Euro Championship",                 country: "World"),
        LeagueInfo(id: 5,   name: "UEFA Nations League",               country: "World"),
        LeagueInfo(id: 10,  name: "Friendlies",                        country: "World"),
        LeagueInfo(id: 32,  name: "World Cup - Qualification Europe",  country: "World"),
        LeagueInfo(id: 960, name: "Euro Championship - Qualification", country: "World"),
        LeagueInfo(id: 40, name: "Championship", country: "England"),
        LeagueInfo(id: 41, name: "League One", country: "England"),
        LeagueInfo(id: 42, name: "League Two", country: "England"),
        LeagueInfo(id: 140, name: "La Liga", country: "Spain"),
        LeagueInfo(id: 135, name: "Serie A", country: "Italy"),
        LeagueInfo(id: 78, name: "Bundesliga", country: "Germany"),
        LeagueInfo(id: 61, name: "Ligue 1", country: "France"),
        LeagueInfo(id: 45, name: "FA Cup", country: "England"),
        LeagueInfo(id: 179, name: "Scottish Premiership", country: "Scotland"),
        LeagueInfo(id: 180, name: "Scottish Championship", country: "Scotland"),
        LeagueInfo(id: 183, name: "Scottish League 1", country: "Scotland"),
        LeagueInfo(id: 184, name: "Scottish League 2", country: "Scotland")
    ]
    
    static func getID(for name: String) -> Int? {
        // Handle legacy variations
        if name == "League 1" { return 41 }
        if name == "League 2" { return 42 }
        
        return supportedLeagues.first { $0.name == name }?.id
    }
}
