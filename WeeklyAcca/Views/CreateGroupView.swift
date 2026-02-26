import SwiftUI


struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String) -> Void
    
    @State private var groupName: String = ""
    @State private var errorMessage: String?
    
    init(onCreate: @escaping (String) -> Void) {
        self.onCreate = onCreate
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Group Name", text: $groupName)
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
                        onCreate(groupName)
                        dismiss()
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateGroupView(onCreate: { _ in })
}
