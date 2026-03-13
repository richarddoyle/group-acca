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
    @State private var hasInitializedDefaults: Bool = false
    
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showLockTimeWarning: Bool = false
    
    @State private var selectedSport: String = "Football"
    let sports = ["Football"]
    
    @State private var monzoUsername: String = ""
    @State private var selectedLeagues: Set<String> = Set(LeagueConstants.supportedLeagues.map { $0.name })
    
    // Currency & Stake Options
    @State private var selectedCurrency: String = "£"
    let currencies = ["£", "$", "€"]
    
    var stakeOptions: [Double] {
        var options: [Double] = [1.0, 2.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0, 25.0, 50.0, 100.0]
        if !options.contains(group.stakePerPerson) {
            options.append(group.stakePerPerson)
            options.sort()
        }
        return options
    }
    
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
                    DatePicker("Start Date", selection: $startDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Pick Deadline", selection: $startDate, in: Date()..., displayedComponents: .hourAndMinute)
                    Text("Pick deadline on \(startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) \(startDate.formatted(date: .omitted, time: .shortened)) (\(TimeZone.current.abbreviation() ?? ""))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                .onChange(of: startDate) { oldDate, newDate in
                    let oldTitle = oldDate.formatted(.dateTime.month(.abbreviated).day().year())
                    if title == oldTitle || title.isEmpty {
                        title = newDate.formatted(.dateTime.month(.abbreviated).day().year())
                    }
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
                        Text("Currency")
                        Spacer()
                        Picker("", selection: $selectedCurrency) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Stake per pick")
                        Spacer()
                        Picker("", selection: $stakePerPick) {
                            ForEach(stakeOptions, id: \.self) { amount in
                                Text("\(selectedCurrency)\(String(format: "%.2f", amount))").tag(amount)
                            }
                        }
                        .pickerStyle(.menu)
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
                
                Section {
                    NavigationLink(destination: AddMonzoUsernameView(monzoUsername: $monzoUsername)) {
                        HStack(spacing: 12) {
                            Text("M")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                            
                            Text("Monzo Username")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if !monzoUsername.isEmpty {
                                Text(monzoUsername)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Add")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Payment Options")
                } footer: {
                    Text("Add details of your preferred payment methods so that members can send you their stake easily.")
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
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        validateAndCreate()
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
            .alert("Approaching Lock Time", isPresented: $showLockTimeWarning, actions: {
                Button("Cancel", role: .cancel) { }
                Button("Create Anyway", role: .destructive) {
                    createAcca()
                }
            }, message: {
                Text("The pick deadline is less than an hour away (or in the past). Are you sure you want to create this Accumulator now?")
            })
            .task {
                guard !hasInitializedDefaults else { return }
                
                // Initialize defaults
                setupDefaults()
                
                // Load members for this group safely
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
                
                // Fetch Profile for default Monzo handle
                do {
                    let userId = SupabaseService.shared.currentUserId
                    let fetchedProfile = try await SupabaseService.shared.fetchProfile(id: userId)
                    
                    await MainActor.run {
                        if let existingMonzo = fetchedProfile.monzoUsername {
                            self.monzoUsername = existingMonzo
                        }
                    }
                } catch {
                    print("Error loading profile: \(error)")
                }
                
                hasInitializedDefaults = true
            }
        }
    }
    
    private func setupDefaults() {
        let calendar = Calendar.current
        let today = Date()
        
        // 1. Start Date / Lock Time: Current time + 2 hours
        let newStartDate = calendar.date(byAdding: .hour, value: 2, to: today) ?? today.addingTimeInterval(2 * 3600)
        self.startDate = newStartDate
        
        if title.isEmpty {
            self.title = newStartDate.formatted(.dateTime.month(.abbreviated).day().year())
        }
        
        // 2. End Date: Tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: newStartDate) {
            self.endDate = tomorrow
        } else {
            self.endDate = newStartDate
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
    
    private func validateAndCreate() {
        if startDate < Date() {
            errorMessage = "The pick deadline cannot be in the past."
            showError = true
            return
        }
        
        let oneHourFromNow = Date().addingTimeInterval(3600)
        
        if startDate < oneHourFromNow {
            showLockTimeWarning = true
        } else {
            createAcca()
        }
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
                    status: .pending,
                    monzoUsername: monzoUsername.isEmpty ? nil : monzoUsername,
                    creatorId: SupabaseService.shared.currentUserId
                )
                
                // 3. Save Week to Supabase
                try await SupabaseService.shared.createWeek(week: newWeek)
                
                // 3b. Update Profile with the new Monzo Username
                if !monzoUsername.isEmpty {
                    let userId = SupabaseService.shared.currentUserId
                    var profile = try await SupabaseService.shared.fetchProfile(id: userId)
                    if profile.monzoUsername != monzoUsername {
                        profile.monzoUsername = monzoUsername
                        try await SupabaseService.shared.updateProfile(profile)
                    }
                }
                
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
                
                // Trigger Push Notifications via Edge Function
                do {
                    try await SupabaseService.shared.sendAccaNotification(for: newWeek)
                } catch {
                    print("Error sending Acca push notification: \(error)")
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
