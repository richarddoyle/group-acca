import SwiftUI

struct SelectionOutcomeBadge: View {
    let outcome: SelectionOutcome
    
    var body: some View {
        Text(outcome.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15), in: Capsule())
            .foregroundStyle(backgroundColor)
    }
    
    private var backgroundColor: Color {
        switch outcome {
        case .pending: return .orange
        case .win: return .green
        case .loss: return .red
        case .void: return .secondary
        }
    }
}
