import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var storedUserName: String = ""
    @State private var joinCode: String = ""
    @State private var userName: String = "" // Need name for new member
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
                
                Section("Your Name") {
                    TextField("Name", text: $userName)
                        .onAppear {
                            if !storedUserName.isEmpty { userName = storedUserName }
                        }
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
                    .disabled(joinCode.count < 6 || userName.isEmpty || isJoining)
                }
            }
        }
    }
    
    private func joinGroup() {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                let _ = try await SupabaseService.shared.joinGroup(code: joinCode, userName: userName, userId: SupabaseService.shared.currentUserId)
                await MainActor.run {
                    storedUserName = userName // Update stored name
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
