import SwiftUI
import SwiftData

@main
struct RewireApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ArtistStore.shared)
        }
        .modelContainer(for: UserArtistData.self)
    }
}
