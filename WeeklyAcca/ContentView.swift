import SwiftUI


struct ContentView: View {
    @State private var selectedGroup: BettingGroup?
    
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainAppView(selectedGroup: $selectedGroup, isAuthenticated: $isAuthenticated)
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
        .task {
            await checkAuthStatus()
        }
    }
    
    private func checkAuthStatus() async {
        if SupabaseService.shared.currentUser != nil {
            isAuthenticated = true
            // Ensure profile exists in case of manual DB truncations
            try? await SupabaseService.shared.ensureProfileExists()
        } else {
            isAuthenticated = false
        }
    }
}

struct MainAppView: View {
    @Binding var selectedGroup: BettingGroup?
    @Binding var isAuthenticated: Bool
    @State private var groups: [BettingGroup] = []
    @State private var isLoading = false
    
    var body: some View {
        TabView {
            // Tab 1: Accas & Groups
            Group {
                if let group = selectedGroup {
                    DashboardView(group: group, selectedGroup: $selectedGroup)
                } else {
                    GroupListView(selectedGroup: $selectedGroup)
                }
            }
            .tabItem {
                Label("Groups", systemImage: "person.3")
            }
            
            // Tab 2: Matches
            NavigationStack {
                MatchesView()
            }
            .tabItem {
                Label("Matches", systemImage: "sportscourt")
            }
            
            // Tab 3: My Stats
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("My Stats", systemImage: "chart.bar")
            }
            
            // Tab 3: Profile
            ProfileView(selectedGroup: $selectedGroup, isAuthenticated: $isAuthenticated)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .task {
            await loadGroups()
            requestPushNotificationPermission()
        }
    }
    
    // Computed property to safely handle the optional selectedGroup
    private var activeGroup: BettingGroup? {
        selectedGroup
    }
    
    private func loadGroups() async {
        isLoading = true
        do {
            let userId = SupabaseService.shared.currentUserId
            let fetchedGroups = try await SupabaseService.shared.fetchGroups(for: userId)
            await MainActor.run {
                self.groups = fetchedGroups
                isLoading = false
            }
        } catch {
            print("Error loading groups: \(error)")
            isLoading = false
        }
    }
    
    private func requestPushNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("APNs Auth error: \(error.localizedDescription)")
            }
        }
        
        // Sync existing token if we have one
        if let token = UserDefaults.standard.string(forKey: "apnsToken") {
            Task {
                do {
                    try await SupabaseService.shared.updateAPNSToken(token: token)
                } catch {
                    print("Could not sync APNs token: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
