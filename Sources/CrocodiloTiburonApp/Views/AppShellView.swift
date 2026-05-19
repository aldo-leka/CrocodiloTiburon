import SwiftUI

struct AppShellView: View {
    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 286)
            Divider()
            CompanyWorkspaceView()
                .frame(minWidth: 430)
            Divider()
            ReaderWorkspaceView()
                .frame(minWidth: 520)
        }
        .background(CTTheme.canvas)
    }
}
