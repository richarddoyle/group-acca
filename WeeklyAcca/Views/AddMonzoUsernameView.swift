import SwiftUI

struct AddMonzoUsernameView: View {
    @Binding var monzoUsername: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Icon
                HStack {
                    Spacer()
                    AsyncImage(url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Monzo_logo.svg/512px-Monzo_logo.svg.png")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if phase.error != nil {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Text("M")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                            }
                        } else {
                            ProgressView()
                                .frame(width: 80, height: 80)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your Monzo Username")
                        .font(.title2.bold())
                    Text("Adding your Monzo username makes it easy for other members of the group to send you their stake.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                // Instructions Step-by-Step
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to find your username:")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    InstructionStepRow(
                        number: 1,
                        text: "Open the **Monzo App**"
                    )
                    
                    InstructionStepRow(
                        number: 2,
                        text: "Tap **Payments** at the bottom of the screen"
                    )
                    
                    InstructionStepRow(
                        number: 3,
                        text: "Tap your **Profile Icon** in the top right to open your Payments settings"
                    )
                    
                    InstructionStepRow(
                        number: 4,
                        text: "Look for the field starting with **monzo.me/** – the text right after the slash is your username!"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Username")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter username (e.g. johndoe)", text: $monzoUsername)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                
                // Help Link
                if let url = URL(string: "https://monzo.com/help/") {
                    Link(destination: url) {
                        HStack {
                            Text("Read more on Monzo's Help page")
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 4)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Monzo Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

private struct InstructionStepRow: View {
    let number: Int
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "\(number).circle")
                .foregroundStyle(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
    }
}
