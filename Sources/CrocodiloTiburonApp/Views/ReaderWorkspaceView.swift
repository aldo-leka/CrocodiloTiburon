import SwiftUI

struct ReaderWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        PersistedHSplitView(
            storageKey: "reader",
            panes: [
                PersistedSplitPane(
                    minWidth: 160,
                    defaultWidth: 160,
                    maxWidth: 320,
                    view: AnyView(SectionRailView().environmentObject(workspace))
                ),
                PersistedSplitPane(
                    minWidth: 360,
                    defaultWidth: 720,
                    maxWidth: nil,
                    view: AnyView(FilingReaderView().environmentObject(workspace))
                )
            ]
        )
        .frame(maxHeight: .infinity)
        .background(CTTheme.canvas)
    }
}

struct SectionRailView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            Text("Sections")
                .font(CTTheme.Typography.label)
                .foregroundStyle(CTTheme.ink)
            Text("datamule standardized keys")
                .font(CTTheme.Typography.caption)
                .foregroundStyle(CTTheme.muted)
            VStack(spacing: CTTheme.Spacing.xs) {
                ForEach(workspace.sections) { section in
                    Button {
                        workspace.selectSection(section)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.title)
                                .font(CTTheme.Typography.body)
                                .foregroundStyle(CTTheme.ink)
                                .lineLimit(2)
                            HStack {
                                Text(section.key)
                                Spacer()
                                if section.estimatedWordCount > 0 {
                                    Text("~\(section.estimatedWordCount)")
                                }
                            }
                            .font(CTTheme.Typography.caption)
                            .foregroundStyle(CTTheme.muted)
                        }
                        .padding(CTTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(workspace.selectedSectionKey == section.key ? CTTheme.cream : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.surfaceSoft)
    }
}

struct FilingReaderView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        Group {
            if workspace.isLoadingReader {
                ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workspace.readerMode == .original, !workspace.readerHTML.isEmpty {
                FilingWebView(html: workspace.readerHTML, baseURL: workspace.readerBaseURL)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CTTheme.Spacing.xl) {
                        CTCard(background: CTTheme.surfaceDark) {
                            VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
                                Text(workspace.selectedSection?.title ?? workspace.selectedDocument?.description ?? "Reader")
                                    .font(CTTheme.Typography.displayMedium)
                                    .foregroundStyle(.white)
                                Text(workspace.selectedDocument?.filename ?? "Select a filing document")
                                    .font(CTTheme.Typography.body)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(workspace.readerMode == .markdown ? "```text\n\(workspace.readerDisplayText)\n```" : workspace.readerDisplayText)
                            .font(.system(size: 15, weight: .regular, design: workspace.readerMode == .markdown ? .monospaced : .serif))
                            .foregroundStyle(CTTheme.body)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }
                    .padding(CTTheme.Spacing.xl)
                    .frame(maxWidth: 760, alignment: .leading)
                }
            }
        }
    }
}
