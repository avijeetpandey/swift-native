import SwiftNativeCore

struct AboutScreen: View {
    @State private var likes = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("About")
                .font(.title)
            Text("A tiny app built with Swift Native — one Swift codebase, native UI.")
                .foregroundColor(.gray)
            Button("👍 \(likes)") { likes += 1 }
        }
        .padding(24)
    }
}
