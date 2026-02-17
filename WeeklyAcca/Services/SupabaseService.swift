import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    // Replace with your actual project URL and Anon Key
    private let supabaseURL = URL(string: "https://pbjmyzpbxperewnqwozn.supabase.co")!
    private let supabaseKey = "sb_publishable_tPmGReQIql1l32FhggOJEA_KPpq4U4R"
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    // MARK: - User Management
    var currentUserId: UUID {
        if let savedString = UserDefaults.standard.string(forKey: "currentUserID"),
           let uuid = UUID(uuidString: savedString) {
            return uuid
        }
        
        // Generate new ID if none exists
        let newID = UUID()
        UserDefaults.standard.set(newID.uuidString, forKey: "currentUserID")
        return newID
    }
    
    // MARK: - Auth
    // ... auth methods
    
    // MARK: - Database Methods
    
    // Create a new betting group
    func createGroup(name: String, stake: Double) async throws -> BettingGroup {
        let group = BettingGroup(
            id: UUID(),
            name: name,
            stakePerPerson: stake,
            joinCode: String(UUID().uuidString.prefix(6)).uppercased(),
            createdAt: Date()
        )
        
        try await client.database
            .from("betting_groups")
            .insert(group)
            .execute()
        
        return group
    }
    
    // Fetch user's groups (via member table)
    // Note: This requires complex joining or two queries. Simplified for now to just fetch all groups user is in.
    func fetchGroups(for userId: UUID) async throws -> [BettingGroup] {
        // 1. Get member records for this user
        let members: [Member] = try await client.database
            .from("members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let groupIds = members.map { $0.groupId }
        
        if groupIds.isEmpty { return [] }
        
        // 2. Fetch groups
        let groups: [BettingGroup] = try await client.database
            .from("betting_groups")
            .select()
            .in("id", value: groupIds)
            .execute()
            .value
            
        return groups
    }
    
    // Fetch members of a group
    func fetchMembers(for groupId: UUID) async throws -> [Member] {
        let members: [Member] = try await client.database
            .from("members")
            .select()
            .eq("group_id", value: groupId)
            .execute()
            .value
        return members
    }
    
    // Join a group by code
    func joinGroup(code: String, userName: String, userId: UUID) async throws -> BettingGroup {
        // 1. Find group
        let groups: [BettingGroup] = try await client.database
            .from("betting_groups")
            .select()
            .eq("join_code", value: code.uppercased())
            .execute()
            .value
        
        guard let group = groups.first else {
            throw NSError(domain: "Supabase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid Join Code"])
        }
        
        // 2. Create member
        let member = Member(
            id: UUID(),
            groupId: group.id,
            name: userName,
            balance: 0.0,
            joinedAt: Date(),
            userId: userId
        )
        
        try await client.database
            .from("members")
            .insert(member)
            .execute()
            
        return group
    }
    
    // Fetch Weeks (Accas) for a group
    func fetchWeeks(groupId: UUID) async throws -> [Week] {
        let weeks: [Week] = try await client.database
            .from("accas") // Table is 'accas' but model is 'Week' (mapped in CodingKeys?)
            .select() // Add relationships: *, selections:selections(*) ?
            .eq("group_id", value: groupId)
            .order("week_number", ascending: false) // Latest first
            .execute()
            .value
        return weeks
    }
    
    // Create a new Week
    func createWeek(week: Week) async throws {
        try await client.database
            .from("accas")
            .insert(week)
            .execute()
    }
    
    // Fetch Selections for a week
    func fetchSelections(weekId: UUID) async throws -> [Selection] {
         let selections: [Selection] = try await client.database
            .from("selections")
            .select()
            .eq("acca_id", value: weekId)
            .execute()
            .value
        return selections
    }
    
    // Submit/Update Selection
    func saveSelection(_ selection: Selection) async throws {
        try await client.database
            .from("selections")
            .upsert(selection)
            .execute()
    }
}
