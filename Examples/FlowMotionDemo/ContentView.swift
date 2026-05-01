import SwiftUI
import FlowMotion

struct ContentView: View {
    var body: some View {
        FlowNavigationStack(transition: .cinematic()) {
            HomeScreen()
        }
    }
}

#Preview {
    ContentView()
}
