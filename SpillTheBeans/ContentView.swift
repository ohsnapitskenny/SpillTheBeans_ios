import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CoffeeMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            EncyclopediaView()
                .tabItem {
                    Label("Encyclopedia", systemImage: "books.vertical.fill")
                }

            // Placeholder for future tabs (e.g. Journal, Social Feed)
            ComingSoonView(tabName: "Journal", systemImage: "pencil.and.list.clipboard")
                .tabItem {
                    Label("Journal", systemImage: "pencil.and.list.clipboard")
                }
        }
        .tint(Color.espresso)
    }
}

// MARK: - Coming Soon Placeholder

private struct ComingSoonView: View {
    let tabName: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
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
    }
}
