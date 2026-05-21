import Foundation
import GRDB

/// Local-first SQLite store for companies, SEC filing metadata, documents, and notes.
final class LocalDatabase {
    let dbQueue: DatabaseQueue
    let url: URL

    var path: String { url.path }

    init(path: String) throws {
        self.url = URL(fileURLWithPath: path)
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    convenience init(url: URL) throws {
        try self.init(path: url.path)
    }

    static func appDatabase() throws -> LocalDatabase {
        let fileManager = FileManager.default

        if let path = ProcessInfo.processInfo.environment["CROCODILO_DATABASE_PATH"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return try LocalDatabase(url: url)
        }

        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("CrocodiloTiburon", isDirectory: true)

        try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return try LocalDatabase(url: supportURL.appendingPathComponent("CrocodiloTiburon.sqlite"))
    }

    func seedIfNeeded() throws {
        let count = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companies") ?? 0
        }
        guard count == 0 else { return }

        try dbQueue.write { db in
            for company in SampleData.companies {
                try upsert(company, db: db)
            }
            for filing in SampleData.filings {
                try upsert(filing, db: db)
            }
            for document in SampleData.documents(for: SampleData.apple10KID) {
                try upsert(document, db: db)
            }
            for note in SampleData.notes {
                try upsert(note, db: db)
            }
        }
    }

    func fetchCompanies() throws -> [Company] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, cik, ticker, name, exchange, industry, status, priority, last_opened_at
                FROM companies
                ORDER BY ticker ASC
                """
            )
            .compactMap(company(from:))
        }
    }

    func companyCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companies") ?? 0
        }
    }

    func fetchFilings() throws -> [Filing] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, company_id, accession, form, filer, filing_date, report_date, title, summary,
                       primary_document, downloaded_at, read_status, document_count, note_count
                FROM filings
                ORDER BY filing_date DESC
                """
            )
            .compactMap(filing(from:))
        }
    }

    func fetchDocuments(filingID: Filing.ID) throws -> [FilingDocument] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, filing_id, sequence, document_type, filename, description,
                       is_main_document, parse_status
                FROM filing_documents
                WHERE filing_id = ?
                ORDER BY sequence ASC
                """,
                arguments: [filingID.uuidString]
            )
            .compactMap(document(from:))
        }
    }

    func fetchNotes() throws -> [ResearchNote] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, company_id, filing_id, document_id, section_key, title, body,
                       tags_json, created_at, updated_at
                FROM notes
                ORDER BY updated_at DESC
                """
            )
            .compactMap(note(from:))
        }
    }

    func upsertCompany(_ company: Company) throws {
        try dbQueue.write { db in
            try upsert(company, db: db)
        }
    }

    func upsertCompanies(_ companies: [Company]) throws {
        try dbQueue.write { db in
            for company in companies {
                try upsert(company, db: db)
            }
        }
    }

    func upsertFilings(_ filings: [Filing]) throws {
        try dbQueue.write { db in
            for filing in filings {
                try upsert(filing, db: db)
            }
        }
    }

    func upsertDocuments(_ documents: [FilingDocument]) throws {
        try dbQueue.write { db in
            for document in documents {
                try upsert(document, db: db)
            }
        }
    }

    func upsertNote(_ note: ResearchNote) throws {
        try dbQueue.write { db in
            try upsert(note, db: db)
        }
    }

    func deleteNote(id: ResearchNote.ID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM notes WHERE id = ?", arguments: [id.uuidString])
        }
    }

    func markCompanyOpened(id: Company.ID, at date: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE companies
                SET last_opened_at = ?, status = CASE
                    WHEN status = ? THEN ?
                    ELSE status
                END,
                updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    dateTimeString(date),
                    ResearchStatus.notStarted.rawValue,
                    ResearchStatus.inProgress.rawValue,
                    dateTimeString(date),
                    id.uuidString
                ]
            )
        }
    }

    func markFilingOpened(id: Filing.ID, at date: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE filings
                SET read_status = CASE
                    WHEN read_status = ? THEN ?
                    ELSE read_status
                END,
                updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    FilingReadStatus.unread.rawValue,
                    FilingReadStatus.opened.rawValue,
                    dateTimeString(date),
                    id.uuidString
                ]
            )
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create core research tables") { db in
            try db.create(table: "companies", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("cik", .text).notNull()
                table.column("ticker", .text).notNull().unique()
                table.column("name", .text).notNull()
                table.column("exchange", .text)
                table.column("industry", .text)
                table.column("status", .text).notNull().defaults(to: ResearchStatus.notStarted.rawValue)
                table.column("priority", .integer).notNull().defaults(to: 999)
                table.column("last_opened_at", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(table: "filings", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("company_id", .text).notNull().references("companies", onDelete: .cascade)
                table.column("accession", .text).notNull().unique()
                table.column("form", .text).notNull()
                table.column("filer", .text)
                table.column("filing_date", .text).notNull()
                table.column("report_date", .text)
                table.column("title", .text)
                table.column("summary", .text)
                table.column("primary_document", .text)
                table.column("document_count", .integer).notNull().defaults(to: 0)
                table.column("note_count", .integer).notNull().defaults(to: 0)
                table.column("sec_url", .text)
                table.column("local_tar_path", .text)
                table.column("downloaded_at", .text)
                table.column("read_status", .text).notNull().defaults(to: FilingReadStatus.unread.rawValue)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
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
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
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
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
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
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(table: "research_queue", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("company_id", .text).notNull().references("companies", onDelete: .cascade)
                table.column("status", .text).notNull().defaults(to: ResearchStatus.notStarted.rawValue)
                table.column("priority", .integer).notNull().defaults(to: 999)
                table.column("assigned_reason", .text)
                table.column("decision", .text)
                table.column("last_opened_at", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(index: "idx_companies_ticker", on: "companies", columns: ["ticker"], ifNotExists: true)
            try db.create(index: "idx_companies_cik", on: "companies", columns: ["cik"], ifNotExists: true)
            try db.create(index: "idx_filings_company", on: "filings", columns: ["company_id"], ifNotExists: true)
            try db.create(index: "idx_filings_form", on: "filings", columns: ["form"], ifNotExists: true)
            try db.create(index: "idx_filings_filing_date", on: "filings", columns: ["filing_date"], ifNotExists: true)
            try db.create(index: "idx_documents_filing", on: "filing_documents", columns: ["filing_id"], ifNotExists: true)
            try db.create(index: "idx_documents_type", on: "filing_documents", columns: ["document_type"], ifNotExists: true)
            try db.create(index: "idx_notes_company", on: "notes", columns: ["company_id"], ifNotExists: true)
            try db.create(index: "idx_notes_filing", on: "notes", columns: ["filing_id"], ifNotExists: true)
            try db.create(index: "idx_notes_document", on: "notes", columns: ["document_id"], ifNotExists: true)
            try db.create(index: "idx_notes_section", on: "notes", columns: ["section_key"], ifNotExists: true)
            try db.create(index: "idx_queue_company", on: "research_queue", columns: ["company_id"], ifNotExists: true)
        }

        migrator.registerMigration("add datamule mvp columns") { db in
            func hasColumn(_ column: String, in table: String) throws -> Bool {
                try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))").contains { row in
                    let name: String = row["name"]
                    return name == column
                }
            }

            if try !hasColumn("last_opened_at", in: "companies") {
                try db.alter(table: "companies") { table in
                    table.add(column: "last_opened_at", .text)
                }
            }

            if try !hasColumn("primary_document", in: "filings") {
                try db.alter(table: "filings") { table in
                    table.add(column: "primary_document", .text)
                }
            }

            if try !hasColumn("document_count", in: "filings") {
                try db.alter(table: "filings") { table in
                    table.add(column: "document_count", .integer).notNull().defaults(to: 0)
                }
            }

            if try !hasColumn("note_count", in: "filings") {
                try db.alter(table: "filings") { table in
                    table.add(column: "note_count", .integer).notNull().defaults(to: 0)
                }
            }
        }

        migrator.registerMigration("key companies by ticker") { db in
            try db.execute(sql: "DROP TABLE IF EXISTS companies_next")
            try db.execute(sql: """
            CREATE TABLE companies_next (
                id TEXT PRIMARY KEY NOT NULL,
                cik TEXT NOT NULL,
                ticker TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                exchange TEXT,
                industry TEXT,
                status TEXT NOT NULL DEFAULT '\(ResearchStatus.notStarted.rawValue)',
                priority INTEGER NOT NULL DEFAULT 999,
                last_opened_at TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """)
            try db.execute(sql: """
            INSERT OR IGNORE INTO companies_next
                (id, cik, ticker, name, exchange, industry, status, priority, last_opened_at, created_at, updated_at)
            SELECT id, cik, UPPER(ticker), name, exchange, industry, status, priority, last_opened_at, created_at, updated_at
            FROM companies
            ORDER BY ticker ASC
            """)
            try db.drop(table: "companies")
            try db.rename(table: "companies_next", to: "companies")
            try db.create(index: "idx_companies_ticker", on: "companies", columns: ["ticker"], ifNotExists: true)
            try db.create(index: "idx_companies_cik", on: "companies", columns: ["cik"], ifNotExists: true)
        }

        migrator.registerMigration("add filing filer") { db in
            let hasFilerColumn = try Row.fetchAll(db, sql: "PRAGMA table_info(filings)").contains { row in
                let name: String = row["name"]
                return name == "filer"
            }

            if !hasFilerColumn {
                try db.alter(table: "filings") { table in
                    table.add(column: "filer", .text)
                }
            }
        }

        return migrator
    }

    private func upsert(_ company: Company, db: Database) throws {
        let now = dateTimeString(Date())
        try db.execute(
            sql: """
            INSERT INTO companies
                (id, cik, ticker, name, exchange, industry, status, priority, last_opened_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(ticker) DO UPDATE SET
                cik = excluded.cik,
                name = excluded.name,
                exchange = excluded.exchange,
                industry = excluded.industry,
                status = CASE
                    WHEN companies.status != ? THEN companies.status
                    ELSE excluded.status
                END,
                priority = excluded.priority,
                last_opened_at = COALESCE(companies.last_opened_at, excluded.last_opened_at),
                updated_at = excluded.updated_at
            """,
            arguments: [
                company.id.uuidString,
                company.cik,
                company.ticker.uppercased(),
                company.name,
                company.exchange,
                company.industry,
                company.status.rawValue,
                company.priority,
                company.lastOpenedAt.map(dateTimeString),
                now,
                now,
                ResearchStatus.notStarted.rawValue
            ]
        )
    }

    private func upsert(_ filing: Filing, db: Database) throws {
        let now = dateTimeString(Date())
        try db.execute(
            sql: """
            INSERT INTO filings
                (id, company_id, accession, form, filer, filing_date, report_date, title, summary,
                 primary_document, document_count, note_count, downloaded_at, read_status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(accession) DO UPDATE SET
                company_id = excluded.company_id,
                form = excluded.form,
                filer = excluded.filer,
                filing_date = excluded.filing_date,
                report_date = excluded.report_date,
                title = excluded.title,
                summary = excluded.summary,
                primary_document = excluded.primary_document,
                document_count = CASE
                    WHEN excluded.document_count > 0 THEN excluded.document_count
                    ELSE filings.document_count
                END,
                note_count = excluded.note_count,
                downloaded_at = COALESCE(excluded.downloaded_at, filings.downloaded_at),
                read_status = excluded.read_status,
                updated_at = excluded.updated_at
            """,
            arguments: [
                filing.id.uuidString,
                filing.companyID.uuidString,
                filing.accession,
                filing.form,
                filing.filer,
                dayString(filing.filingDate),
                filing.reportDate.map(dayString),
                filing.title,
                filing.summary,
                filing.primaryDocument,
                filing.documentCount,
                filing.noteCount,
                filing.isDownloaded ? now : nil,
                filing.readStatus.rawValue,
                now,
                now
            ]
        )
    }

    private func upsert(_ document: FilingDocument, db: Database) throws {
        let now = dateTimeString(Date())
        try db.execute(
            sql: """
            INSERT INTO filing_documents
                (id, filing_id, sequence, document_type, filename, description,
                 is_main_document, parse_status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(filing_id, sequence) DO UPDATE SET
                id = excluded.id,
                document_type = excluded.document_type,
                filename = excluded.filename,
                description = excluded.description,
                is_main_document = excluded.is_main_document,
                parse_status = excluded.parse_status,
                updated_at = excluded.updated_at
            """,
            arguments: [
                document.id.uuidString,
                document.filingID.uuidString,
                document.sequence,
                document.type,
                document.filename,
                document.description,
                document.isMainDocument,
                document.parseStatus.rawValue,
                now,
                now
            ]
        )
    }

    private func upsert(_ note: ResearchNote, db: Database) throws {
        let tagsData = (try? JSONEncoder().encode(note.tags)) ?? Data("[]".utf8)
        let tagsJSON = String(data: tagsData, encoding: .utf8) ?? "[]"

        try db.execute(
            sql: """
            INSERT INTO notes
                (id, company_id, filing_id, document_id, section_key, title, body,
                 tags_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                company_id = excluded.company_id,
                filing_id = excluded.filing_id,
                document_id = excluded.document_id,
                section_key = excluded.section_key,
                title = excluded.title,
                body = excluded.body,
                tags_json = excluded.tags_json,
                updated_at = excluded.updated_at
            """,
            arguments: [
                note.id.uuidString,
                note.companyID.uuidString,
                note.filingID?.uuidString,
                note.documentID?.uuidString,
                note.sectionKey,
                note.title,
                note.body,
                tagsJSON,
                dateTimeString(note.createdAt),
                dateTimeString(note.updatedAt)
            ]
        )
    }

    private func company(from row: Row) -> Company? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        return Company(
            id: id,
            cik: row["cik"],
            ticker: row["ticker"],
            name: row["name"],
            exchange: row["exchange"] ?? "SEC",
            industry: row["industry"] ?? "Unknown",
            status: ResearchStatus(rawValue: row["status"]) ?? .notStarted,
            priority: row["priority"],
            lastOpenedAt: dateTime(row["last_opened_at"])
        )
    }

    private func filing(from row: Row) -> Filing? {
        guard
            let id = UUID(uuidString: row["id"]),
            let companyID = UUID(uuidString: row["company_id"])
        else { return nil }

        return Filing(
            id: id,
            companyID: companyID,
            accession: row["accession"],
            form: row["form"],
            filer: row["filer"],
            filingDate: dayDate(row["filing_date"]) ?? Date(),
            reportDate: dayDate(row["report_date"]),
            title: row["title"] ?? row["form"],
            summary: row["summary"] ?? "",
            primaryDocument: row["primary_document"],
            isDownloaded: row["downloaded_at"] != nil,
            readStatus: FilingReadStatus(rawValue: row["read_status"]) ?? .unread,
            documentCount: row["document_count"] ?? 0,
            noteCount: row["note_count"] ?? 0
        )
    }

    private func document(from row: Row) -> FilingDocument? {
        guard
            let id = UUID(uuidString: row["id"]),
            let filingID = UUID(uuidString: row["filing_id"])
        else { return nil }

        return FilingDocument(
            id: id,
            filingID: filingID,
            sequence: row["sequence"],
            type: row["document_type"],
            filename: row["filename"],
            description: row["description"] ?? row["filename"],
            isMainDocument: row["is_main_document"],
            parseStatus: ParseStatus(rawValue: row["parse_status"]) ?? .notParsed
        )
    }

    private func note(from row: Row) -> ResearchNote? {
        guard
            let id = UUID(uuidString: row["id"]),
            let companyID = UUID(uuidString: row["company_id"])
        else { return nil }

        let tagsJSON: String = row["tags_json"]
        let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []

        return ResearchNote(
            id: id,
            companyID: companyID,
            filingID: optionalUUID(row["filing_id"]),
            documentID: optionalUUID(row["document_id"]),
            sectionKey: row["section_key"],
            title: row["title"],
            body: row["body"],
            tags: tags,
            createdAt: dateTime(row["created_at"]) ?? Date(),
            updatedAt: dateTime(row["updated_at"]) ?? Date()
        )
    }

    private func optionalUUID(_ string: String?) -> UUID? {
        guard let string else { return nil }
        return UUID(uuidString: string)
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dayDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func dateTimeString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func dateTime(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}
