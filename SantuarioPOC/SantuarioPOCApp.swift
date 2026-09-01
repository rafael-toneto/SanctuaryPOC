import SwiftUI

@main
struct SantuarioPOCApp: App {
    @StateObject private var store = SanctuaryStore()

    var body: some Scene {
        WindowGroup {
            SanctuaryView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
