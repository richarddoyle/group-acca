import SwiftUI

struct TestView: View {
    @State private var offset: CGFloat = 0
    var body: some View {
        VStack {
            Text("Offset: \(offset)")
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<100) { i in
                        Text("Item \(i)")
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: OffsetKey.self,
                            value: proxy.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(OffsetKey.self) { value in
                print("New offset: \(value)")
            }
        }
    }
}
struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
