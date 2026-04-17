import SwiftUI

struct ContentView: View {
    var body: some View {
        // Tab struct API — available iOS 18+ (required for iOS 26)
        // .sidebarAdaptable shows a sidebar on iPad and a tab bar on iPhone
        TabView {
            Tab("Map", systemImage: "map.fill") {
                CoffeeMapView()
            }

            Tab("Encyclopedia", systemImage: "books.vertical.fill") {
                EncyclopediaView()
            }

            // Placeholder kept separate so future features can be added independently
            Tab("Journal", systemImage: "pencil.and.list.clipboard") {
                ComingSoonView(tabName: "Journal", systemImage: "pencil.and.list.clipboard")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.espresso)
    }
}

// MARK: - Coming Soon Placeholder

private struct ComingSoonView: View {
    let tabName: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(Color.terracotta.opacity(0.35))
                Text(tabName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.espresso)
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.creamBackground)
            .navigationTitle(tabName)
        }
    }
}
