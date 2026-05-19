import SwiftUI

@main
struct CrocodiloTiburonApp: App {
    @StateObject private var workspace = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(workspace)
                .frame(minWidth: 1240, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Search Company") {
                    workspace.focusSearch()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
}
