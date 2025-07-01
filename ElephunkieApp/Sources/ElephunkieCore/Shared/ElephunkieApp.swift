import SwiftUI

@main
struct ElephunkieApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var serverManager = LocalServerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(serverManager)
                .onAppear {
                    Task {
                        await serverManager.startServer()
                    }
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Elephunkie") {
                    appState.showAbout = true
                }
            }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}