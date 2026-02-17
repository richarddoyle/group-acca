import Foundation

struct Competition: Identifiable, Hashable {
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

struct MatchOdds: Hashable {
    let home: Double
    let draw: Double
    let away: Double
}

struct Fixture: Identifiable, Hashable {
    let id: UUID
    let apiId: Int?
    let homeTeam: String
    let awayTeam: String
    let date: Date
    let competition: Competition
    let status: String
    let odds: MatchOdds
    
    var timeString: String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    init(id: UUID = UUID(), apiId: Int? = nil, homeTeam: String, awayTeam: String, date: Date, competition: Competition, status: String = "NS", odds: MatchOdds) {
        self.id = id
        self.apiId = apiId
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.date = date
        self.competition = competition
        self.status = status
        self.odds = odds
    }
}

actor MockData {
    static let shared = MockData()
    
    let competitions: [Competition] = [
        Competition(name: "Premier League", country: "England"),
        Competition(name: "La Liga", country: "Spain"),
        Competition(name: "Serie A", country: "Italy"),
        Competition(name: "Bundesliga", country: "Germany"),
        Competition(name: "Ligue 1", country: "France"),
        Competition(name: "Champions League", country: "Europe")
    ]
    
    func getFixtures(for date: Date) -> [Competition: [Fixture]] {
        // Deterministic mock generation based on date
        var fixturesByComp: [Competition: [Fixture]] = [:]
        
        let calendar = Calendar.current
        let dayComponent = calendar.component(.day, from: date)
        
        // Random-ish but consistent count based on day
        let seed = dayComponent % 3
        
        for comp in competitions {
            // Some comps only have games on certain "seeds" to vary the list
            if (comp.name == "Champions League" && (dayComponent % 2 != 0)) { continue }
            
            var compsFixtures: [Fixture] = []
            let matchCount = Int.random(in: 1...3) // Mock 1-3 games per comp
            
            for i in 0..<matchCount {
                let home = generateTeamName(for: comp, index: i * 2)
                let away = generateTeamName(for: comp, index: i * 2 + 1)
                
                // Random time between 12:00 and 22:00
                let hour = Int.random(in: 12...21)
                let minute = [0, 15, 30, 45].randomElement()!
                let fixtureDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
                
                let fixture = Fixture(
                    // default UUID
                    homeTeam: home,
                    awayTeam: away,
                    date: fixtureDate,
                    competition: comp,
                    odds: MatchOdds(
                        home: Double.random(in: 1.5...5.0),
                        draw: Double.random(in: 2.5...4.5),
                        away: Double.random(in: 1.5...5.0)
                    )
                )
                compsFixtures.append(fixture)
            }
            
            if !compsFixtures.isEmpty {
                fixturesByComp[comp] = compsFixtures.sorted { $0.date < $1.date }
            }
        }
        
        return fixturesByComp
    }
    
    private func generateTeamName(for competition: Competition, index: Int) -> String {
        let pl = ["Arsenal", "Aston Villa", "Bournemouth", "Brentford", "Brighton", "Chelsea", "Crystal Palace", "Everton", "Fulham", "Liverpool", "Luton", "Man City", "Man Utd", "Newcastle", "Nottm Forest", "Sheffield Utd", "Spurs", "West Ham", "Wolves"]
        let es = ["Real Madrid", "Barcelona", "Atletico Madrid", "Sevilla", "Real Sociedad", "Betis", "Villarreal", "Valencia"]
        let it = ["Inter", "Milan", "Juventus", "Napoli", "Roma", "Lazio", "Atalanta", "Fiorentina"]
        let de = ["Bayern", "Dortmund", "Leverkusen", "Leipzig", "Stuttgart", "Frankfurt"]
        let fr = ["PSG", "Monaco", "Marseille", "Lille", "Lens", "Rennes"]
        
        let source: [String]
        switch competition.name {
        case "Premier League": source = pl
        case "La Liga": source = es
        case "Serie A": source = it
        case "Bundesliga": source = de
        case "Ligue 1": source = fr
        default: source = pl + es // Fallback
        }
        
        return source[index % source.count]
    }
}
