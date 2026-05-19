import Foundation

enum SampleData {
    static let appleID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let hurcoID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let dfchID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    static let apple10KID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let apple10QID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let apple8KID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let appleProxyID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let appleMainDocID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    static var companies: [Company] {
        [
            Company(id: appleID, cik: "0000320193", ticker: "AAPL", name: "Apple Inc.", exchange: "NASDAQ", industry: "Consumer Electronics", status: .inProgress, priority: 1, lastOpenedAt: Date()),
            Company(id: hurcoID, cik: "0000315374", ticker: "HURC", name: "Hurco Companies, Inc.", exchange: "NASDAQ", industry: "Machine Tools", status: .interesting, priority: 2, lastOpenedAt: nil),
            Company(id: dfchID, cik: "0000000000", ticker: "DFCH", name: "Distribution Finance Capital Holdings", exchange: "LSE", industry: "Specialty Finance", status: .watchlist, priority: 3, lastOpenedAt: nil)
        ]
    }

    static var filings: [Filing] {
        [
            Filing(id: apple10KID, companyID: appleID, accession: "0000320193-25-000079", form: "10-K", filer: "Apple Inc.", filingDate: date("2025-10-31"), reportDate: date("2025-09-27"), title: "Annual report", summary: "Main 10-K plus exhibits, XBRL taxonomy, report files, and graphics. Live datamule test found 90 document items.", isDownloaded: true, readStatus: .reading, documentCount: 90, noteCount: 4),
            Filing(id: apple10QID, companyID: appleID, accession: "0000320193-26-000013", form: "10-Q", filer: "Apple Inc.", filingDate: date("2026-05-01"), reportDate: date("2026-03-28"), title: "Quarterly report", summary: "Recent quarterly filing available from EFTS search results.", isDownloaded: false, readStatus: .unread, documentCount: 0, noteCount: 0),
            Filing(id: apple8KID, companyID: appleID, accession: "0000320193-25-000077", form: "8-K", filer: "Apple Inc.", filingDate: date("2025-09-09"), reportDate: nil, title: "Current report", summary: "Event filing. Good candidate for event-driven notes and catalyst tracking.", isDownloaded: false, readStatus: .opened, documentCount: 0, noteCount: 1),
            Filing(id: appleProxyID, companyID: appleID, accession: "0001308179-25-000008", form: "DEF 14A", filer: "Apple Inc.", filingDate: date("2025-01-10"), reportDate: nil, title: "Proxy statement", summary: "Governance, compensation, board, and shareholder proposal data.", isDownloaded: false, readStatus: .unread, documentCount: 0, noteCount: 0)
        ]
    }

    static func documents(for filingID: Filing.ID) -> [FilingDocument] {
        [
            FilingDocument(id: appleMainDocID, filingID: filingID, sequence: 1, type: "10-K", filename: "aapl-20250927.htm", description: "10-K", isMainDocument: true, parseStatus: .parsed),
            FilingDocument(filingID: filingID, sequence: 2, type: "EX-4.1", filename: "a10-kexhibit4109272025.htm", description: "Description of securities", isMainDocument: false, parseStatus: .notParsed),
            FilingDocument(filingID: filingID, sequence: 3, type: "EX-21.1", filename: "a10-kexhibit21109272025.htm", description: "Subsidiaries", isMainDocument: false, parseStatus: .notParsed),
            FilingDocument(filingID: filingID, sequence: 4, type: "EX-23.1", filename: "a10-kexhibit23109272025.htm", description: "Auditor consent", isMainDocument: false, parseStatus: .notParsed),
            FilingDocument(filingID: filingID, sequence: 5, type: "EX-31.1", filename: "a10-kexhibit31109272025.htm", description: "CEO certification", isMainDocument: false, parseStatus: .notParsed),
            FilingDocument(filingID: filingID, sequence: 8, type: "EX-101.SCH", filename: "aapl-20250927.xsd", description: "XBRL taxonomy extension schema", isMainDocument: false, parseStatus: .notParsed)
        ]
    }

    static var sections: [ReaderSection] {
        [
            ReaderSection(key: "business", lookupKey: "business", title: "Business overview", estimatedWordCount: 2600, riskLevel: .useful),
            ReaderSection(key: "item1a", lookupKey: "item1a", title: "Item 1A. Risk Factors", estimatedWordCount: 9800, riskLevel: .important),
            ReaderSection(key: "item1b", lookupKey: "item1b", title: "Item 1B. Unresolved Staff Comments", estimatedWordCount: 120, riskLevel: .neutral),
            ReaderSection(key: "item7", lookupKey: "item7", title: "Item 7. MD&A", estimatedWordCount: 3600, riskLevel: .important),
            ReaderSection(key: "item8", lookupKey: "item8", title: "Item 8. Financial Statements", estimatedWordCount: 14800, riskLevel: .useful),
            ReaderSection(key: "signatures", lookupKey: "signatures", title: "Signatures", estimatedWordCount: 420, riskLevel: .neutral)
        ]
    }

    static var notes: [ResearchNote] {
        [
            ResearchNote(companyID: appleID, filingID: nil, documentID: nil, sectionKey: nil, title: "Company thesis stub", body: "Use Crocodilo Tiburon to compare services growth, buybacks, gross margin resilience, China risk, and antitrust language over time.", tags: ["thesis", "todo"], createdAt: Date(), updatedAt: Date()),
            ResearchNote(companyID: appleID, filingID: apple10KID, documentID: appleMainDocID, sectionKey: "item1a", title: "Risk factors to diff", body: "Track language around regulatory pressure, App Store economics, supply chain concentration, and AI-capex expectations year over year.", tags: ["risk", "compare"], createdAt: Date(), updatedAt: Date()),
            ResearchNote(companyID: appleID, filingID: apple10KID, documentID: appleMainDocID, sectionKey: "item7", title: "MD&A read-through", body: "Need a section comparison view for revenue mix, segment margin, services, and geographic commentary.", tags: ["mda", "feature"], createdAt: Date(), updatedAt: Date())
        ]
    }

    static let readerText = """
    Item 1A. Risk Factors

    The following summarizes factors that could have a material effect on the Company’s business, reputation, results of operations, financial condition, and stock price. This placeholder mirrors the live datamule parsing result: Item 1A can be extracted with document.get_section(title='item1a', format='text').

    Business and market risks

    The Company competes in markets characterized by rapid technological change, frequent product introductions, evolving industry standards, and aggressive pricing. Investors should pay attention to whether risk language changes from routine boilerplate into company-specific warnings.

    Regulatory and legal risks

    Antitrust, privacy, payments, distribution, and platform-control language deserve special tracking. Crocodilo Tiburon should make this easy by comparing Item 1A across multiple years and highlighting added or removed sentences.

    Supply chain and concentration risks

    Manufacturing concentration, key supplier dependence, geopolitical exposure, and component availability can turn a pretty income statement into a fragile thesis. The reader should let Aldo tag these sections quickly while staying in flow.

    Why this matters for the app

    The backend already gives us the filing text. The product value is the calmer reading surface, the section navigation, the notes, and the longitudinal comparison workflow.
    """

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }
}
