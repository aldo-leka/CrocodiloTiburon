import CryptoKit
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
    var primaryDocument: String? = nil
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

extension UUID {
    static func stable(_ seed: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
