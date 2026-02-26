import SwiftUI

struct WeekStatusBadge: View {
    let week: Week
    
    var body: some View {
        if week.status == .pending {
            if week.isOpen {
                Text("Open")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.blue)
            } else {
                Text("In Progress")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.orange)
            }
        } else {
            StatusBadge(status: week.status)
        }
    }
}
