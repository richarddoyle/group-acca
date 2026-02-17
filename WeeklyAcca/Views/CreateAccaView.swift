import SwiftUI

struct CreateAccaView: View {
    let group: BettingGroup
    let nextWeekNumber: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var selectedMemberIDs: Set<UUID> = [] // UUID for Supabase
    @State private var members: [Member] = [] // Loaded members
    
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 7)
    
    @State private var selectedSport: String = "Football"
    let sports = ["Football"]
    
    @State private var selectedLeagues: Set<String> = ["Premier League", "Championship", "League One", "League Two"]
    
    var availableLeagues: [String] {
        LeagueConstants.supportedLeagues.map { $0.name }
    }
    
    @State private var allowEarlyKickoffs: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                // ... (Sections same as before)
                Section("Accumulator Details") {
                    TextField("Title (e.g., Week 1)", text: $title)
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section("Sport & Rules") {
                    Picker("Sport", selection: $selectedSport) {
                        ForEach(sports, id: \.self) { sport in
                            Text(sport).tag(sport)
                        }
                    }
                    
                    if selectedSport == "Football" {
                        Toggle("Allow Early Kickoffs (12:30)", isOn: $allowEarlyKickoffs)
                        
                        NavigationLink {
                            List {
                                ForEach(availableLeagues, id: \.self) { league in
                                    HStack {
                                        Text(league)
                                        Spacer()
                                        if selectedLeagues.contains(league) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedLeagues.contains(league) {
                                            selectedLeagues.remove(league)
                                        } else {
                                            selectedLeagues.insert(league)
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Select Leagues")
                        } label: {
                            HStack {
                                Text("Competitions")
                                Spacer()
                                Text("\(selectedLeagues.count) Selected")
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Participants") {
                    if members.isEmpty {
                        Text("Loading members...")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(members) { member in
                            Toggle(isOn: binding(for: member)) {
                                Text(member.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Accumulator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createAcca()
                    }
                    .disabled(title.isEmpty || selectedMemberIDs.isEmpty)
                }
            }
            .task {
                // Load members for this group
                do {
                    let fetchedMembers = try await SupabaseService.shared.fetchMembers(for: group.id)
                    await MainActor.run {
                        self.members = fetchedMembers
                        for member in members {
                            selectedMemberIDs.insert(member.id) // Default all selected
                        }
                    }
                } catch {
                    print("Error loading members: \(error)")
                }
            }
        }
    }
    
    private func binding(for member: Member) -> Binding<Bool> {
        Binding(
            get: { selectedMemberIDs.contains(member.id) },
            set: { isSelected in
                if isSelected {
                    selectedMemberIDs.insert(member.id)
                } else {
                    selectedMemberIDs.remove(member.id)
                }
            }
        )
    }
    
    private func createAcca() {
        Task {
            do {
                // 1. Use passed week number

                
                // 2. Create the Week object
                let newWeek = Week(
                    id: UUID(),
                    groupId: group.id,
                    weekNumber: nextWeekNumber,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    sport: selectedSport,
                    selectedLeagues: Array(selectedLeagues),
                    allowEarlyKickoffs: allowEarlyKickoffs,
                    isSettled: false,
                    status: .pending
                )
                
                // 3. Save Week to Supabase
                try await SupabaseService.shared.createWeek(week: newWeek)
                
                // 4. Create initial pending selections for selected members
                // Note: In Supabase, we might not want to pre-fill selections rows for everyone immediately
                // to save DB space, but the app logic expects them. Let's create them.
                // We need to fetch members first to be sure? No, we have group.members from the parent view context?
                // Wait, group.members is not available directly if BettingGroup is a Codable struct without relations loaded.
                // We need to fetch members for the group to create selections.
                
                let members = try await SupabaseService.shared.fetchMembers(for: group.id)
                let selectedMembers = members.filter { selectedMemberIDs.contains($0.id) }
                
                for member in selectedMembers {
                    let placeholder = Selection(
                        id: UUID(),
                        accaId: newWeek.id,
                        memberId: member.id,
                        teamName: "Pending",
                        league: "Pending",
                        outcome: .pending,
                        odds: 0.0
                    )
                    try await SupabaseService.shared.saveSelection(placeholder)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating acca: \(error)")
                // Handle error (show alert)
            }
        }
    }
}
