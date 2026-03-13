import SwiftUI

struct MemberProfileView: View {
    @Environment(\.dismiss) var dismiss
    let member: Member
    let group: BettingGroup
    let avatarUrl: String?
    
    // Optional properties for Admin payment features
    var week: Week? = nil
    var selections: [Selection]? = nil
    var onUpdateRow: (() -> Void)? = nil
    
    @State private var isUpdating: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showToast: Bool = false
    
    // Stats State
    @State private var isLoadingStats: Bool = true
    @State private var successfulPicks: Int = 0
    @State private var successfulPickRate: Double = 0.0
    @State private var successfulAccas: Int = 0 
    @State private var activeAwards: [ActiveAward] = []
    @State private var currentStreak: Int = 0
    @State private var last10Picks: [Selection] = []
    
    // Derived state for the target user (Admin)
    private var isUserPaid: Bool {
        return selections?.first?.isPaid ?? false
    }
    
    // Admin check
    private var isAdmin: Bool {
        return SupabaseService.shared.currentUserId == group.adminId
    }
    
    private var canManagePayment: Bool {
        return isAdmin && week != nil && selections != nil && !(selections!.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Header Details
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProfileImage(url: avatarUrl, size: 180)
                            
                            if canManagePayment {
                                Text("Payment Status: \(isUserPaid ? "Paid" : "Unpaid")")
                                    .font(.subheadline)
                                    .foregroundStyle(isUserPaid ? .green : .secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                // Admin Actions Blocks
                if canManagePayment {
                    Section("Admin Actions") {
                        HStack(spacing: 12) {
                            Button {
                                updatePaymentStatus(to: !isUserPaid)
                            } label: {
                                VStack(spacing: 6) {
                                    if isUpdating {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: !isUserPaid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.title3)
                                    }
                                    Text(!isUserPaid ? "Mark as paid" : "Reject payment")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .background(!isUserPaid ? Color.green : Color.red.opacity(0.15))
                                .foregroundStyle(!isUserPaid ? .white : .red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isUpdating)
                            .buttonStyle(PlainButtonStyle())
                            
                            Button {
                                // Mocking the Payment Reminder
                                withAnimation { showToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showToast = false }
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "bell.fill")
                                        .font(.title3)
                                    Text("Send reminder")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .background(Color(.systemGray6))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                
                if isLoadingStats {
                    HStack {
                        Spacer()
                        ProgressView("Loading stats...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Overall") {
                        StatRow(label: "Successful Picks", value: "\(successfulPicks)")
                        StatRow(label: "Successful Pick %", value: successfulPickRate.formatted(.percent.precision(.fractionLength(1))))
                        StatRow(label: "Successful Accas", value: "\(successfulAccas)")
                    }
                    
                    ActiveAwardsSectionView(activeAwards: activeAwards)
                    
                    CurrentFormSectionView(
                        currentStreak: currentStreak,
                        last10Picks: last10Picks,
                        memberName: member.name,
                        avatarUrl: avatarUrl
                    )
                }
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .overlay {
                if showToast {
                    VStack {
                        Spacer()
                        Text("Reminder sent!")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .alert("Error", isPresented: $showingError, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(errorMessage)
            })
            .task {
                await loadUserStats()
            }
        }
    }
    
    private func loadUserStats() async {
        guard let userId = member.userId else {
            await MainActor.run { isLoadingStats = false }
            return
        }
        
        do {
            async let fetchedMemberships = SupabaseService.shared.fetchMyMemberships(userId: userId)
            async let fetchedWeeks = SupabaseService.shared.fetchWeeks(groupId: group.id)
            
            let m = try await fetchedMemberships
            let w = try await fetchedWeeks
            
            // Only care about the membership for THIS group
            guard let membership = m.first(where: { $0.groupId == group.id }) else {
                await MainActor.run { isLoadingStats = false }
                return
            }
            
            let s = try await SupabaseService.shared.fetchMySelections(memberIds: [membership.id])
            
            var newAwards: [ActiveAward] = []
            let badgeManager = GroupBadgeManager()
            await badgeManager.loadBadges(for: group)
            
            let topWinners = await badgeManager.topWinners
            let topEarners = await badgeManager.topEarners
            let streakBadges = await badgeManager.streakBadges
            
            if topWinners.contains(membership.id) {
                newAwards.append(ActiveAward(emoji: "👑", groupName: group.name, description: "Most successful picks in the group."))
            }
            
            if topEarners.contains(membership.id) {
                newAwards.append(ActiveAward(emoji: "💰", groupName: group.name, description: "Highest total winnings in the group."))
            }
            
            if let streakBadge = streakBadges[membership.id] {
                let desc: String
                if streakBadge == "🐐" { desc = "On a 10+ win streak." }
                else if streakBadge == "🚀" { desc = "On a 5+ win streak." }
                else if streakBadge == "🔥" { desc = "On a 3+ win streak." }
                else { desc = "On a win streak." }
                
                newAwards.append(ActiveAward(emoji: streakBadge, groupName: group.name, description: desc))
            }
            
            // Calculate Stats for THIS group only
            let groupWeekIds = Set(w.map { $0.id })
            let groupSelections = s.filter { groupWeekIds.contains($0.accaId) }
            
            let closedWeekIds = Set(w.filter { $0.status != .pending }.map { $0.id })
            let totalPicks = groupSelections.filter { closedWeekIds.contains($0.accaId) && $0.outcome != .pending }.count
            let successPicksCount = groupSelections.filter { closedWeekIds.contains($0.accaId) && $0.outcome == .win }.count
            let successRate = totalPicks > 0 ? Double(successPicksCount) / Double(totalPicks) : 0.0
            
            // Calculate Successful Accas (where the user's pick was a win and the acca was won)
            let wonAccaIds = Set(w.filter { $0.status == .won }.map { $0.id })
            let successfulAccasCount = groupSelections.filter { wonAccaIds.contains($0.accaId) && $0.outcome == .win }.count
            
            // Last 10 Picks
            let sortedSelections = groupSelections
                .filter { $0.outcome != .pending }
                .sorted { a, b in
                    let dateA = a.kickoffTime ?? Date.distantPast
                    let dateB = b.kickoffTime ?? Date.distantPast
                    if dateA == dateB {
                        return a.id.uuidString > b.id.uuidString
                    }
                    return dateA > dateB
                }
                
            let recentPicks = Array(sortedSelections.prefix(10))
            
            // Streak
            var streak = 0
            for selection in sortedSelections {
                if selection.outcome == .win {
                    streak += 1
                } else if selection.outcome == .loss {
                    break
                }
            }
            
            await MainActor.run {
                self.successfulPicks = successPicksCount
                self.successfulPickRate = successRate
                self.successfulAccas = successfulAccasCount
                self.activeAwards = newAwards
                self.currentStreak = streak
                self.last10Picks = recentPicks
                self.isLoadingStats = false
            }
            
        } catch {
            print("Error loading member stats: \(error)")
            await MainActor.run { isLoadingStats = false }
        }
    }
    
    private func updatePaymentStatus(to isPaid: Bool) {
        let memberSelections = selections ?? []
        guard !memberSelections.isEmpty else { return }
        
        isUpdating = true
        Task {
            do {
                for selection in memberSelections {
                    var updated = selection
                    updated.isPaid = isPaid
                    try await SupabaseService.shared.saveSelection(updated)
                }
                
                await MainActor.run {
                    onUpdateRow?()
                    isUpdating = false
                    dismiss()
                }
            } catch {
                print("Error overriding user payment status: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to update payment status."
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
}

struct ActiveAwardsSectionView: View {
    let activeAwards: [ActiveAward]
    
    var body: some View {
        Section(header: Text("Active Awards")) {
            if activeAwards.isEmpty {
                Text("No active awards.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                let groupedAwards = Dictionary(grouping: activeAwards, by: { $0.groupName })
                let sortedGroups = groupedAwards.keys.sorted()
                
                ForEach(sortedGroups, id: \.self) { groupName in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(groupName)
                            .font(.headline)
                        
                        if let awardsInGroup = groupedAwards[groupName] {
                            ForEach(awardsInGroup) { award in
                                HStack(spacing: 8) {
                                    Text(award.emoji)
                                        .font(.system(size: 24))
                                    
                                    Text(award.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 0)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct CurrentFormSectionView: View {
    let currentStreak: Int
    let last10Picks: [Selection]
    let memberName: String
    let avatarUrl: String?
    
    var body: some View {
        Section(header: Text("Current Form")) {
            StatRow(label: "Current Win Streak", value: "\(currentStreak)")
            
            if !last10Picks.isEmpty {
                ForEach(last10Picks, id: \.id) { pick in
                    SelectionRow(selection: pick, memberName: memberName, avatarUrl: avatarUrl, isLocked: true, hideBadge: true)
                }
            }
        }
    }
}
