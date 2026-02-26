import Foundation

struct LeagueConstants {
    struct LeagueInfo: Hashable, Identifiable {
        let id: Int
        let name: String
        let country: String
    }

    static let supportedLeagues: [LeagueInfo] = [
        LeagueInfo(id: 39, name: "Premier League", country: "England"),
        LeagueInfo(id: 40, name: "Championship", country: "England"),
        LeagueInfo(id: 41, name: "League One", country: "England"),
        LeagueInfo(id: 42, name: "League Two", country: "England"),
        LeagueInfo(id: 140, name: "La Liga", country: "Spain"),
        LeagueInfo(id: 135, name: "Serie A", country: "Italy"),
        LeagueInfo(id: 78, name: "Bundesliga", country: "Germany"),
        LeagueInfo(id: 61, name: "Ligue 1", country: "France"),
        LeagueInfo(id: 45, name: "FA Cup", country: "England"),
        LeagueInfo(id: 2, name: "Champions League", country: "World"),
        LeagueInfo(id: 3, name: "Europa League", country: "World"),
        LeagueInfo(id: 848, name: "Europa Conference League", country: "World")
    ]
    
    static func getID(for name: String) -> Int? {
        // Handle legacy variations
        if name == "League 1" { return 41 }
        if name == "League 2" { return 42 }
        
        return supportedLeagues.first { $0.name == name }?.id
    }
}
