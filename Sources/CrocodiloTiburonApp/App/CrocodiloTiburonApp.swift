import AppKit
import SwiftUI

@main
struct CrocodiloTiburonApp: App {
    @NSApplicationDelegateAdaptor(CrocodiloTiburonAppDelegate.self) private var appDelegate
    @StateObject private var workspace = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(workspace)
                .frame(minWidth: 1240, minHeight: 780)
                .background(AppActivationView())
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

final class CrocodiloTiburonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        activateAppWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        activateAppWindow()
        return true
    }
}

struct AppActivationView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        activateWhenWindowExists(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        activateWhenWindowExists(for: view, coordinator: context.coordinator)
    }

    private func activateWhenWindowExists(for view: NSView, coordinator: Coordinator) {
        guard !coordinator.didActivate else { return }

        DispatchQueue.main.async {
            guard let window = view.window else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    activateWhenWindowExists(for: view, coordinator: coordinator)
                }
                return
            }

            coordinator.didActivate = true
            NSApp.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    final class Coordinator {
        var didActivate = false
    }
}

func activateAppWindow() {
    DispatchQueue.main.async {
        NSApp.setActivationPolicy(.regular)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
