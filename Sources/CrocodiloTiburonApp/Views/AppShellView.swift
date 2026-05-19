import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        PersistedHSplitView(
            storageKey: "main",
            panes: [
                PersistedSplitPane(
                    minWidth: 220,
                    defaultWidth: 220,
                    maxWidth: 420,
                    view: AnyView(SidebarView().environmentObject(workspace))
                ),
                PersistedSplitPane(
                    minWidth: 360,
                    defaultWidth: 360,
                    maxWidth: nil,
                    view: AnyView(CompanyWorkspaceView().environmentObject(workspace))
                ),
                PersistedSplitPane(
                    minWidth: 420,
                    defaultWidth: 420,
                    maxWidth: nil,
                    view: AnyView(ReaderWorkspaceView().environmentObject(workspace))
                )
            ]
        )
        .background(CTTheme.canvas)
        .overlay(alignment: .topTrailing) {
            if workspace.isAppLoading {
                GlobalLoadingIndicator()
                    .padding(CTTheme.Spacing.sm)
            }
        }
    }
}

private struct GlobalLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.small)
            .padding(CTTheme.Spacing.xs)
            .background(.regularMaterial)
            .clipShape(Circle())
    }
}
