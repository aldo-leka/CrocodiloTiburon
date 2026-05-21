import Foundation
import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    private static let excludeOwnershipReportsKey = "filings.excludeOwnershipReports"
    private static let ownershipReportForms: Set<String> = ["3", "3/A", "4", "4/A", "5", "5/A"]
    private static let nonOwnershipSearchForms = ["-0", "-3", "-3/A", "-4", "-4/A", "-5", "-5/A"]
    private static let maxReaderContentCacheEntries = 24

    private static func initialExcludeOwnershipReports() -> Bool {
        if ProcessInfo.processInfo.environment["CROCODILO_INCLUDE_OWNERSHIP_REPORTS"] == "1" {
            return false
        }

        return UserDefaults.standard.object(forKey: excludeOwnershipReportsKey) as? Bool ?? true
    }

    @Published var companies: [Company] = []
    @Published var filings: [Filing] = []
    @Published var documents: [FilingDocument] = []
    @Published var sections: [ReaderSection] = []
    @Published var notes: [ResearchNote] = []
    @Published var selectedCompanyID: Company.ID?
    @Published var selectedFilingID: Filing.ID?
    @Published var selectedDocumentID: FilingDocument.ID?
    @Published var selectedSectionKey: String = ""
    @Published var query: String = ""
    @Published var shouldFocusSearch: Bool = false
    @Published var isLoadingSEC: Bool = false
    @Published var isLoadingReader: Bool = false
    @Published var isLoadingDocuments: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var readerText: String = ""
    @Published var readerMarkdown: String = ""
    @Published var readerPDFData: Data?
    @Published var isEditingNote: Bool = false
    @Published var editingNoteID: ResearchNote.ID?
    @Published var draftNoteTitle: String = ""
    @Published var draftNoteBody: String = ""
    @Published var draftNoteTags: String = ""
    @Published var selectedCompanyProfileSummary: String = ""
    @Published var isLoadingCompanyProfile: Bool = false
    @Published var excludeOwnershipReports: Bool = WorkspaceStore.initialExcludeOwnershipReports()

    private let database: LocalDatabase?
    private var datamuleBridge = DatamuleBridge()
    private var companySelectionVersion = 0
    private var readerLoadVersion = 0
    private var companyRefreshTask: Task<Void, Never>?
    private var companyProfileTask: Task<Void, Never>?
    private var readerSectionsCache: [ReaderDocumentCacheKey: [ReaderSection]] = [:]
    private var readerContentCache: [ReaderContentCacheKey: ReaderContentPayload] = [:]
    private var readerContentCacheOrder: [ReaderContentCacheKey] = []
    private var preparedReaderFilingAccessions = Set<String>()
    private var uiTestCommandTask: Task<Void, Never>?

    init() {
        let initialCompanies = SampleData.companies
        let initialFilings = SampleData.filings
        let initialDocuments = SampleData.documents(for: SampleData.apple10KID)
        let initialNotes = SampleData.notes
        var loadedDatabase: LocalDatabase?
        var startupError: Error?

        companies = initialCompanies
        filings = initialFilings
        documents = initialDocuments
        notes = initialNotes
        selectedCompanyID = initialCompanies.first?.id
        selectedFilingID = initialFilings.first?.id
        selectedDocumentID = initialDocuments.first?.id

        do {
            let database = try LocalDatabase.appDatabase()
            try database.seedIfNeeded()
            loadedDatabase = database
        } catch {
            startupError = error
        }

        self.database = loadedDatabase

        if let database = loadedDatabase {
            configureDatamuleCache(databasePath: database.path)
            do {
                try reloadFromDatabase(preferLastOpenedCompany: true)
                prepareSelectedCompanyProfileLoad(selectionVersion: companySelectionVersion)
                startSelectedDocumentContentLoadIfNeeded()
                refreshSelectedCompanyFilingsIfNeeded(selectionVersion: companySelectionVersion)
                statusMessage = "Datamule queue ready."
                Task { await loadTickerUniverseIfNeeded() }
            } catch {
                errorMessage = "SQLite opened, but loading data failed. \(error.localizedDescription)"
            }
        } else if let startupError {
            errorMessage = "SQLite failed to open; using in-memory sample data. \(startupError.localizedDescription)"
        }

        startUITestCommandLoopIfNeeded()
    }

    var selectedCompany: Company? {
        companies.first(where: { $0.id == selectedCompanyID })
    }

    var selectedFiling: Filing? {
        filings.first(where: { $0.id == selectedFilingID })
    }

    var selectedDocument: FilingDocument? {
        documents.first(where: { $0.id == selectedDocumentID })
    }

    var selectedSection: ReaderSection? {
        sections.first(where: { $0.key == selectedSectionKey })
    }

    var readerDocuments: [FilingDocument] {
        documents.filter(\.isReaderDisplayable)
    }

    var readerAttachments: [FilingDocument] {
        readerDocuments.filter { !$0.isMainDocument }
    }

    var readerDisplayText: String {
        readerText.trimmingCharacters(in: .whitespacesAndNewlines) == "None" ? "" : readerText
    }

    var readerDisplayMarkdown: String {
        readerMarkdown.trimmingCharacters(in: .whitespacesAndNewlines) == "None" ? "" : readerMarkdown
    }

    var readerDisplayContent: String {
        let markdown = readerDisplayMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if shouldRenderMarkdownReaderContent {
            return readerDisplayMarkdown
        }

        let text = readerDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return readerDisplayText
        }

        if !markdown.isEmpty {
            return readerDisplayMarkdown
        }

        return ""
    }

    var readerContentAccessibilityValue: String {
        let documentID = selectedDocumentID?.uuidString.lowercased() ?? "none"
        let filename = selectedDocument?.filename ?? "none"

        if let readerPDFData {
            return "pdf:\(documentID):\(filename):\(readerPDFData.count)"
        }

        let contentLength = readerDisplayContent.trimmingCharacters(in: .whitespacesAndNewlines).count
        if contentLength > 0 {
            let contentKind = hasMarkdownReaderContent ? "markdown" : "text"
            return "\(contentKind):\(documentID):\(filename):\(contentLength)"
        }

        return "empty:\(documentID):\(filename):0"
    }

    var hasMarkdownReaderContent: Bool {
        shouldRenderMarkdownReaderContent
    }

    private var shouldRenderMarkdownReaderContent: Bool {
        !readerDisplayMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isDocumentLoading: Bool {
        isLoadingReader || isLoadingDocuments
    }

    var shouldShowReaderLoading: Bool {
        if isLoadingReader { return true }

        return isLoadingDocuments
            && selectedDocument == nil
            && readerPDFData == nil
            && readerDisplayContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isAppLoading: Bool {
        isLoadingSEC || isLoadingReader || isLoadingDocuments || isLoadingCompanyProfile
    }

    var hasReaderContent: Bool {
        isDocumentLoading
            || readerPDFData != nil
            || !readerDocuments.isEmpty
            || !sections.isEmpty
            || !readerDisplayContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredCompanies: [Company] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return companies }
        return companies.filter {
            $0.ticker.localizedStandardContains(searchQuery) ||
            $0.name.localizedStandardContains(searchQuery) ||
            $0.cik.localizedStandardContains(searchQuery)
        }
    }

    var openedCompanyIDs: Set<Company.ID> {
        Set(filings.lazy.filter { $0.readStatus != .unread }.map(\.companyID))
    }

    var selectedCompanyFilings: [Filing] {
        guard let selectedCompanyID else { return [] }
        return filings.filter { filing in
            filing.companyID == selectedCompanyID
                && (!excludeOwnershipReports || !Self.isOwnershipReport(filing.form))
        }
            .sorted { $0.filingDate > $1.filingDate }
    }

    var selectedNotes: [ResearchNote] {
        guard let selectedCompanyID else { return [] }
        return notes.filter { $0.companyID == selectedCompanyID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var selectedCompanyOverviewDescription: String {
        if !selectedCompanyProfileSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedCompanyProfileSummary
        }
        if isLoadingCompanyProfile {
            return ""
        }
        guard let selectedCompany else {
            return "Select a company to load its filings and metadata."
        }
        return fallbackDescription(for: selectedCompany)
    }

    func focusSearch() {
        shouldFocusSearch = true
    }

    func selectCompany(_ company: Company) {
        companySelectionVersion += 1
        let selectionVersion = companySelectionVersion

        selectedCompanyID = company.id
        touchCompany(company.id)
        let firstFiling = selectedCompanyFilings.first
        selectedFilingID = firstFiling?.id
        loadDocumentsForSelectedFiling(preserveCurrentSelection: false)
        resetReaderPrompt()
        startSelectedDocumentContentLoadIfNeeded()
        prepareSelectedCompanyProfileLoad(selectionVersion: selectionVersion)

        companyRefreshTask?.cancel()
        refreshSelectedCompanyFilingsIfNeeded(selectionVersion: selectionVersion)
    }

    func selectFiling(_ filing: Filing) {
        selectedFilingID = filing.id
        markFilingOpened(filing)
        loadDocumentsForSelectedFiling(preserveCurrentSelection: false)
        resetReaderPrompt()

        if selectedDocumentID != nil {
            startSelectedDocumentContentLoadIfNeeded()
        } else {
            isLoadingDocuments = true
            Task { await refreshSelectedFilingDocuments() }
        }
    }

    func selectDocument(_ document: FilingDocument) {
        guard selectedDocumentID != document.id else {
            startSelectedDocumentContentLoadIfNeeded()
            return
        }

        selectedDocumentID = document.id
        if let filing = selectedFiling {
            markFilingOpened(filing)
        }
        startSelectedDocumentContentLoadIfNeeded()
    }

    func selectSection(_ section: ReaderSection) {
        selectedSectionKey = section.key
        if selectedDocument != nil {
            startSelectedDocumentContentLoadIfNeeded()
        }
    }

    func loadTickerUniverseIfNeeded() async {
        guard let database else { return }

        do {
            guard try database.companyCount() < 10_000 else { return }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        isLoadingSEC = true
        isLoadingDocuments = true
        errorMessage = nil
        statusMessage = ""
        defer {
            isLoadingSEC = false
            isLoadingDocuments = false
        }

        do {
            let response = try await datamuleBridge.tickers()
            let universe = companies(from: response.companies)
            try database.upsertCompanies(universe)
            try reloadFromDatabase(preferredCompanyID: selectedCompanyID)
            statusMessage = ""
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Could not load datamule ticker universe."
        }
    }

    func setExcludeOwnershipReports(_ shouldExclude: Bool) {
        guard excludeOwnershipReports != shouldExclude else { return }
        excludeOwnershipReports = shouldExclude
        UserDefaults.standard.set(shouldExclude, forKey: Self.excludeOwnershipReportsKey)

        if let currentFilingID = selectedFilingID,
           !selectedCompanyFilings.contains(where: { $0.id == currentFilingID }) {
            selectedFilingID = selectedCompanyFilings.first?.id
            loadDocumentsForSelectedFiling(preserveCurrentSelection: false)
            resetReaderPrompt()
            startSelectedDocumentContentLoadIfNeeded()
        }

        companyRefreshTask?.cancel()
        refreshSelectedCompanyFilingsIfNeeded(selectionVersion: companySelectionVersion)
    }

    func refreshSelectedCompanyFilings(
        expectedCompanyID: Company.ID? = nil,
        selectionVersion: Int? = nil
    ) async {
        guard let database else { return }
        guard let company = expectedCompanyID.flatMap({ self.company(id: $0) }) ?? selectedCompany else { return }

        isLoadingSEC = true
        errorMessage = nil
        statusMessage = ""
        defer { isLoadingSEC = false }

        do {
            let response = try await datamuleBridge.search(
                ticker: company.ticker,
                forms: excludeOwnershipReports ? Self.nonOwnershipSearchForms : nil,
                start: "2001-01-01",
                end: searchEndDate()
            )
            let fetchedFilings = filings(from: response.results, company: company)
            try database.upsertFilings(fetchedFilings)

            guard shouldApplyAsyncResult(companyID: company.id, selectionVersion: selectionVersion) else {
                return
            }

            try reloadFromDatabase(
                preferredCompanyID: company.id,
                preferredFilingID: selectedFilingID,
                preferredDocumentID: selectedDocumentID
            )
            statusMessage = ""
            if let selectedFilingID {
                await refreshSelectedFilingDocuments(
                    expectedCompanyID: company.id,
                    expectedFilingID: selectedFilingID,
                    selectionVersion: selectionVersion
                )
            }
        } catch {
            guard shouldApplyAsyncResult(companyID: company.id, selectionVersion: selectionVersion) else {
                return
            }
            errorMessage = error.localizedDescription
            statusMessage = "Could not fetch datamule filings for \(company.ticker)."
        }
    }

    func refreshSelectedFilingDocuments(
        expectedCompanyID: Company.ID? = nil,
        expectedFilingID: Filing.ID? = nil,
        selectionVersion: Int? = nil
    ) async {
        guard let database else { return }
        guard let company = expectedCompanyID.flatMap({ self.company(id: $0) }) ?? selectedCompany else { return }
        guard let filing = expectedFilingID.flatMap({ self.filing(id: $0) }) ?? selectedFiling else { return }
        guard filing.companyID == company.id else { return }

        isLoadingSEC = true
        isLoadingDocuments = true
        errorMessage = nil
        statusMessage = ""
        defer {
            isLoadingSEC = false
            isLoadingDocuments = false
        }

        do {
            let filingDate = dayString(filing.filingDate)
            _ = try await datamuleBridge.download(
                ticker: company.ticker,
                forms: [filing.form],
                start: filingDate,
                end: filingDate
            )
            let response = try await datamuleBridge.documents(accession: filing.accession)
            let fetchedDocuments = documents(from: response, filing: filing)
            try database.upsertDocuments(fetchedDocuments)

            var updatedFiling = filing
            updatedFiling.documentCount = fetchedDocuments.count
            updatedFiling.isDownloaded = true
            try database.upsertFilings([updatedFiling])

            guard shouldApplyAsyncResult(
                companyID: company.id,
                filingID: filing.id,
                selectionVersion: selectionVersion
            ) else {
                return
            }

            try reloadFromDatabase(
                preferredCompanyID: company.id,
                preferredFilingID: filing.id,
                preferredDocumentID: selectedDocumentID ?? preferredReaderDocument(in: fetchedDocuments)?.id
            )
            statusMessage = ""

            if selectedDocumentID != nil {
                await loadSelectedDocumentContent()
            }
        } catch {
            guard shouldApplyAsyncResult(
                companyID: company.id,
                filingID: filing.id,
                selectionVersion: selectionVersion
            ) else {
                return
            }
            errorMessage = error.localizedDescription
            statusMessage = "Could not cache datamule documents for \(filing.accession)."
        }
    }

    func loadSelectedDocumentContent() async {
        let requestVersion = beginReaderLoad()
        await loadSelectedDocumentContent(requestVersion: requestVersion)
    }

    private func loadSelectedDocumentContent(requestVersion expectedReaderLoadVersion: Int) async {
        guard let filing = selectedFiling, let document = selectedDocument else {
            resetReaderPrompt()
            return
        }
        guard let company = company(id: filing.companyID) else {
            resetReaderPrompt()
            return
        }
        let expectedFilingID = filing.id
        let expectedDocumentID = document.id

        isLoadingReader = true
        errorMessage = nil
        statusMessage = ""
        defer {
            if readerLoadVersion == expectedReaderLoadVersion {
                isLoadingReader = false
            }
        }

        do {
            try await prepareReaderFilingArchive(company: company, filing: filing)
            guard shouldApplyReaderResult(
                filingID: expectedFilingID,
                documentID: expectedDocumentID,
                requestVersion: expectedReaderLoadVersion
            ) else {
                return
            }

            if document.isPDF {
                let cacheKey = readerContentCacheKey(filing: filing, document: document, sectionKey: "")
                if let cachedContent = cachedReaderContent(for: cacheKey) {
                    guard shouldApplyReaderResult(
                        filingID: expectedFilingID,
                        documentID: expectedDocumentID,
                        requestVersion: expectedReaderLoadVersion
                    ) else {
                        return
                    }
                    readerPDFData = cachedContent.pdfData
                    readerText = cachedContent.text
                    readerMarkdown = cachedContent.markdown
                    sections = []
                    selectedSectionKey = ""
                    statusMessage = ""
                    return
                }

                let exported = try await datamuleBridge.exportDocument(
                    accession: filing.accession,
                    documentType: document.type,
                    filename: document.filename
                )
                guard let path = exported.path else {
                    throw DatamuleBridgeError.processFailed("Datamule did not return an exported document path.")
                }
                guard shouldApplyReaderResult(
                    filingID: expectedFilingID,
                    documentID: expectedDocumentID,
                    requestVersion: expectedReaderLoadVersion
                ) else {
                    return
                }
                let exportedURL = URL(fileURLWithPath: path)
                let pdfData = try Data(contentsOf: exportedURL)
                try? FileManager.default.removeItem(at: exportedURL)
                readerPDFData = pdfData
                readerText = ""
                readerMarkdown = ""
                sections = []
                selectedSectionKey = ""
                cacheReaderContent(
                    ReaderContentPayload(pdfData: pdfData, text: "", markdown: ""),
                    for: cacheKey
                )
            } else {
                readerPDFData = nil

                if document.canExtractSections {
                    let documentCacheKey = readerDocumentCacheKey(filing: filing, document: document)
                    let loadedSections: [ReaderSection]
                    if let cachedSections = readerSectionsCache[documentCacheKey] {
                        loadedSections = cachedSections
                    } else if let parsedSections = try? await datamuleBridge.sections(
                        accession: filing.accession,
                        documentType: document.type,
                        filename: document.filename
                    ) {
                        loadedSections = readerSections(from: parsedSections.sections)
                        readerSectionsCache[documentCacheKey] = loadedSections
                    } else {
                        loadedSections = []
                    }

                    if !loadedSections.isEmpty {
                        guard shouldApplyReaderResult(
                            filingID: expectedFilingID,
                            documentID: expectedDocumentID,
                            requestVersion: expectedReaderLoadVersion
                        ) else {
                            return
                        }
                        sections = loadedSections
                    } else {
                        sections = []
                    }

                    if let currentSection = sections.first(where: { $0.key == selectedSectionKey }) {
                        selectedSectionKey = currentSection.key
                    } else {
                        selectedSectionKey = sections.first?.key ?? ""
                    }

                    if let section = selectedSection {
                        let cacheKey = readerContentCacheKey(
                            filing: filing,
                            document: document,
                            sectionKey: section.key
                        )
                        if let cachedContent = cachedReaderContent(for: cacheKey) {
                            guard shouldApplyReaderResult(
                                filingID: expectedFilingID,
                                documentID: expectedDocumentID,
                                requestVersion: expectedReaderLoadVersion
                            ) else {
                                return
                            }
                            readerText = cachedContent.text
                            readerMarkdown = cachedContent.markdown
                            statusMessage = ""
                            return
                        }

                        let sectionFormats: [(format: String, isMarkdown: Bool)] = document.prefersMarkdownReader
                            ? [("markdown", true), ("text", false)]
                            : [("text", false), ("markdown", true)]

                        for sectionFormat in sectionFormats {
                            let sectionContent = try? await datamuleBridge.section(
                                accession: filing.accession,
                                documentType: document.type,
                                filename: document.filename,
                                section: section.lookupKey,
                                format: sectionFormat.format
                            )
                            let content = cleanReaderText(sectionContent?.sections.joined(separator: "\n\n"))
                            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                continue
                            }

                            guard shouldApplyReaderResult(
                                filingID: expectedFilingID,
                                documentID: expectedDocumentID,
                                requestVersion: expectedReaderLoadVersion
                            ) else {
                                return
                            }

                            let payload = ReaderContentPayload(
                                pdfData: nil,
                                text: sectionFormat.isMarkdown ? "" : content,
                                markdown: sectionFormat.isMarkdown ? content : ""
                            )
                            readerText = payload.text
                            readerMarkdown = payload.markdown
                            cacheReaderContent(payload, for: cacheKey)
                            statusMessage = ""
                            return
                        }
                    }
                } else {
                    sections = []
                    selectedSectionKey = ""
                }

                let cacheKey = readerContentCacheKey(filing: filing, document: document, sectionKey: "")
                if let cachedContent = cachedReaderContent(for: cacheKey) {
                    guard shouldApplyReaderResult(
                        filingID: expectedFilingID,
                        documentID: expectedDocumentID,
                        requestVersion: expectedReaderLoadVersion
                    ) else {
                        return
                    }
                    readerText = cachedContent.text
                    readerMarkdown = cachedContent.markdown
                    statusMessage = ""
                    return
                }

                let loaded = try await datamuleBridge.document(
                    accession: filing.accession,
                    documentType: document.type,
                    filename: document.filename,
                    includeText: true,
                    includeMarkdown: true
                )

                guard shouldApplyReaderResult(
                    filingID: expectedFilingID,
                    documentID: expectedDocumentID,
                    requestVersion: expectedReaderLoadVersion
                ) else {
                    return
                }

                let payload = ReaderContentPayload(
                    pdfData: nil,
                    text: cleanReaderText(loaded.text),
                    markdown: cleanReaderText(loaded.markdown)
                )
                readerText = payload.text
                readerMarkdown = payload.markdown
                cacheReaderContent(payload, for: cacheKey)
            }

            statusMessage = ""
        } catch {
            guard shouldApplyReaderResult(
                filingID: expectedFilingID,
                documentID: expectedDocumentID,
                requestVersion: expectedReaderLoadVersion
            ) else {
                return
            }
            readerPDFData = nil
            readerText = ""
            readerMarkdown = ""
            sections = []
            selectedSectionKey = ""
            errorMessage = error.localizedDescription
            statusMessage = "Could not load datamule document for \(document.filename)."
        }
    }

    func beginNewNote() {
        guard selectedCompanyID != nil else { return }
        editingNoteID = nil
        draftNoteTitle = selectedSection?.title ?? "New note"
        draftNoteBody = ""
        draftNoteTags = [selectedFiling?.form.lowercased(), selectedSectionKey]
            .compactMap { $0 }
            .joined(separator: ", ")
        isEditingNote = true
    }

    func editNote(_ note: ResearchNote) {
        editingNoteID = note.id
        draftNoteTitle = note.title
        draftNoteBody = note.body
        draftNoteTags = note.tags.joined(separator: ", ")
        isEditingNote = true
    }

    func cancelNoteEditing() {
        isEditingNote = false
        editingNoteID = nil
        draftNoteTitle = ""
        draftNoteBody = ""
        draftNoteTags = ""
    }

    func saveDraftNote() {
        guard let database, let companyID = selectedCompanyID else {
            errorMessage = "SQLite is not available, so this note cannot be saved."
            return
        }

        let existing = editingNoteID.flatMap { id in notes.first(where: { $0.id == id }) }
        let now = Date()
        let title = draftNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftNoteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = draftNoteTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let note = ResearchNote(
            id: existing?.id ?? UUID(),
            companyID: companyID,
            filingID: selectedFilingID,
            documentID: selectedDocumentID,
            sectionKey: selectedSectionKey,
            title: title.isEmpty ? "Untitled note" : title,
            body: body,
            tags: tags,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try database.upsertNote(note)
            try reloadFromDatabase(
                preferredCompanyID: companyID,
                preferredFilingID: selectedFilingID,
                preferredDocumentID: selectedDocumentID
            )
            cancelNoteEditing()
            statusMessage = "Saved note."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEditingNote() {
        guard let database, let editingNoteID else {
            cancelNoteEditing()
            return
        }

        do {
            try database.deleteNote(id: editingNoteID)
            try reloadFromDatabase(
                preferredCompanyID: selectedCompanyID,
                preferredFilingID: selectedFilingID,
                preferredDocumentID: selectedDocumentID
            )
            cancelNoteEditing()
            statusMessage = "Deleted note."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadFromDatabase(
        preferredCompanyID: Company.ID? = nil,
        preferredFilingID: Filing.ID? = nil,
        preferredDocumentID: FilingDocument.ID? = nil,
        preferLastOpenedCompany: Bool = false
    ) throws {
        guard let database else { return }

        let previousCompanyID = preferredCompanyID ?? (preferLastOpenedCompany ? nil : selectedCompanyID)
        let previousFilingID = preferredFilingID ?? selectedFilingID
        let previousDocumentID = preferredDocumentID ?? selectedDocumentID

        companies = try database.fetchCompanies()
        filings = try database.fetchFilings()
        notes = try database.fetchNotes()

        selectedCompanyID = previousCompanyID.flatMap { id in
            companies.contains(where: { $0.id == id }) ? id : nil
        } ?? (preferLastOpenedCompany ? mostRecentlyOpenedCompanyID() : nil) ?? companies.first?.id

        let filingsForCompany = selectedCompanyFilings
        selectedFilingID = previousFilingID.flatMap { id in
            filingsForCompany.contains(where: { $0.id == id }) ? id : nil
        } ?? filingsForCompany.first?.id

        loadDocumentsForSelectedFiling(preferredDocumentID: previousDocumentID)

        sections = []
    }

    private func configureDatamuleCache(databasePath: String) {
        do {
            let cacheURL = try Self.secCacheURL()
            let exportURL = (try? Self.temporaryDocumentExportURL())
                ?? Self.fallbackDocumentExportURL(cacheURL: cacheURL)
            Self.migrateLegacyApplicationSupportSECCache(databasePath: databasePath, to: cacheURL)
            datamuleBridge = DatamuleBridge(cacheURL: cacheURL, documentExportURL: exportURL)
        } catch {
            errorMessage = "Could not prepare SEC cache. \(error.localizedDescription)"
        }
    }

    private static func secCacheURL() throws -> URL {
        let fileManager = FileManager.default
        let cacheURL = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("CrocodiloTiburon", isDirectory: true)
        .appendingPathComponent("SEC", isDirectory: true)

        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        return cacheURL
    }

    private static func temporaryDocumentExportURL() throws -> URL {
        let fileManager = FileManager.default
        let exportURL = fileManager.temporaryDirectory
            .appendingPathComponent("CrocodiloTiburon", isDirectory: true)
            .appendingPathComponent("ExportedDocuments", isDirectory: true)

        if fileManager.fileExists(atPath: exportURL.path) {
            try? fileManager.removeItem(at: exportURL)
        }
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        return exportURL
    }

    private static func fallbackDocumentExportURL(cacheURL: URL) -> URL {
        let exportURL = cacheURL.appendingPathComponent("TransientExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        return exportURL
    }

    private static func migrateLegacyApplicationSupportSECCache(databasePath: String, to cacheURL: URL) {
        let fileManager = FileManager.default
        let legacyURL = URL(fileURLWithPath: databasePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SEC", isDirectory: true)

        guard
            legacyURL.path != cacheURL.path,
            let legacyFiles = try? fileManager.contentsOfDirectory(
                at: legacyURL,
                includingPropertiesForKeys: nil
            )
        else { return }

        for legacyFile in legacyFiles where legacyFile.pathExtension == "tar" {
            let destination = cacheURL.appendingPathComponent(legacyFile.lastPathComponent)
            guard !fileManager.fileExists(atPath: destination.path) else { continue }
            try? fileManager.moveItem(at: legacyFile, to: destination)
        }

        try? fileManager.removeItem(at: legacyURL)
    }

    private func mostRecentlyOpenedCompanyID() -> Company.ID? {
        companies
            .filter { $0.lastOpenedAt != nil }
            .max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }?
            .id
    }

    private func company(id: Company.ID) -> Company? {
        companies.first { $0.id == id }
    }

    private func filing(id: Filing.ID) -> Filing? {
        filings.first { $0.id == id }
    }

    private func shouldApplyAsyncResult(
        companyID: Company.ID,
        filingID: Filing.ID? = nil,
        selectionVersion: Int? = nil
    ) -> Bool {
        guard selectedCompanyID == companyID else { return false }
        if let filingID, selectedFilingID != filingID { return false }
        if let selectionVersion, selectionVersion != companySelectionVersion { return false }
        return true
    }

    private func shouldApplyReaderResult(
        filingID: Filing.ID,
        documentID: FilingDocument.ID,
        requestVersion: Int
    ) -> Bool {
        selectedFilingID == filingID
            && selectedDocumentID == documentID
            && readerLoadVersion == requestVersion
    }

    private func prepareReaderFilingArchive(company: Company, filing: Filing) async throws {
        guard !preparedReaderFilingAccessions.contains(filing.accession) else { return }

        let filingDate = dayString(filing.filingDate)
        _ = try await datamuleBridge.download(
            ticker: company.ticker,
            forms: [filing.form],
            start: filingDate,
            end: filingDate
        )
        preparedReaderFilingAccessions.insert(filing.accession)
    }

    private func prepareSelectedCompanyProfileLoad(selectionVersion: Int) {
        guard let company = selectedCompany else {
            selectedCompanyProfileSummary = ""
            isLoadingCompanyProfile = false
            companyProfileTask?.cancel()
            return
        }

        selectedCompanyProfileSummary = ""
        isLoadingCompanyProfile = true
        companyProfileTask?.cancel()
        companyProfileTask = Task { [weak self] in
            await self?.loadCompanyProfile(
                ticker: company.ticker,
                companyID: company.id,
                selectionVersion: selectionVersion
            )
        }
    }

    private func loadCompanyProfile(
        ticker: String,
        companyID: Company.ID,
        selectionVersion: Int
    ) async {
        do {
            let response = try await datamuleBridge.profile(ticker: ticker)
            guard shouldApplyAsyncResult(companyID: companyID, selectionVersion: selectionVersion) else {
                return
            }
            let summary = response.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !summary.isEmpty {
                selectedCompanyProfileSummary = summary
            } else if let company = self.company(id: companyID) {
                selectedCompanyProfileSummary = fallbackDescription(for: company)
            }
            isLoadingCompanyProfile = false
        } catch {
            guard shouldApplyAsyncResult(companyID: companyID, selectionVersion: selectionVersion) else {
                return
            }
            if let company = self.company(id: companyID) {
                selectedCompanyProfileSummary = fallbackDescription(for: company)
            }
            isLoadingCompanyProfile = false
        }
    }

    private func refreshSelectedCompanyFilingsIfNeeded(selectionVersion: Int) {
        guard let selectedCompanyID else { return }

        companyRefreshTask = Task { [weak self] in
            await self?.refreshSelectedCompanyFilings(
                expectedCompanyID: selectedCompanyID,
                selectionVersion: selectionVersion
            )
        }
    }

    private func fallbackDescription(for company: Company) -> String {
        let industry = company.industry.trimmingCharacters(in: .whitespacesAndNewlines)
        let exchange = company.exchange.trimmingCharacters(in: .whitespacesAndNewlines)

        if industry.isEmpty || industry == "Unknown" || industry == "Datamule filer" {
            return "\(company.name) is an SEC filer\(exchange.isEmpty ? "" : " listed on \(exchange)")."
        }
        return "\(company.name) is an SEC filer\(exchange.isEmpty ? "" : " listed on \(exchange)") classified as \(industry)."
    }

    private func loadDocumentsForSelectedFiling(
        preferredDocumentID: FilingDocument.ID? = nil,
        preserveCurrentSelection: Bool = true
    ) {
        guard let database, let selectedFilingID else {
            documents = []
            selectedDocumentID = nil
            return
        }

        do {
            let documentIDToPreserve = preferredDocumentID ?? (preserveCurrentSelection ? selectedDocumentID : nil)
            documents = try database.fetchDocuments(filingID: selectedFilingID)
            selectedDocumentID = documentIDToPreserve.flatMap { id in
                documents.contains(where: { $0.id == id }) ? id : nil
            } ?? preferredReaderDocument(in: documents)?.id
        } catch {
            documents = []
            selectedDocumentID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func startSelectedDocumentContentLoadIfNeeded() {
        guard selectedDocument != nil else { return }
        let requestVersion = beginReaderLoad()
        Task { await loadSelectedDocumentContent(requestVersion: requestVersion) }
    }

    private func beginReaderLoad() -> Int {
        readerLoadVersion += 1
        isLoadingReader = true
        return readerLoadVersion
    }

    private func preferredReaderDocument(in documents: [FilingDocument]) -> FilingDocument? {
        documents.first(where: { $0.isMainDocument && $0.isReaderDisplayable })
            ?? documents.first(where: \.isReaderDisplayable)
    }

    private func resetReaderPrompt() {
        readerLoadVersion += 1
        readerPDFData = nil
        readerText = ""
        readerMarkdown = ""
        sections = []
        selectedSectionKey = ""
    }

    private func startUITestCommandLoopIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CROCODILO_UI_TESTING"] == "1",
              let path = environment["CROCODILO_UI_SEARCH_COMMAND_PATH"],
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        let commandURL = URL(fileURLWithPath: path)
        uiTestCommandTask = Task { [weak self] in
            var lastCommand = ""
            while !Task.isCancelled {
                if let rawCommand = try? String(contentsOf: commandURL, encoding: .utf8) {
                    let command = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !command.isEmpty, command != lastCommand {
                        lastCommand = command
                        await MainActor.run {
                            self?.handleUITestCommand(command)
                        }
                    }
                }

                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func handleUITestCommand(_ command: String) {
        if command.hasPrefix("search:") {
            query = String(command.dropFirst("search:".count))
            return
        }

        if command.hasPrefix("filing:") {
            let idValue = String(command.dropFirst("filing:".count))
            if let filingID = UUID(uuidString: idValue), let filing = filing(id: filingID) {
                selectFiling(filing)
            }
            return
        }

        query = command
    }

    private func filings(from hits: [DatamuleFilingHit], company: Company) -> [Filing] {
        var seen = Set<String>()
        var filings: [Filing] = []

        for hit in hits {
            guard
                let accession = hit.accession,
                let form = hit.form,
                let filingDate = dayDate(hit.filingDate)
            else { continue }
            guard !seen.contains(accession) else { continue }
            seen.insert(accession)

            filings.append(
                Filing(
                    id: UUID.stable("filing:\(company.cik):\(accession)"),
                    companyID: company.id,
                    accession: accession,
                    form: form,
                    filer: filerName(from: hit, company: company),
                    filingDate: filingDate,
                    reportDate: dayDate(hit.periodEnding),
                    title: hit.description?.isEmpty == false ? hit.description! : title(for: form),
                    summary: hit.items?.isEmpty == false ? "Items: \(hit.items!.joined(separator: ", "))" : "",
                    primaryDocument: hit.filename,
                    isDownloaded: false,
                    readStatus: .unread,
                    documentCount: 0,
                    noteCount: 0
                )
            )
        }

        return filings.sorted { $0.filingDate > $1.filingDate }
    }

    private func documents(from response: DatamuleDocumentsResponse, filing: Filing) -> [FilingDocument] {
        let compactAccession = filing.accession.replacingOccurrences(of: "-", with: "")
        let submission = response.submissions.first {
            $0.accession.replacingOccurrences(of: "-", with: "") == compactAccession
        }
        let payloads = submission?.documents ?? []

        return payloads.enumerated().compactMap { offset, payload in
            guard let filename = payload.filename, let type = payload.type else { return nil }
            let sequence = Int(payload.sequence ?? "") ?? offset + 1
            let isMainDocument = type == filing.form || filename == filing.primaryDocument

            return FilingDocument(
                id: UUID.stable("document:\(filing.accession):\(sequence):\(filename)"),
                filingID: filing.id,
                sequence: sequence,
                type: type,
                filename: filename,
                description: payload.description?.isEmpty == false ? payload.description! : filename,
                isMainDocument: isMainDocument,
                parseStatus: isMainDocument || isReadableDocument(filename) ? .parsed : .notParsed
            )
        }
        .sorted { $0.sequence < $1.sequence }
    }

    private func companies(from payloads: [DatamuleCompanyPayload]) -> [Company] {
        var seenTickers = Set<String>()
        return payloads.compactMap { payload in
            let ticker = payload.ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard let cik = payload.cik, !cik.isEmpty, !ticker.isEmpty, !seenTickers.contains(ticker) else { return nil }
            seenTickers.insert(ticker)
            return Company(
                id: UUID.stable("company:\(ticker)"),
                cik: cik,
                ticker: ticker,
                name: payload.name ?? ticker,
                exchange: payload.exchange?.isEmpty == false ? payload.exchange! : "SEC",
                industry: payload.industry?.isEmpty == false ? payload.industry! : "Datamule filer",
                status: .notStarted,
                priority: 999,
                lastOpenedAt: nil
            )
        }
    }

    private func touchCompany(_ companyID: Company.ID) {
        guard let database else { return }
        let openedAt = Date()

        if let index = companies.firstIndex(where: { $0.id == companyID }) {
            companies[index].lastOpenedAt = openedAt
            if companies[index].status == .notStarted {
                companies[index].status = .inProgress
            }
        }

        do {
            try database.markCompanyOpened(id: companyID, at: openedAt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markFilingOpened(_ filing: Filing) {
        let openedAt = Date()

        if let filingIndex = filings.firstIndex(where: { $0.id == filing.id }),
           filings[filingIndex].readStatus == .unread {
            filings[filingIndex].readStatus = .opened
        }

        if let companyIndex = companies.firstIndex(where: { $0.id == filing.companyID }) {
            companies[companyIndex].lastOpenedAt = openedAt
            if companies[companyIndex].status == .notStarted {
                companies[companyIndex].status = .inProgress
            }
        }

        guard let database else { return }
        Task.detached {
            try? database.markFilingOpened(id: filing.id, at: openedAt)
            try? database.markCompanyOpened(id: filing.companyID, at: openedAt)
        }
    }

    private func readerSections(from datamuleSections: [DatamuleSectionSummary]) -> [ReaderSection] {
        let sections = datamuleSections.compactMap { summary -> ReaderSection? in
            guard let rawKey = summary.key, let title = summary.title else { return nil }
            let key = rawKey.lowercased()
            let lookupKey = (summary.lookupKey ?? summary.key ?? rawKey).lowercased()
            let sectionClass = summary.sectionClass?.lowercased()
            let keep = key.hasPrefix("item")
                || key.hasPrefix("part")
                || key == "signatures"
                || sectionClass == "item"
                || sectionClass == "part"
                || sectionClass == "signatures"
            guard keep else { return nil }

            return ReaderSection(
                key: key,
                lookupKey: lookupKey,
                title: title,
                estimatedWordCount: summary.wordCount ?? 0,
                riskLevel: riskLevel(for: key)
            )
        }

        return Array(sections.prefix(64))
    }

    private func cleanReaderText(_ text: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed == "None" ? "" : (text ?? "")
    }

    private func readerDocumentCacheKey(filing: Filing, document: FilingDocument) -> ReaderDocumentCacheKey {
        ReaderDocumentCacheKey(
            accession: filing.accession,
            documentType: document.type,
            filename: document.filename
        )
    }

    private func readerContentCacheKey(
        filing: Filing,
        document: FilingDocument,
        sectionKey: String
    ) -> ReaderContentCacheKey {
        ReaderContentCacheKey(
            accession: filing.accession,
            documentType: document.type,
            filename: document.filename,
            sectionKey: sectionKey
        )
    }

    private func cachedReaderContent(for key: ReaderContentCacheKey) -> ReaderContentPayload? {
        guard let payload = readerContentCache[key] else { return nil }
        readerContentCacheOrder.removeAll { $0 == key }
        readerContentCacheOrder.append(key)
        return payload
    }

    private func cacheReaderContent(_ payload: ReaderContentPayload, for key: ReaderContentCacheKey) {
        readerContentCache[key] = payload
        readerContentCacheOrder.removeAll { $0 == key }
        readerContentCacheOrder.append(key)

        while readerContentCacheOrder.count > Self.maxReaderContentCacheEntries,
              let evictedKey = readerContentCacheOrder.first {
            readerContentCacheOrder.removeFirst()
            readerContentCache[evictedKey] = nil
        }
    }

    private func filerName(from hit: DatamuleFilingHit, company: Company) -> String? {
        guard let displayNames = hit.displayNames, !displayNames.isEmpty else {
            return company.name
        }

        let companyCIK = normalizedCIK(company.cik)
        let nonCompanyNames = displayNames.filter { displayName in
            guard let cik = cik(fromDisplayName: displayName) else {
                return !cleanDisplayName(displayName).localizedCaseInsensitiveContains(company.name)
            }
            return normalizedCIK(cik) != companyCIK
        }
        let chosenNames = nonCompanyNames.isEmpty ? displayNames : nonCompanyNames
        let cleaned = chosenNames
            .map(cleanDisplayName)
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
    }

    private func cleanDisplayName(_ displayName: String) -> String {
        if let range = displayName.range(of: "  (") ?? displayName.range(of: " (CIK") {
            return displayName[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cik(fromDisplayName displayName: String) -> String? {
        guard let range = displayName.range(of: "CIK ") else { return nil }
        let suffix = displayName[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    private func normalizedCIK(_ cik: String) -> String {
        let digits = cik.filter(\.isNumber)
        return digits.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
    }

    private static func isOwnershipReport(_ form: String) -> Bool {
        ownershipReportForms.contains(form.uppercased())
    }

    private func companyName(from hits: [DatamuleFilingHit]?, fallback: String) -> String {
        guard let displayName = hits?.compactMap({ $0.displayNames?.first }).first else {
            return fallback
        }
        if let range = displayName.range(of: "  (") {
            return String(displayName[..<range.lowerBound])
        }
        return displayName
    }

    private func title(for form: String) -> String {
        switch form {
        case "10-K": "Annual report"
        case "10-Q": "Quarterly report"
        case "8-K": "Current report"
        case "DEF 14A": "Proxy statement"
        case "20-F": "Foreign annual report"
        case "6-K": "Foreign issuer report"
        case "40-F": "Canadian annual report"
        default: form
        }
    }

    private func riskLevel(for key: String) -> SectionRiskLevel {
        switch key {
        case "item1a", "item7", "item7a": .important
        case "signatures": .neutral
        default: key.hasPrefix("item") ? .useful : .neutral
        }
    }

    private func isReadableDocument(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
        return lowercased.hasSuffix(".htm")
            || lowercased.hasSuffix(".html")
            || lowercased.hasSuffix(".txt")
            || lowercased.hasSuffix(".xml")
            || lowercased.hasSuffix(".pdf")
    }

    private func searchEndDate() -> String {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date()) + 1
        return "\(year)-12-31"
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dayDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

private struct ReaderDocumentCacheKey: Hashable {
    var accession: String
    var documentType: String
    var filename: String
}

private struct ReaderContentCacheKey: Hashable {
    var accession: String
    var documentType: String
    var filename: String
    var sectionKey: String
}

private struct ReaderContentPayload {
    var pdfData: Data?
    var text: String
    var markdown: String
}
