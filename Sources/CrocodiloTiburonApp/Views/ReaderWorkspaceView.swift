import SwiftUI
import MarkdownUI

struct ReaderWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        Group {
            if workspace.hasReaderContent && shouldShowRail {
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
            } else if workspace.hasReaderContent {
                FilingReaderView()
                    .environmentObject(workspace)
            } else {
                Color.clear
            }
        }
        .frame(maxHeight: .infinity)
        .background(CTTheme.canvas)
    }

    private var shouldShowRail: Bool {
        !workspace.sections.isEmpty
    }
}

struct SectionRailView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
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
                        }
                        .padding(CTTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(workspace.selectedSectionKey == section.key ? CTTheme.cream : Color.clear)
                        .contentShape(Rectangle())
                        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.canvas)
    }
}

struct FilingReaderView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            if !workspace.readerAttachments.isEmpty {
                AttachmentStripView()
                    .environmentObject(workspace)
                Hairline()
            }
            Group {
                if workspace.isDocumentLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pdfData = workspace.readerPDFData {
                    FilingPDFView(data: pdfData)
                } else if !workspace.readerDisplayContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: CTTheme.Spacing.xl) {
                            MarkdownReaderText(
                                content: workspace.readerDisplayContent,
                                renderMarkdown: workspace.hasMarkdownReaderContent
                            )
                            .equatable()
                        }
                        .padding(CTTheme.Spacing.xl)
                        .frame(maxWidth: 760, alignment: .leading)
                    }
                } else {
                    ReaderEmptyDocumentView(document: workspace.selectedDocument)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MarkdownReaderText: View, Equatable {
    let content: String
    let renderMarkdown: Bool
    @State private var parsedMarkdown: MarkdownContent?
    @State private var parsedMarkdownSource = ""

    static func == (lhs: MarkdownReaderText, rhs: MarkdownReaderText) -> Bool {
        lhs.content == rhs.content && lhs.renderMarkdown == rhs.renderMarkdown
    }

    var body: some View {
        if renderMarkdown {
            Group {
                if parsedMarkdownSource == content, let parsedMarkdown {
                    Markdown(parsedMarkdown)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .onAppear(perform: parseMarkdownIfNeeded)
            .onChange(of: content) { _, _ in
                parseMarkdownIfNeeded()
            }
            .onChange(of: renderMarkdown) { _, _ in
                parseMarkdownIfNeeded()
            }
        } else {
            Text(content)
                .font(CTTheme.Typography.reader)
                .foregroundStyle(CTTheme.body)
                .lineSpacing(6)
                .textSelection(.enabled)
        }
    }

    private func parseMarkdownIfNeeded() {
        guard renderMarkdown else { return }
        guard parsedMarkdownSource != content || parsedMarkdown == nil else { return }
        parsedMarkdown = MarkdownContent(content)
        parsedMarkdownSource = content
    }
}

private struct ReaderEmptyDocumentView: View {
    let document: FilingDocument?

    var body: some View {
        VStack(spacing: CTTheme.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(CTTheme.muted)
            Text("No readable preview")
                .font(CTTheme.Typography.titleSmall)
                .foregroundStyle(CTTheme.ink)
            if let document {
                Text(document.displayTitle)
                    .font(CTTheme.Typography.body)
                    .foregroundStyle(CTTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(CTTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AttachmentStripView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CTTheme.Spacing.xs) {
                ForEach(workspace.readerAttachments) { document in
                    Button {
                        workspace.selectDocument(document)
                    } label: {
                        HStack(spacing: CTTheme.Spacing.xs) {
                            Image(systemName: document.isPDF ? "doc.richtext" : "doc.text")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(workspace.selectedDocumentID == document.id ? CTTheme.ink : CTTheme.muted)
                            Text(document.displayTitle)
                                .font(CTTheme.Typography.caption)
                                .foregroundStyle(CTTheme.ink)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, CTTheme.Spacing.sm)
                        .padding(.vertical, CTTheme.Spacing.xs)
                        .background(workspace.selectedDocumentID == document.id ? CTTheme.cream : CTTheme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous)
                                .stroke(workspace.selectedDocumentID == document.id ? CTTheme.link : CTTheme.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CTTheme.Spacing.lg)
            .padding(.vertical, CTTheme.Spacing.sm)
        }
        .background(CTTheme.canvas)
    }
}
