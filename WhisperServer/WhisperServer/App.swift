import SwiftUI

@main
struct WhisperServerApp: App {
    @StateObject private var serverManager = ServerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .task {
                    await serverManager.prepareModel()
                }
        }
    }
}
