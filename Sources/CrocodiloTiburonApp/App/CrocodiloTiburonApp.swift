import AppKit
import SwiftUI

@MainActor
private enum CrocodiloTiburonAppEnvironment {
    static let workspace = WorkspaceStore()
}

@main
struct CrocodiloTiburonApp: App {
    @NSApplicationDelegateAdaptor(CrocodiloTiburonAppDelegate.self) private var appDelegate
    @StateObject private var workspace: WorkspaceStore

    init() {
        _workspace = StateObject(wrappedValue: CrocodiloTiburonAppEnvironment.workspace)
        AppFontRegistry.registerFonts()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
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

@MainActor
final class CrocodiloTiburonAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        uiTestLog("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func showMainWindow() {
        uiTestLog("showMainWindow existing=\(mainWindow != nil)")
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window

        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        uiTestLog("ordered window visible=\(window.isVisible) windows=\(NSApp.windows.count)")
    }

    private func makeMainWindow() -> NSWindow {
        uiTestLog("makeMainWindow")
        let rootView = AppShellView()
            .environmentObject(CrocodiloTiburonAppEnvironment.workspace)
            .frame(minWidth: 1240, minHeight: 780)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Crocodilo Tiburon"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        window.setAccessibilityElement(true)
        window.setAccessibilityRole(.window)
        window.setAccessibilityTitle("Crocodilo Tiburon")
        window.center()
        return window
    }

    private func uiTestLog(_ message: String) {
        guard ProcessInfo.processInfo.environment["CROCODILO_UI_TESTING"] == "1" else { return }
        FileHandle.standardError.write(Data("[CrocodiloTiburon] \(message)\n".utf8))
    }
}

@MainActor
func activateAppWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
