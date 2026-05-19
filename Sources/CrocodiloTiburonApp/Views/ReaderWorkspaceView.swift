import SwiftUI

struct ReaderWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            readerToolbar
            Divider()
            HStack(spacing: 0) {
                SectionRailView()
                    .frame(width: 210)
                Divider()
                FilingReaderView()
                    .frame(minWidth: 420)
                Divider()
                NotesPanelView()
                    .frame(width: 300)
            }
        }
        .background(CTTheme.canvas)
    }

    private var readerToolbar: some View {
        HStack(spacing: CTTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.selectedDocument?.description ?? "Reader")
                    .font(CTTheme.Typography.label)
                    .foregroundStyle(CTTheme.ink)
                Text(workspace.selectedDocument?.filename ?? "Select a filing document")
                    .font(CTTheme.Typography.caption)
                    .foregroundStyle(CTTheme.muted)
            }
            Spacer()
            Picker("Mode", selection: $workspace.readerMode) {
                ForEach(ReaderMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 248)
            Button("Compare years") {}
                .buttonStyle(CTSecondaryButtonStyle())
        }
        .padding(.horizontal, CTTheme.Spacing.lg)
        .frame(height: 72)
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
                                Text("~\(section.estimatedWordCount)")
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
        ScrollView {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.xl) {
                CTCard(background: CTTheme.surfaceDark) {
                    VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
                        Text("Item 1A. Risk Factors")
                            .font(CTTheme.Typography.displayMedium)
                            .foregroundStyle(.white)
                        Text("Parsed text placeholder. The live bridge will replace this with Document.get_section(title='item1a', format='text').")
                            .font(CTTheme.Typography.body)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(SampleData.readerText)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(CTTheme.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                CTCard(background: CTTheme.cream) {
                    VStack(alignment: .leading, spacing: CTTheme.Spacing.sm) {
                        Text("Next product move")
                            .font(CTTheme.Typography.titleSmall)
                        Text("Wire this reader to the Python datamule bridge, then cache section text in SQLite. Keep the original filing available in a WKWebView toggle.")
                            .font(CTTheme.Typography.body)
                            .foregroundStyle(CTTheme.body)
                    }
                }
            }
            .padding(CTTheme.Spacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

struct NotesPanelView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
            HStack {
                Text("Notes")
                    .font(CTTheme.Typography.label)
                    .foregroundStyle(CTTheme.ink)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            CTCard(background: CTTheme.peach) {
                VStack(alignment: .leading, spacing: CTTheme.Spacing.sm) {
                    Text("Quick note")
                        .font(CTTheme.Typography.titleSmall)
                    Text("Selection-based notes should land here without breaking reading flow.")
                        .font(CTTheme.Typography.body)
                }
            }
            ScrollView {
                LazyVStack(spacing: CTTheme.Spacing.md) {
                    ForEach(workspace.selectedNotes) { note in
                        NoteCard(note: note)
                    }
                }
            }
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.canvas)
    }
}

private struct NoteCard: View {
    let note: ResearchNote

    var body: some View {
        CTCard(background: CTTheme.surfaceSoft, border: CTTheme.hairline) {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.sm) {
                Text(note.title)
                    .font(CTTheme.Typography.titleSmall)
                    .foregroundStyle(CTTheme.ink)
                Text(note.body)
                    .font(CTTheme.Typography.body)
                    .foregroundStyle(CTTheme.body)
                    .fixedSize(horizontal: false, vertical: true)
                FlowTags(tags: note.tags)
            }
        }
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: CTTheme.Spacing.xs) {
            ForEach(tags, id: \.self) { tag in
                PillTag(text: tag, color: CTTheme.mint.opacity(0.55), textColor: CTTheme.forest)
            }
        }
    }
}
