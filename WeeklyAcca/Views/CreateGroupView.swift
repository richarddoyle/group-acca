import SwiftUI


struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, String) -> Void
    
    @AppStorage("userName") private var storedUserName: String = ""
    @State private var groupName: String = ""
    @State private var userName: String = ""
    @State private var errorMessage: String?
    
    init(onCreate: @escaping (String, String) -> Void) {
        self.onCreate = onCreate
        self._userName = State(initialValue: UserDefaults.standard.string(forKey: "userName") ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Group Name", text: $groupName)
                }
                
                Section("Your Details") {
                    TextField("Your Name", text: $userName)
                        .textContentType(.name)
                }
                
                if let error = errorMessage {
                    Section {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Betting Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if !userName.isEmpty {
                             storedUserName = userName
                        }
                        onCreate(groupName, userName)
                        dismiss()
                    }
                    .disabled(groupName.isEmpty || userName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateGroupView(onCreate: { _, _ in })
}
