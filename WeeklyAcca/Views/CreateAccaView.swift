import SwiftUI

struct CreateAccaView: View {
    let group: BettingGroup
    let nextWeekNumber: Int
    var onCreated: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var selectedMemberIDs: Set<UUID> = [] // UUID for Supabase
    @State private var members: [Member] = [] // Loaded members
    @State private var stakePerPick: Double = 5.0
    @State private var maxPicksPerMember: Int = 1
    
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    @State private var selectedSport: String = "Football"
    let sports = ["Football"]
    
    @State private var selectedLeagues: Set<String> = Set(LeagueConstants.supportedLeagues.map { $0.name })
    
    var availableLeagues: [String] {
        LeagueConstants.supportedLeagues.map { $0.name }
    }
    
    // @State private var allowEarlyKickoffs: Bool = true // Removed
    
    var body: some View {
        NavigationStack {
            Form {
                // ... (Sections same as before)
                Section("Name") {
                    TextField("Title (e.g., Week 1)", text: $title)
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Pick Deadline", selection: $startDate, displayedComponents: .hourAndMinute)
                    Text("Pick deadline on \(startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) \(startDate.formatted(date: .omitted, time: .shortened)) (\(TimeZone.current.abbreviation() ?? ""))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section("Sport & Rules") {
                    Picker("Sport", selection: $selectedSport) {
                        ForEach(sports, id: \.self) { sport in
                            Text(sport).tag(sport)
                        }
                    }
                    
                    if selectedSport == "Football" {
                        // Toggle("Allow Early Kickoffs (12:30)", isOn: $allowEarlyKickoffs) // Removed
                        
                        NavigationLink {
                            List {
                                ForEach(availableLeagues, id: \.self) { league in
                                    HStack {
                                        Text(league)
                                        Spacer()
                                        if selectedLeagues.contains(league) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.accentColor)
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
                            .navigationTitle("Competitions")
                        } label: {
                            HStack {
                                Text("Competitions")
                                Spacer()
                                Text("\(selectedLeagues.count) Selected")
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Stake per pick")
                        Spacer()
                        TextField("£", value: $stakePerPick, format: .currency(code: "GBP"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Max picks per member")
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                if maxPicksPerMember > 1 { maxPicksPerMember -= 1 }
                            } label: {
                                Text("-")
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(maxPicksPerMember > 1 ? Color.primary : Color.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(maxPicksPerMember)")
                                .frame(width: 40)
                                .multilineTextAlignment(.center)
                                .fontWeight(.semibold)
                            
                            Button {
                                if maxPicksPerMember < 20 { maxPicksPerMember += 1 }
                            } label: {
                                Text("+")
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(maxPicksPerMember < 20 ? Color.primary : Color.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createAcca()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(title.isEmpty || selectedMemberIDs.isEmpty || isCreating)
                }
            }
            .safeAreaInset(edge: .top) {
                if title.isEmpty || selectedMemberIDs.isEmpty {
                   VStack {
                        Text(title.isEmpty ? "Enter a title to continue" : "Select at least one participant")
                            .font(.caption)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .alert("Error", isPresented: $showError, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(errorMessage ?? "Unknown error")
            })
            .task {
                // Initialize defaults
                setupDefaults()
                
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
    
    private func setupDefaults() {
        let calendar = Calendar.current
        let today = Date()
        
        if title.isEmpty {
            self.title = today.formatted(.dateTime.month(.abbreviated).day().year()) // e.g., "Feb 27, 2026"
        }
        
        // Target UK Timezone
        guard let ukTimeZone = TimeZone(identifier: "Europe/London") else {
            // Fallback if timezone identifier fails (highly unlikely)
            startDate = today
            endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return
        }
        
        // 1. Start Date / Lock Time: Today at 14:30 (2:30 PM) UK Time
        var components = calendar.dateComponents(in: ukTimeZone, from: today)
        components.hour = 14
        components.minute = 30
        components.second = 0
        
        if let lockTime = components.date {
            startDate = lockTime
        } else {
            startDate = today
        }
        
        // 2. End Date: Tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startDate) {
            endDate = tomorrow
        } else {
            endDate = startDate
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
        isCreating = true
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
                    stakePerPick: stakePerPick,
                    maxPicksPerMember: maxPicksPerMember,
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
                    isCreating = false
                    onCreated?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                print("Error creating acca: \(error)")
                // Handle error (show alert)
            }
        }
    }
}
