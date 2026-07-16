import SwiftUI
import GoogleMaps

@main
struct SpillTheBeansApp: App {
    @State private var authService = AuthService()

    init() {
        // The Maps SDK must be initialised before the first GMSMapView is created.
        // The key lives in Info.plist (GMSApiKey) so it stays out of source code.
        let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
        GMSServices.provideAPIKey(key)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
    }
}
