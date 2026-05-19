import SwiftUI

struct AppShellView: View {
    var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 220, idealWidth: 286, maxWidth: 420)
            CompanyWorkspaceView()
                .frame(minWidth: 360, idealWidth: 430, maxWidth: .infinity)
            ReaderWorkspaceView()
                .frame(minWidth: 420, idealWidth: 520, maxWidth: .infinity)
        }
        .background(CTTheme.canvas)
    }
}
