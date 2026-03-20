import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hasSeenShareCodeCoachMark") private var hasSeenShareCodeCoachMark = true
    @AppStorage("hasSeenCreateAccaCoachMark") private var hasSeenCreateAccaCoachMark = true
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Onboarding & Tooltips") {
                    Button(action: {
                        hasCompletedOnboarding = false
                        hasSeenShareCodeCoachMark = false
                        hasSeenCreateAccaCoachMark = false
                        
                        // Give slight delay so they can read alert or see UI change if we had one
                        dismiss()
                    }) {
                        Text("Reset All Onboarding Flows")
                            .foregroundStyle(.red)
                    }
                }
                
                Section(footer: Text("These settings are only available in development and internal testing builds.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Developer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DeveloperSettingsView()
}
