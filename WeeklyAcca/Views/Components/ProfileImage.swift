import SwiftUI

struct ProfileImage: View {
    let url: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let urlString = url {
                CachedImage(url: urlString) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
