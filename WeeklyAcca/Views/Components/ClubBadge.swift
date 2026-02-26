import SwiftUI

struct ClubBadge: View {
    let url: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .scaledToFit()
                } placeholder: {
                    Circle().fill(Color(.systemGray6))
                }
            } else {
                Circle().fill(Color(.systemGray5))
            }
        }
        .frame(width: size, height: size)
    }
}
