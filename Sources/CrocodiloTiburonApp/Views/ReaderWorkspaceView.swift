import SwiftUI

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
                    .accessibilityIdentifier(CTAccessibility.readerSectionButton(key: section.key))
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
            if !workspace.readerDocuments.isEmpty {
                AttachmentStripView()
                    .environmentObject(workspace)
                Hairline()
            }
            Group {
                if workspace.shouldShowReaderLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier(CTAccessibility.readerLoading)
                } else if let pdfData = workspace.readerPDFData {
                    FilingPDFView(data: pdfData, accessibilityValue: workspace.readerContentAccessibilityValue)
                        .accessibilityIdentifier(CTAccessibility.readerPDF)
                        .accessibilityValue(workspace.readerContentAccessibilityValue)
                } else if !workspace.readerDisplayContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: CTTheme.Spacing.xl) {
                            ReaderBodyText(
                                content: workspace.readerDisplayContent,
                                sourceID: "\(workspace.readerContentAccessibilityValue):\(workspace.selectedSectionKey)",
                                renderMarkdown: workspace.isReaderDisplayContentMarkdown
                            )
                            .equatable()
                        }
                        .padding(CTTheme.Spacing.xl)
                        .frame(maxWidth: 760, alignment: .leading)
                    }
                    .accessibilityIdentifier(CTAccessibility.readerText)
                    .accessibilityValue(workspace.readerContentAccessibilityValue)
                } else {
                    ReaderEmptyDocumentView(document: workspace.selectedDocument)
                        .accessibilityValue(workspace.readerContentAccessibilityValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ReaderBodyText: View, Equatable {
    let content: String
    let sourceID: String
    let renderMarkdown: Bool
    @State private var blocks: [ReaderContentBlock] = []
    @State private var blockSource: ReaderContentSource?

    static func == (lhs: ReaderBodyText, rhs: ReaderBodyText) -> Bool {
        lhs.sourceID == rhs.sourceID && lhs.renderMarkdown == rhs.renderMarkdown
    }

    var body: some View {
        Group {
            if blockSource == source, !blocks.isEmpty {
                LazyVStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
                    ForEach(blocks) { block in
                        ReaderContentBlockView(block: block)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .task(id: source) {
            await prepareBlocks()
        }
        .onChange(of: content) { _, _ in
            clearBlocksIfNeeded()
        }
        .onChange(of: renderMarkdown) { _, _ in
            clearBlocksIfNeeded()
        }
    }

    private var source: ReaderContentSource {
        ReaderContentSource(id: sourceID, renderMarkdown: renderMarkdown)
    }

    private func clearBlocksIfNeeded() {
        if blockSource != source {
            blocks = []
        }
    }

    private func prepareBlocks() async {
        let currentSource = source
        if blockSource == currentSource, !blocks.isEmpty {
            return
        }

        let content = content
        let renderMarkdown = renderMarkdown
        let preparedBlocks = await Task.detached(priority: .userInitiated) {
            ReaderContentParser.blocks(for: content, renderMarkdown: renderMarkdown)
        }.value

        guard !Task.isCancelled else { return }
        blocks = preparedBlocks
        blockSource = currentSource
    }
}

private struct ReaderContentSource: Hashable {
    var id: String
    var renderMarkdown: Bool
}

private struct ReaderContentBlock: Identifiable, Sendable {
    let id: Int
    let kind: ReaderContentBlockKind
    let text: String
    let attributedText: AttributedString
}

private enum ReaderContentBlockKind: Sendable {
    case heading(level: Int)
    case paragraph
    case listItem(marker: String)
    case blockquote
    case code
    case table(ReaderMarkdownTable)
    case divider
}

private struct ReaderMarkdownTable: Sendable {
    var rows: [ReaderMarkdownTableRow]
    var columnAlignments: [ReaderMarkdownTableColumnAlignment]
}

private struct ReaderMarkdownTableRow: Identifiable, Sendable {
    var id: Int
    var isHeader: Bool
    var cells: [ReaderMarkdownTableCell]
}

private struct ReaderMarkdownTableCell: Identifiable, Sendable {
    var id: Int
    var text: String
    var attributedText: AttributedString
    var alignment: ReaderMarkdownTableColumnAlignment
}

private enum ReaderMarkdownTableColumnAlignment: Sendable {
    case leading
    case center
    case trailing

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

private struct ReaderContentBlockView: View {
    let block: ReaderContentBlock

    var body: some View {
        switch block.kind {
        case .heading(let level):
            Text(block.attributedText)
                .font(headingFont(for: level))
                .bold()
                .foregroundStyle(CTTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level == 1 ? CTTheme.Spacing.sm : CTTheme.Spacing.xs)
        case .paragraph:
            Text(block.attributedText)
                .font(CTTheme.Typography.reader)
                .foregroundStyle(CTTheme.body)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .listItem(let marker):
            HStack(alignment: .firstTextBaseline, spacing: CTTheme.Spacing.sm) {
                Text(marker)
                    .font(CTTheme.Typography.reader)
                    .foregroundStyle(CTTheme.muted)
                    .frame(minWidth: 18, alignment: .trailing)
                Text(block.attributedText)
                    .font(CTTheme.Typography.reader)
                    .foregroundStyle(CTTheme.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .blockquote:
            HStack(alignment: .top, spacing: CTTheme.Spacing.md) {
                Rectangle()
                    .fill(CTTheme.hairline)
                    .frame(width: 3)
                Text(block.attributedText)
                    .font(CTTheme.Typography.reader)
                    .foregroundStyle(CTTheme.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .code:
            Text(verbatim: block.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(CTTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CTTheme.Spacing.sm)
                .background(CTTheme.surfaceSoft)
                .clipShape(.rect(cornerRadius: CTTheme.Radius.sm))
        case .table(let table):
            ReaderMarkdownTableView(table: table)
        case .divider:
            Hairline()
                .padding(.vertical, CTTheme.Spacing.xs)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        default: .headline
        }
    }
}

private struct ReaderMarkdownTableView: View {
    let table: ReaderMarkdownTable

    var body: some View {
        ScrollView(.horizontal) {
            Grid(
                alignment: .leading,
                horizontalSpacing: 0,
                verticalSpacing: 0
            ) {
                ForEach(table.rows) { row in
                    GridRow {
                        ForEach(row.cells) { cell in
                            Text(cell.attributedText)
                                .font(row.isHeader ? CTTheme.Typography.body : CTTheme.Typography.caption)
                                .bold(row.isHeader)
                                .foregroundStyle(row.isHeader ? CTTheme.ink : CTTheme.body)
                                .lineLimit(nil)
                                .textSelection(.enabled)
                                .frame(
                                    minWidth: 120,
                                    maxWidth: 260,
                                    alignment: cell.alignment.frameAlignment
                                )
                                .padding(.horizontal, CTTheme.Spacing.sm)
                                .padding(.vertical, CTTheme.Spacing.xs)
                                .background(row.isHeader ? CTTheme.surfaceSoft : CTTheme.canvas)
                                .overlay {
                                    Rectangle()
                                        .stroke(CTTheme.hairline, lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: CTTheme.Radius.sm))
        }
    }
}

private struct ReaderMarkdownBlock {
    var kind: ReaderContentBlockKind
    let content: String
}

private enum ReaderContentParser {
    private static let smallDocumentLimit = 36_000
    private static let preferredChunkLimit = 24_000
    private static let markdownOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    static func blocks(for content: String, renderMarkdown: Bool) -> [ReaderContentBlock] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let parsedBlocks = renderMarkdown
            ? markdownBlocks(from: trimmed).flatMap(splitOversizedMarkdownBlock)
            : paragraphBlocks(from: trimmed).flatMap { splitOversizedTextBlock($0, kind: .paragraph) }

        return parsedBlocks.enumerated().map { index, block in
            ReaderContentBlock(
                id: index,
                kind: block.kind,
                text: block.content,
                attributedText: attributedString(for: block)
            )
        }
    }

    private static func splitOversizedMarkdownBlock(_ block: ReaderMarkdownBlock) -> [ReaderMarkdownBlock] {
        switch block.kind {
        case .paragraph, .listItem, .blockquote:
            splitOversizedTextBlock(block.content, kind: block.kind)
        default:
            [block]
        }
    }

    private static func splitOversizedTextBlock(
        _ block: String,
        kind: ReaderContentBlockKind
    ) -> [ReaderMarkdownBlock] {
        guard block.count > preferredChunkLimit else {
            return [ReaderMarkdownBlock(kind: kind, content: block)]
        }

        return splitOversizedBlock(block).map {
            ReaderMarkdownBlock(kind: kind, content: $0)
        }
    }

    private static func attributedString(for block: ReaderMarkdownBlock) -> AttributedString {
        switch block.kind {
        case .code, .table, .divider:
            AttributedString(block.content)
        default:
            (try? AttributedString(markdown: block.content, options: markdownOptions))
                ?? AttributedString(block.content)
        }
    }

    private static func markdownBlocks(from content: String) -> [ReaderMarkdownBlock] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [ReaderMarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var isInFence = false
        var lineIndex = 0

        func flushParagraph() {
            let content = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                blocks.append(ReaderMarkdownBlock(kind: inferredKind(for: content), content: content))
            }
            paragraph = []
        }

        func flushCode() {
            let content = code.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                blocks.append(ReaderMarkdownBlock(kind: .code, content: content))
            }
            code = []
        }

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let startsFence = trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")

            if startsFence {
                if isInFence {
                    flushCode()
                    isInFence = false
                } else {
                    flushParagraph()
                    isInFence = true
                }
                lineIndex += 1
                continue
            }

            if isInFence {
                code.append(line)
                lineIndex += 1
                continue
            }

            if trimmedLine.isEmpty {
                flushParagraph()
                lineIndex += 1
                continue
            }

            if let tableBlock = tableBlock(startingAt: lineIndex, in: lines) {
                flushParagraph()
                blocks.append(tableBlock.block)
                lineIndex += tableBlock.lineCount
                continue
            }

            if let codeBlock = indentedCodeBlock(startingAt: lineIndex, in: lines) {
                flushParagraph()
                blocks.append(codeBlock.block)
                lineIndex += codeBlock.lineCount
                continue
            }

            if let quoteBlock = blockquoteBlock(startingAt: lineIndex, in: lines) {
                flushParagraph()
                blocks.append(quoteBlock.block)
                lineIndex += quoteBlock.lineCount
                continue
            }

            if let listItem = listItem(from: trimmedLine) {
                flushParagraph()
                blocks.append(listItem)
                lineIndex += 1
                continue
            }

            if let heading = heading(from: trimmedLine) {
                flushParagraph()
                blocks.append(heading)
                lineIndex += 1
                continue
            }

            if isDivider(trimmedLine) {
                flushParagraph()
                blocks.append(ReaderMarkdownBlock(kind: .divider, content: ""))
                lineIndex += 1
                continue
            }

            paragraph.append(line)
            lineIndex += 1
        }

        if isInFence {
            flushCode()
        } else {
            flushParagraph()
        }

        return blocks.isEmpty ? [ReaderMarkdownBlock(kind: .paragraph, content: content)] : blocks
    }

    private static func inferredKind(for content: String) -> ReaderContentBlockKind {
        return .paragraph
    }

    private static func tableBlock(
        startingAt index: Int,
        in lines: [String]
    ) -> (block: ReaderMarkdownBlock, lineCount: Int)? {
        guard index + 1 < lines.count else { return nil }
        let headerLine = lines[index]
        let separatorLine = lines[index + 1]
        guard
            containsUnescapedPipe(headerLine),
            let alignments = tableColumnAlignments(from: separatorLine)
        else { return nil }

        let headerCells = normalizedTableCells(splitTableRow(headerLine), columnCount: alignments.count)
        guard !headerCells.isEmpty else { return nil }

        var rawLines = [headerLine, separatorLine]
        var bodyRows: [[String]] = []
        var lineIndex = index + 2

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, containsUnescapedPipe(line) else { break }
            bodyRows.append(normalizedTableCells(splitTableRow(line), columnCount: alignments.count))
            rawLines.append(line)
            lineIndex += 1
        }

        var rows: [ReaderMarkdownTableRow] = [
            ReaderMarkdownTableRow(
                id: 0,
                isHeader: true,
                cells: tableCells(from: headerCells, alignments: alignments)
            )
        ]
        rows += bodyRows.enumerated().map { index, cells in
            ReaderMarkdownTableRow(
                id: index + 1,
                isHeader: false,
                cells: tableCells(from: cells, alignments: alignments)
            )
        }

        let table = ReaderMarkdownTable(rows: rows, columnAlignments: alignments)
        let content = rawLines.joined(separator: "\n")
        return (
            ReaderMarkdownBlock(kind: .table(table), content: content),
            rawLines.count
        )
    }

    private static func tableColumnAlignments(from line: String) -> [ReaderMarkdownTableColumnAlignment]? {
        let cells = splitTableRow(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [ReaderMarkdownTableColumnAlignment] = []

        for rawCell in cells {
            let cell = rawCell.trimmingCharacters(in: .whitespaces)
            guard cell.contains("-") else { return nil }
            guard cell.allSatisfy({ $0 == ":" || $0 == "-" || $0.isWhitespace }) else {
                return nil
            }
            let hyphenCount = cell.filter { $0 == "-" }.count
            guard hyphenCount >= 3 else { return nil }

            let startsWithColon = cell.first == ":"
            let endsWithColon = cell.last == ":"
            switch (startsWithColon, endsWithColon) {
            case (true, true):
                alignments.append(.center)
            case (false, true):
                alignments.append(.trailing)
            default:
                alignments.append(.leading)
            }
        }

        return alignments
    }

    private static func tableCells(
        from cells: [String],
        alignments: [ReaderMarkdownTableColumnAlignment]
    ) -> [ReaderMarkdownTableCell] {
        alignments.indices.map { index in
            let text = cells.indices.contains(index) ? cells[index] : ""
            return ReaderMarkdownTableCell(
                id: index,
                text: text,
                attributedText: (try? AttributedString(markdown: text, options: markdownOptions))
                    ?? AttributedString(text),
                alignment: alignments[index]
            )
        }
    }

    private static func normalizedTableCells(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count >= columnCount {
            return Array(cells.prefix(columnCount))
        }
        return cells + Array(repeating: "", count: columnCount - cells.count)
    }

    private static func splitTableRow(_ line: String) -> [String] {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        var cells: [String] = []
        var current = ""
        var isEscaping = false

        for character in trimmedLine {
            if isEscaping {
                if character == "|" {
                    current.append(character)
                } else {
                    current.append("\\")
                    current.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }

        if isEscaping {
            current.append("\\")
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))

        if trimmedLine.hasPrefix("|"), cells.first == "" {
            cells.removeFirst()
        }
        if trimmedLine.hasSuffix("|"), cells.last == "" {
            cells.removeLast()
        }

        return cells
    }

    private static func containsUnescapedPipe(_ line: String) -> Bool {
        var isEscaping = false
        for character in line {
            if isEscaping {
                isEscaping = false
                continue
            }
            if character == "\\" {
                isEscaping = true
                continue
            }
            if character == "|" {
                return true
            }
        }
        return false
    }

    private static func blockquoteBlock(
        startingAt index: Int,
        in lines: [String]
    ) -> (block: ReaderMarkdownBlock, lineCount: Int)? {
        var quoteLines: [String] = []
        var lineIndex = index

        while lineIndex < lines.count {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(">") else { break }
            var quoteLine = String(line.dropFirst())
            if quoteLine.first?.isWhitespace == true {
                quoteLine.removeFirst()
            }
            quoteLines.append(quoteLine)
            lineIndex += 1
        }

        guard !quoteLines.isEmpty else { return nil }
        let content = quoteLines.joined(separator: "\n")
        return (
            ReaderMarkdownBlock(kind: .blockquote, content: content),
            quoteLines.count
        )
    }

    private static func indentedCodeBlock(
        startingAt index: Int,
        in lines: [String]
    ) -> (block: ReaderMarkdownBlock, lineCount: Int)? {
        guard lines[index].hasPrefix("    ") || lines[index].hasPrefix("\t") else {
            return nil
        }

        var codeLines: [String] = []
        var lineIndex = index
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            if line.hasPrefix("    ") {
                codeLines.append(String(line.dropFirst(4)))
            } else if line.hasPrefix("\t") {
                codeLines.append(String(line.dropFirst()))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                codeLines.append("")
            } else {
                break
            }
            lineIndex += 1
        }

        let content = codeLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return (
            ReaderMarkdownBlock(kind: .code, content: content),
            lineIndex - index
        )
    }

    private static func listItem(from line: String) -> ReaderMarkdownBlock? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            let content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return ReaderMarkdownBlock(kind: .listItem(marker: "•"), content: content)
        }

        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let marker = line[...dotIndex]
        guard marker.dropLast().allSatisfy(\.isNumber) else { return nil }
        let contentStart = line.index(after: dotIndex)
        guard contentStart < line.endIndex, line[contentStart].isWhitespace else { return nil }
        let content = line[contentStart...].trimmingCharacters(in: .whitespaces)
        return ReaderMarkdownBlock(kind: .listItem(marker: String(marker)), content: content)
    }

    private static func heading(from line: String) -> ReaderMarkdownBlock? {
        let markerCount = line.prefix { $0 == "#" }.count
        guard (1...6).contains(markerCount) else { return nil }
        let markerEnd = line.index(line.startIndex, offsetBy: markerCount)
        guard markerEnd < line.endIndex, line[markerEnd].isWhitespace else { return nil }
        let title = line[markerEnd...].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return ReaderMarkdownBlock(kind: .heading(level: markerCount), content: title)
    }

    private static func isDivider(_ line: String) -> Bool {
        let characters = line.filter { !$0.isWhitespace }
        guard characters.count >= 3 else { return false }
        return Set(characters).isSubset(of: ["-"])
            || Set(characters).isSubset(of: ["*"])
            || Set(characters).isSubset(of: ["_"])
    }

    private static func append(
        _ block: String,
        to current: inout String,
        chunks: inout [String]
    ) {
        let separator = current.isEmpty ? "" : "\n\n"
        let candidateLength = current.count + separator.count + block.count
        if candidateLength > preferredChunkLimit, !current.isEmpty {
            chunks.append(current)
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

    private static func paragraphBlocks(from content: String) -> [String] {
        guard content.count > smallDocumentLimit else {
            return [content]
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [String] = []
        var current: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            current.append(line)

            if trimmedLine.isEmpty, !current.isEmpty {
                blocks.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                current = []
            }
        }

        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var result: [String] = []
        var chunk = ""
        for block in blocks.filter({ !$0.isEmpty }).flatMap(splitOversizedBlock) {
            append(block, to: &chunk, chunks: &result)
        }
        if !chunk.isEmpty {
            result.append(chunk)
        }

        return result.isEmpty ? [content] : result
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
        .accessibilityIdentifier(CTAccessibility.readerEmpty)
    }
}

private struct AttachmentStripView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CTTheme.Spacing.xs) {
                ForEach(workspace.readerDocuments) { document in
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
                    .accessibilityIdentifier(CTAccessibility.readerDocumentButton(id: document.id))
                    .accessibilityLabel(document.displayTitle)
                    .accessibilityValue(
                        "\(document.filename)|\(document.id.uuidString.lowercased())|\(document.filingID.uuidString.lowercased())"
                    )
                }
            }
            .padding(.horizontal, CTTheme.Spacing.lg)
            .padding(.vertical, CTTheme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .background(CTTheme.canvas)
        .accessibilityIdentifier(CTAccessibility.readerDocumentStrip)
    }
}
