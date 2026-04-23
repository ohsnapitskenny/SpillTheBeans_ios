import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        if authService.isAuthenticated {
            mainTabs
        } else {
            SplashView()
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
