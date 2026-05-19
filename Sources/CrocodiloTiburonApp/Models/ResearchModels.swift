import Foundation

struct Company: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var cik: String
    var ticker: String
    var name: String
    var exchange: String
    var industry: String
    var status: ResearchStatus
    var priority: Int
    var lastOpenedAt: Date?
}

enum ResearchStatus: String, Codable, CaseIterable, Hashable {
    case notStarted = "Not started"
    case inProgress = "In progress"
    case readAnnual = "Read 10-K"
    case interesting = "Interesting"
    case pass = "Pass"
    case watchlist = "Watchlist"
    case candidate = "Portfolio candidate"

    var shortLabel: String { rawValue }
}

struct Filing: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var companyID: Company.ID
    var accession: String
    var form: String
    var filingDate: Date
    var reportDate: Date?
    var title: String
    var summary: String
    var isDownloaded: Bool
    var readStatus: FilingReadStatus
    var documentCount: Int
    var noteCount: Int
}

enum FilingReadStatus: String, Codable, CaseIterable, Hashable {
    case unread = "Unread"
    case opened = "Opened"
    case reading = "Reading"
    case done = "Done"
}

struct FilingDocument: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var filingID: Filing.ID
    var sequence: Int
    var type: String
    var filename: String
    var description: String
    var isMainDocument: Bool
    var parseStatus: ParseStatus
}

enum ParseStatus: String, Codable, CaseIterable, Hashable {
    case notParsed = "Not parsed"
    case parsed = "Parsed"
    case failed = "Failed"
}

struct ReaderSection: Identifiable, Codable, Hashable {
    var id: String { key }
    var key: String
    var title: String
    var estimatedWordCount: Int
    var riskLevel: SectionRiskLevel
}

enum SectionRiskLevel: String, Codable, CaseIterable, Hashable {
    case neutral = "Neutral"
    case useful = "Useful"
    case important = "Important"
    case redFlag = "Red flag"
}

struct ResearchNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var companyID: Company.ID
    var filingID: Filing.ID?
    var documentID: FilingDocument.ID?
    var sectionKey: String?
    var title: String
    var body: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}
