import SwiftUI
import SwiftData

@main
struct CarteVisiteApp: App {
    /// Conteneur SwiftData : stockage 100% local sur l'appareil.
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: BusinessCard.self)
        } catch {
            fatalError("Impossible d'initialiser le stockage local : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            CardListView()
        }
        .modelContainer(modelContainer)
    }
}
