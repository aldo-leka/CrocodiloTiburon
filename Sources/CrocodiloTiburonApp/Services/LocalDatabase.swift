import Foundation
import GRDB

/// SQLite/GRDB foundation for the local-first research database.
///
/// The UI currently runs from sample data. This service is the next integration
/// point: WorkspaceStore can swap the sample arrays for LocalDatabase queries
/// without changing the view layer.
final class LocalDatabase {
    let dbQueue: DatabaseQueue

    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    convenience init(url: URL) throws {
        try self.init(path: url.path)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create core research tables") { db in
            try db.create(table: "companies", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("cik", .text).notNull().unique()
                table.column("ticker", .text).notNull()
                table.column("name", .text).notNull()
                table.column("exchange", .text)
                table.column("industry", .text)
                table.column("status", .text).notNull().defaults(to: ResearchStatus.notStarted.rawValue)
                table.column("priority", .integer).notNull().defaults(to: 999)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "filings", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("company_id", .text).notNull().references("companies", onDelete: .cascade)
                table.column("accession", .text).notNull().unique()
                table.column("form", .text).notNull()
                table.column("filing_date", .text).notNull()
                table.column("report_date", .text)
                table.column("title", .text)
                table.column("summary", .text)
                table.column("sec_url", .text)
                table.column("local_tar_path", .text)
                table.column("downloaded_at", .datetime)
                table.column("read_status", .text).notNull().defaults(to: FilingReadStatus.unread.rawValue)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "filing_documents", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("filing_id", .text).notNull().references("filings", onDelete: .cascade)
                table.column("sequence", .integer).notNull()
                table.column("document_type", .text).notNull()
                table.column("filename", .text).notNull()
                table.column("description", .text)
                table.column("is_main_document", .boolean).notNull().defaults(to: false)
                table.column("parse_status", .text).notNull().defaults(to: ParseStatus.notParsed.rawValue)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
                table.uniqueKey(["filing_id", "sequence"])
            }

            try db.create(table: "document_sections", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("document_id", .text).notNull().references("filing_documents", onDelete: .cascade)
                table.column("section_key", .text).notNull()
                table.column("title", .text).notNull()
                table.column("text", .text)
                table.column("markdown", .text)
                table.column("word_count", .integer).notNull().defaults(to: 0)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
                table.uniqueKey(["document_id", "section_key"])
            }

            try db.create(table: "notes", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("company_id", .text).notNull().references("companies", onDelete: .cascade)
                table.column("filing_id", .text).references("filings", onDelete: .cascade)
                table.column("document_id", .text).references("filing_documents", onDelete: .cascade)
                table.column("section_key", .text)
                table.column("title", .text).notNull()
                table.column("body", .text).notNull()
                table.column("tags_json", .text).notNull().defaults(to: "[]")
                table.column("selected_text", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "research_queue", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("company_id", .text).notNull().references("companies", onDelete: .cascade)
                table.column("status", .text).notNull().defaults(to: ResearchStatus.notStarted.rawValue)
                table.column("priority", .integer).notNull().defaults(to: 999)
                table.column("assigned_reason", .text)
                table.column("decision", .text)
                table.column("last_opened_at", .datetime)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }


            try db.create(index: "idx_companies_ticker", on: "companies", columns: ["ticker"], ifNotExists: true)
            try db.create(index: "idx_filings_company", on: "filings", columns: ["company_id"], ifNotExists: true)
            try db.create(index: "idx_filings_form", on: "filings", columns: ["form"], ifNotExists: true)
            try db.create(index: "idx_filings_filing_date", on: "filings", columns: ["filing_date"], ifNotExists: true)
            try db.create(index: "idx_documents_filing", on: "filing_documents", columns: ["filing_id"], ifNotExists: true)
            try db.create(index: "idx_documents_type", on: "filing_documents", columns: ["document_type"], ifNotExists: true)
            try db.create(index: "idx_sections_document", on: "document_sections", columns: ["document_id"], ifNotExists: true)
            try db.create(index: "idx_sections_key", on: "document_sections", columns: ["section_key"], ifNotExists: true)
            try db.create(index: "idx_notes_company", on: "notes", columns: ["company_id"], ifNotExists: true)
            try db.create(index: "idx_notes_filing", on: "notes", columns: ["filing_id"], ifNotExists: true)
            try db.create(index: "idx_notes_document", on: "notes", columns: ["document_id"], ifNotExists: true)
            try db.create(index: "idx_notes_section", on: "notes", columns: ["section_key"], ifNotExists: true)
            try db.create(index: "idx_queue_company", on: "research_queue", columns: ["company_id"], ifNotExists: true)
        }

        return migrator
    }
}

struct PersistedCompany: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "companies"

    var id: String
    var cik: String
    var ticker: String
    var name: String
    var exchange: String?
    var industry: String?
    var status: String
    var priority: Int
    var createdAt: Date
    var updatedAt: Date
}

struct PersistedFiling: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "filings"

    var id: String
    var companyId: String
    var accession: String
    var form: String
    var filingDate: Date
    var reportDate: Date?
    var title: String?
    var summary: String?
    var secUrl: String?
    var localTarPath: String?
    var downloadedAt: Date?
    var readStatus: String
    var createdAt: Date
    var updatedAt: Date
}
