import SwiftUI


struct SelectionView: View {
    @Binding var selection: Selection
    let memberName: String?
    @State private var showingMatchSelection = false
    
    var body: some View {
        Form {
            Section("Match Selection") {
                if selection.teamName == "Pending" || selection.teamName.isEmpty {
                    Button {
                        showingMatchSelection = true
                    } label: {
                        Label("Select Match", systemImage: "sportscourt")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.teamName)
                            .font(.headline)
                        Text(selection.league)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Change Match") {
                        showingMatchSelection = true
                    }
                }
            }
            
            Section("Bet Details") {
                HStack {
                    Text("Odds")
                    Spacer()
                    TextField("Odds", value: $selection.odds, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("Status") {
                Picker("Outcome", selection: $selection.outcome) {
                    Text("Pending").tag(SelectionOutcome.pending)
                    Text("Win").tag(SelectionOutcome.win)
                    Text("Loss").tag(SelectionOutcome.loss)
                    Text("Void").tag(SelectionOutcome.void)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("\(memberName ?? "Member")'s Pick")
    }
}
