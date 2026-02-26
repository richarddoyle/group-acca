import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    var onJoinSuccess: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter 6-digit code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Join Code")
                } footer: {
                    Text("Ask the group admin for the code found in their settings.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Join Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        joinGroup()
                    }
                    .disabled(joinCode.count < 6 || isJoining)
                }
            }
            .overlay {
                if isJoining {
                    ProgressView()
                }
            }
        }
    }
    
    private func joinGroup() {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                let userId = SupabaseService.shared.currentUserId
                // Fetch profile to get the user's name
                let profile = try await SupabaseService.shared.fetchProfile(id: userId)
                
                let _ = try await SupabaseService.shared.joinGroup(
                    code: joinCode, 
                    userName: profile.username, 
                    userId: userId
                )
                
                await MainActor.run {
                    isJoining = false
                    onJoinSuccess?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    JoinGroupView()
}
