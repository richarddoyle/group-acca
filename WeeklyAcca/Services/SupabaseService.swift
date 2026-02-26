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
        // Prioritize Auth User
        if let user = currentUser {
            return user.id
        }
        
        // Fallback to local ID (for development/migration)
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
    // MARK: - Auth
    
    var currentUser: User? {
        client.auth.currentUser
    }
    
    // Sign In with Apple
    func signInWithApple(idToken: String, nonce: String) async throws {
        print("🔐 SupabaseService: Attempting Sign in with Apple...")
        print("🔐 ID Token length: \(idToken.count)")
        print("🔐 Nonce: \(nonce)")
        do {
            let session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            print("✅ SupabaseService: Sign in successful! User ID: \(session.user.id)")
            
            // Ensure profile exists for this user
            try await ensureProfileExists(for: session.user)
            
        } catch {
            print("❌ SupabaseService: Sign in failed with error: \(error)")
            // Print more details if it's a Supabase error
            throw error
        }
    }
    
    // Checks if a profile row exists for the user, creates one if not.
    private func ensureProfileExists(for user: User) async throws {
        // 1. Check if profile exists
        struct ProfileCheck: Decodable {
            let id: UUID
        }
        
        let existingProfile: [ProfileCheck] = try await client.database
            .from("profiles")
            .select("id")
            .eq("id", value: user.id)
            .execute()
            .value
        
        if existingProfile.isEmpty {
            print("👤 Creating new profile for user \(user.id)")
            // 2. Create profile
            // Note: We might want to store email or other info if available from metadata
            let newProfile = Profile(
                id: user.id,
                username: "User_\(String(user.id.uuidString.prefix(4)))", // Default username
                createdAt: Date()
            )
            
            try await client.database
                .from("profiles")
                .insert(newProfile)
                .execute()
            print("✅ Profile created!")
        } else {
            print("👤 Profile already exists for user \(user.id)")
        }
    }
    
    // Dev Sign In (Email/Password)
    func signInDev(email: String, password: String) async throws {
        print("🔐 SupabaseService: Attempting Dev Sign in...")
        let session = try await client.auth.signIn(email: email, password: password)
        print("✅ SupabaseService: Dev Sign in successful! User ID: \(session.user.id)")
    }
    
    // Sign Out
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Profile Management
    
    func fetchProfile(id: UUID) async throws -> Profile {
        let profile: Profile = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return profile
    }
    
    func fetchProfiles(ids: [UUID]) async throws -> [Profile] {
        if ids.isEmpty { return [] }
        let profiles: [Profile] = try await client.database
            .from("profiles")
            .select()
            .in("id", value: ids)
            .execute()
            .value
        return profiles
    }
    
    func updateProfile(_ profile: Profile) async throws {
        try await client.database
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id)
            .execute()
    }
    
    func uploadAvatar(imageData: Data, userId: UUID) async throws -> String {
        let fileName = "\(userId.uuidString)_\(Date().timeIntervalSince1970).jpg"
        let filePath = fileName
        
        try await client.storage
            .from("avatars")
            .upload(
                path: filePath,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Return the public URL
        let url = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return url.absoluteString
    }
    
    // MARK: - Database Methods
    
    // Create a new betting group
    func createGroup(name: String, stake: Double) async throws -> BettingGroup {
        let currentId = currentUserId 
        
        let group = BettingGroup(
            id: UUID(),
            name: name,
            stakePerPerson: stake,
            joinCode: String(UUID().uuidString.prefix(6)).uppercased(),
            adminId: currentId,
            createdAt: Date()
        )
        
        // 1. Insert the group
        try await client.database
            .from("betting_groups")
            .insert(group)
            .execute()
            
        // 2. Fetch current user profile to get their username
        let profile = try await fetchProfile(id: currentId)
        
        // 3. Insert the creator as an admin member
        var member = Member(
            id: UUID(),
            groupId: group.id,
            name: profile.username,
            balance: 0.0,
            joinedAt: Date(),
            userId: currentId
        )
        
        try await client.database
            .from("members")
            .insert(member)
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
    
    func fetchMyMemberships(userId: UUID) async throws -> [Member] {
        let members: [Member] = try await client.database
            .from("members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return members
    }
    
    func fetchMySelections(memberIds: [UUID]) async throws -> [Selection] {
        if memberIds.isEmpty { return [] }
        let selections: [Selection] = try await client.database
            .from("selections")
            .select()
            .in("member_id", value: memberIds)
            .execute()
            .value
        return selections
    }
    
    func fetchAllMyWeeks(userId: UUID) async throws -> [Week] {
        // First get my group memberships
        let memberships = try await fetchMyMemberships(userId: userId)
        let groupIds = memberships.map { $0.groupId }
        if groupIds.isEmpty { return [] }
        
        let weeks: [Week] = try await client.database
            .from("accas")
            .select()
            .in("group_id", value: groupIds)
            .execute()
            .value
        return weeks
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
        var member = Member(
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
    
    // Delete a betting group
    func deleteGroup(id: UUID) async throws {
        try await client.database
            .from("betting_groups")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // Delete an Acca (Week)
    func deleteAcca(id: UUID) async throws {
        try await client.database
            .from("accas")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // Update an Acca (Week)
    func updateAcca(_ week: Week) async throws {
        try await client.database
            .from("accas")
            .update(week)
            .eq("id", value: week.id)
            .execute()
    }
}
