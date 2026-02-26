import SwiftUI

struct StatusBadge: View {
    let status: WeekStatus
    var label: String? = nil
    var color: Color? = nil
    
    var body: some View {
        Text(label ?? status.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((color ?? statusColor).opacity(0.15), in: Capsule())
            .foregroundStyle(color ?? statusColor)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .won: return .green
        case .lost: return .red
        }
    }
}
