import SwiftUI
import Textual

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
                            TextualReaderText(
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

private struct TextualReaderText: View, Equatable {
    let content: String
    let renderMarkdown: Bool
    @State private var chunks: [ReaderContentChunk] = []
    @State private var chunkSource = ""

    static func == (lhs: TextualReaderText, rhs: TextualReaderText) -> Bool {
        lhs.content == rhs.content && lhs.renderMarkdown == rhs.renderMarkdown
    }

    var body: some View {
        if renderMarkdown {
            Group {
                if chunkSource == content, !chunks.isEmpty {
                    LazyVStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
                        ForEach(chunks) { chunk in
                            StructuredText(markdown: chunk.content)
                                .textual.structuredTextStyle(.gitHub)
                                .textual.textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .onAppear(perform: prepareChunksIfNeeded)
            .onChange(of: content) { _, _ in
                prepareChunksIfNeeded()
            }
            .onChange(of: renderMarkdown) { _, _ in
                prepareChunksIfNeeded()
            }
        } else {
            Text(content)
                .font(CTTheme.Typography.reader)
                .foregroundStyle(CTTheme.body)
                .lineSpacing(6)
                .textSelection(.enabled)
        }
    }

    private func prepareChunksIfNeeded() {
        guard renderMarkdown else { return }
        guard chunkSource != content || chunks.isEmpty else { return }
        chunks = ReaderMarkdownChunker.chunks(for: content)
        chunkSource = content
    }
}

private struct ReaderContentChunk: Identifiable, Equatable {
    let id: Int
    let content: String
}

private enum ReaderMarkdownChunker {
    private static let smallDocumentLimit = 36_000
    private static let preferredChunkLimit = 24_000

    static func chunks(for content: String) -> [ReaderContentChunk] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > smallDocumentLimit else {
            return [ReaderContentChunk(id: 0, content: trimmed)]
        }

        let blocks = markdownBlocks(from: trimmed)
        var result: [ReaderContentChunk] = []
        var current = ""

        for block in blocks.flatMap(splitOversizedBlock) {
            append(block, to: &current, chunks: &result)
        }

        if !current.isEmpty {
            result.append(ReaderContentChunk(id: result.count, content: current))
        }

        return result.isEmpty ? [ReaderContentChunk(id: 0, content: trimmed)] : result
    }

    private static func append(
        _ block: String,
        to current: inout String,
        chunks: inout [ReaderContentChunk]
    ) {
        let separator = current.isEmpty ? "" : "\n\n"
        let candidateLength = current.count + separator.count + block.count
        if candidateLength > preferredChunkLimit, !current.isEmpty {
            chunks.append(ReaderContentChunk(id: chunks.count, content: current))
            current = block
        } else {
            current += separator + block
        }
    }

    private static func splitOversizedBlock(_ block: String) -> [String] {
        guard block.count > preferredChunkLimit else { return [block] }

        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var current = ""

        for line in lines {
            if line.count > preferredChunkLimit {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
                result.append(contentsOf: splitOversizedLine(line))
                continue
            }

            let separator = current.isEmpty ? "" : "\n"
            let candidateLength = current.count + separator.count + line.count
            if candidateLength > preferredChunkLimit, !current.isEmpty {
                result.append(current)
                current = line
            } else {
                current += separator + line
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private static func splitOversizedLine(_ line: String) -> [String] {
        var result: [String] = []
        var startIndex = line.startIndex

        while startIndex < line.endIndex {
            let endIndex = line.index(
                startIndex,
                offsetBy: preferredChunkLimit,
                limitedBy: line.endIndex
            ) ?? line.endIndex
            result.append(String(line[startIndex..<endIndex]))
            startIndex = endIndex
        }

        return result
    }

    private static func markdownBlocks(from content: String) -> [String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [String] = []
        var current: [String] = []
        var isInFence = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let startsFence = trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
            let startsHeading = trimmedLine.hasPrefix("#")

            if startsHeading, !current.isEmpty, !isInFence {
                blocks.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                current = []
            }

            current.append(line)

            if startsFence {
                isInFence.toggle()
            }

            if trimmedLine.isEmpty, !current.isEmpty, !isInFence {
                blocks.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                current = []
            }
        }

        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return blocks.filter { !$0.isEmpty }
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
