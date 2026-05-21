import Foundation

enum CTAccessibility {
    static let appShell = "ct.app.shell"
    static let appLoading = "ct.app.loading"

    static let sidebarSearchField = "ct.sidebar.searchField"
    static let sidebarCompanyList = "ct.sidebar.companyList"
    static let companyRowPrefix = "ct.company.row."

    static let companyHeaderTitle = "ct.company.headerTitle"
    static let companyWorkspaceScroll = "ct.company.workspaceScroll"
    static let filingsList = "ct.filings.list"
    static let filingsCatalog = "ct.filings.catalog"
    static let filingsOwnershipToggle = "ct.filings.excludeOwnershipToggle"
    static let filingRowPrefix = "ct.filings.row."

    static let readerWorkspace = "ct.reader.workspace"
    static let readerDocumentStrip = "ct.reader.documentStrip"
    static let readerDocumentButtonPrefix = "ct.reader.document."
    static let readerLoading = "ct.reader.loading"
    static let readerText = "ct.reader.text"
    static let readerPDF = "ct.reader.pdf"
    static let readerEmpty = "ct.reader.empty"
    static let readerSectionButtonPrefix = "ct.reader.section."

    static func companyRow(ticker: String) -> String {
        companyRowPrefix + normalized(ticker)
    }

    static func filingRow(accession: String) -> String {
        filingRowPrefix + normalized(accession)
    }

    static func readerDocumentButton(id: UUID) -> String {
        readerDocumentButtonPrefix + id.uuidString.lowercased()
    }

    static func readerSectionButton(key: String) -> String {
        readerSectionButtonPrefix + normalized(key)
    }

    static func normalized(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar).lowercased() : "_"
        }
        .joined()
    }
}
