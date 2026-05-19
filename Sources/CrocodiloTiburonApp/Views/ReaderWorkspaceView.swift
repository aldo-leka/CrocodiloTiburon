import SwiftUI

struct ReaderWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            readerToolbar
            Divider()
            HSplitView {
                SectionRailView()
                    .frame(minWidth: 160, idealWidth: 210, maxWidth: 320)
                FilingReaderView()
                    .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity)
                NotesPanelView()
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 460)
            }
            .frame(maxHeight: .infinity)
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
            Button("Reload doc") {
                Task { await workspace.loadSelectedDocumentContent() }
            }
                .buttonStyle(CTSecondaryButtonStyle())
                .disabled(workspace.isLoadingReader || workspace.selectedDocument == nil)
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
        Group {
            if workspace.isLoadingReader {
                VStack(spacing: CTTheme.Spacing.md) {
                    ProgressView()
                    Text("Loading SEC document...")
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.muted)
                }
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

struct NotesPanelView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
            HStack {
                Text("Notes")
                    .font(CTTheme.Typography.label)
                    .foregroundStyle(CTTheme.ink)
                Spacer()
                Button(action: workspace.beginNewNote) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            if workspace.isEditingNote {
                NoteEditorView()
            } else {
                Button(action: workspace.beginNewNote) {
                    CTCard(background: CTTheme.peach) {
                        VStack(alignment: .leading, spacing: CTTheme.Spacing.sm) {
                            Text("Quick note")
                                .font(CTTheme.Typography.titleSmall)
                            Text("Create a note for the selected company, filing, document, and section.")
                                .font(CTTheme.Typography.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                LazyVStack(spacing: CTTheme.Spacing.md) {
                    ForEach(workspace.selectedNotes) { note in
                        Button {
                            workspace.editNote(note)
                        } label: {
                            NoteCard(note: note)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.canvas)
    }
}

private struct NoteEditorView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        CTCard(background: CTTheme.surfaceSoft, border: CTTheme.hairline) {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.sm) {
                TextField("Title", text: $workspace.draftNoteTitle)
                    .textFieldStyle(.plain)
                    .font(CTTheme.Typography.titleSmall)
                TextEditor(text: $workspace.draftNoteBody)
                    .font(CTTheme.Typography.body)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(CTTheme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous)
                            .stroke(CTTheme.hairline, lineWidth: 1)
                    )
                TextField("tags, comma separated", text: $workspace.draftNoteTags)
                    .textFieldStyle(.roundedBorder)
                    .font(CTTheme.Typography.body)
                HStack {
                    Button("Cancel", action: workspace.cancelNoteEditing)
                        .buttonStyle(CTSecondaryButtonStyle())
                    Spacer()
                    if workspace.editingNoteID != nil {
                        Button("Delete", action: workspace.deleteEditingNote)
                            .buttonStyle(CTSecondaryButtonStyle())
                    }
                    Button("Save", action: workspace.saveDraftNote)
                        .buttonStyle(CTPrimaryButtonStyle())
                }
            }
        }
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
