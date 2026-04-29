import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        // Read stored @Observable properties directly — not computed wrappers —
        // so SwiftUI's observation tracker re-evaluates body on every change.
        if authService.isCheckingCredentialState {
            // Neutral loading screen shown during the launch-time Apple ID
            // credential check. Prevents a flash of SplashView → mainTabs
            // (or vice versa) for returning users whose token is still valid.
            loadingView
        } else if authService.currentUser != nil {
            mainTabs
                .transition(.opacity)
        } else {
            SplashView()
                .transition(.opacity)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            Color.espresso.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.cream)
                .scaleEffect(1.2)
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
