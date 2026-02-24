import SwiftUI

@main
struct ListWithMeApp: App {
    let persistenceController = PersistenceController.shared
    @State private var collaborationService = CollaborationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(collaborationService)
        }
    }
}
