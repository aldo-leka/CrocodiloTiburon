import Foundation
import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var companies: [Company]
    @Published var filings: [Filing]
    @Published var documents: [FilingDocument]
    @Published var sections: [ReaderSection]
    @Published var notes: [ResearchNote]
    @Published var selectedCompanyID: Company.ID?
    @Published var selectedFilingID: Filing.ID?
    @Published var selectedDocumentID: FilingDocument.ID?
    @Published var selectedSectionKey: String = "item1a"
    @Published var query: String = ""
    @Published var readerMode: ReaderMode = .cleanText
    @Published var shouldFocusSearch: Bool = false

    init() {
        let initialCompanies = SampleData.companies
        let initialFilings = SampleData.filings
        let initialSections = SampleData.sections
        let initialNotes = SampleData.notes
        let initialFilingID = initialFilings.first?.id
        let initialDocuments = SampleData.documents(for: initialFilingID ?? UUID())

        companies = initialCompanies
        filings = initialFilings
        sections = initialSections
        notes = initialNotes
        selectedCompanyID = initialCompanies.first?.id
        selectedFilingID = initialFilingID
        documents = initialDocuments
        selectedDocumentID = initialDocuments.first?.id
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

    var filteredCompanies: [Company] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return companies }
        return companies.filter {
            $0.ticker.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.cik.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedCompanyFilings: [Filing] {
        guard let selectedCompanyID else { return [] }
        return filings.filter { $0.companyID == selectedCompanyID }
            .sorted { $0.filingDate > $1.filingDate }
    }

    var selectedNotes: [ResearchNote] {
        guard let selectedCompanyID else { return [] }
        return notes.filter { $0.companyID == selectedCompanyID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func focusSearch() {
        shouldFocusSearch = true
    }

    func selectCompany(_ company: Company) {
        selectedCompanyID = company.id
        let firstFiling = filings.first(where: { $0.companyID == company.id })
        selectedFilingID = firstFiling?.id
        documents = SampleData.documents(for: firstFiling?.id ?? UUID())
        selectedDocumentID = documents.first?.id
    }

    func selectFiling(_ filing: Filing) {
        selectedFilingID = filing.id
        documents = SampleData.documents(for: filing.id)
        selectedDocumentID = documents.first?.id
    }

    func selectDocument(_ document: FilingDocument) {
        selectedDocumentID = document.id
    }

    func selectSection(_ section: ReaderSection) {
        selectedSectionKey = section.key
    }
}

enum ReaderMode: String, CaseIterable, Identifiable {
    case cleanText = "Clean"
    case original = "Original"
    case markdown = "Markdown"

    var id: String { rawValue }
}
