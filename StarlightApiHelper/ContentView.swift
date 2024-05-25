import SwiftUI
import SwiftApiAdapter

struct ContentView: View {
    var body: some View {
        TabView {
            ScrollView {
                CreateSpecView()
            }
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity)
            .tabItem {
                Label("1. Create API Spec", systemImage: "text.bubble")
            }

            ScrollView {
                CallSpecView()
            }
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity)
            .tabItem {
                Label("2. Call API Spec", systemImage: "text.bubble")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
