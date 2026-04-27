import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        // Read the stored @Observable property directly — not a computed
        // wrapper — so SwiftUI's observation tracker registers the dependency
        // and re-evaluates body the moment currentUser changes.
        if authService.currentUser != nil {
            mainTabs
                .transition(.opacity)
        } else {
            SplashView()
                .transition(.opacity)
        }
    }

    // MARK: - Main Tab View

    private var mainTabs: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                CoffeeMapView()
            }

            Tab("Encyclopedia", systemImage: "books.vertical.fill") {
                EncyclopediaView()
            }

            Tab("Me", systemImage: "person.fill") {
                UserProfileView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.espresso)
    }
}
