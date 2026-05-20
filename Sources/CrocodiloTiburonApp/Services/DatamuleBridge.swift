import Foundation

struct DatamuleBridge {
    var projectRoot: URL
    var pythonExecutable: URL
    var scriptURL: URL
    var cacheURL: URL
    var documentExportURL: URL?

    init(projectRoot: URL? = nil, cacheURL: URL? = nil, documentExportURL: URL? = nil) {
        let root = projectRoot ?? Self.findProjectRoot()
        self.projectRoot = root
        self.scriptURL = root.appendingPathComponent("tools/datamule_bridge.py")
        self.cacheURL = cacheURL ?? root.appendingPathComponent("Data/SEC")
        self.documentExportURL = documentExportURL

        let virtualEnvPython = root.appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: virtualEnvPython.path) {
            self.pythonExecutable = virtualEnvPython
        } else {
            self.pythonExecutable = URL(fileURLWithPath: "/usr/bin/python3")
        }
    }

    func resolve(ticker: String) async throws -> DatamuleResolveResponse {
        try await run(arguments: ["resolve", ticker])
    }

    func tickers(limit: Int = 0) async throws -> DatamuleTickersResponse {
        var arguments = ["tickers"]
        if limit > 0 {
            arguments += ["--limit", String(limit)]
        }
        return try await run(arguments: arguments)
    }

    func profile(ticker: String) async throws -> DatamuleProfileResponse {
        try await run(arguments: ["profile", ticker])
    }

    func search(ticker: String, forms: [String]? = nil, start: String, end: String) async throws -> DatamuleSearchResponse {
        var arguments = ["search", ticker]
        if let forms, !forms.isEmpty {
            arguments += ["--forms"] + forms
        }
        arguments += ["--start", start, "--end", end]
        return try await run(arguments: arguments)
    }

    func download(ticker: String, forms: [String], start: String, end: String) async throws -> DatamuleDownloadResponse {
        try await run(arguments: ["download", ticker, "--forms"] + forms + ["--start", start, "--end", end, "--cache-dir", cacheURL.path])
    }

    func documents(accession: String) async throws -> DatamuleDocumentsResponse {
        try await run(arguments: ["documents", accession, "--cache-dir", cacheURL.path])
    }

    func document(accession: String, documentType: String, filename: String, includeText: Bool = true, includeMarkdown: Bool = false) async throws -> DatamuleDocumentContentResponse {
        var arguments = [
            "document",
            accession,
            "--document-type", documentType,
            "--filename", filename,
            "--cache-dir", cacheURL.path
        ]
        if includeText {
            arguments.append("--include-text")
        }
        if includeMarkdown {
            arguments.append("--include-markdown")
        }
        return try await run(arguments: arguments)
    }

    func exportDocument(accession: String, documentType: String, filename: String) async throws -> DatamuleDocumentFileResponse {
        var arguments = [
            "export-document",
            accession,
            "--document-type", documentType,
            "--filename", filename,
            "--cache-dir", cacheURL.path
        ]
        if let documentExportURL {
            arguments += ["--output-dir", documentExportURL.path]
        }
        return try await run(arguments: arguments)
    }

    func sections(accession: String, documentType: String, filename: String) async throws -> DatamuleSectionsResponse {
        try await run(arguments: [
            "sections",
            accession,
            "--document-type", documentType,
            "--filename", filename,
            "--cache-dir", cacheURL.path
        ])
    }

    func section(accession: String, documentType: String, filename: String, section: String, format: String) async throws -> DatamuleSectionResponse {
        try await run(arguments: [
            "section",
            accession,
            "--document-type", documentType,
            "--filename", filename,
            "--section", section,
            "--format", format,
            "--cache-dir", cacheURL.path
        ])
    }

    private func run<T: Decodable>(arguments: [String]) async throws -> T {
        let data = try await runRaw(arguments: arguments)
        do {
            let response = try JSONDecoder().decode(T.self, from: data)
            if let bridgeResponse = response as? DatamuleBridgeResponse, !bridgeResponse.ok {
                throw DatamuleBridgeError.processFailed(bridgeResponse.error ?? "Unknown datamule bridge error")
            }
            return response
        } catch let error as DatamuleBridgeError {
            throw error
        } catch {
            let snippet = String(data: data.prefix(1_000), encoding: .utf8) ?? ""
            throw DatamuleBridgeError.decodeFailed("\(error.localizedDescription)\n\(snippet)")
        }
    }

    private func runRaw(arguments: [String]) async throws -> Data {
        let executable = pythonExecutable
        let script = scriptURL
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = executable
            process.arguments = [script.path] + arguments
            process.currentDirectoryURL = projectRoot
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return output
            }

            let stderrMessage = String(data: errorOutput, encoding: .utf8)
            let stdoutMessage = String(data: output, encoding: .utf8)
            throw DatamuleBridgeError.processFailed(stderrMessage ?? stdoutMessage ?? "Unknown datamule bridge error")
        }.value
    }

    private static func findProjectRoot() -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let script = candidate.appendingPathComponent("tools/datamule_bridge.py")
            if FileManager.default.fileExists(atPath: script.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

protocol DatamuleBridgeResponse {
    var ok: Bool { get }
    var error: String? { get }
}

struct DatamuleResolveResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let ticker: String?
    let ciks: [Int]?
}

struct DatamuleTickersResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let count: Int
    let companies: [DatamuleCompanyPayload]
}

struct DatamuleCompanyPayload: Decodable {
    let ticker: String
    let cik: String?
    let name: String?
    let exchange: String?
    let industry: String?
}

struct DatamuleProfileResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let ticker: String?
    let longName: String?
    let shortName: String?
    let summary: String?
    let sector: String?
    let industry: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case ticker
        case longName = "long_name"
        case shortName = "short_name"
        case summary
        case sector
        case industry
        case website
    }
}

struct DatamuleSearchResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let ticker: String?
    let count: Int
    let results: [DatamuleFilingHit]
}

struct DatamuleFilingHit: Decodable {
    let id: String?
    let accession: String?
    let form: String?
    let rootForms: [String]?
    let filingDate: String?
    let periodEnding: String?
    let displayNames: [String]?
    let description: String?
    let filename: String?
    let ciks: [String]?
    let items: [String]?
    let fileNumber: [String]?
    let filmNumber: [String]?
    let businessLocations: [String]?
    let businessStates: [String]?
    let incorporationStates: [String]?
    let sics: [String]?
    let sequence: Int?
    let xsl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case accession
        case form
        case rootForms = "root_forms"
        case filingDate = "filing_date"
        case periodEnding = "period_ending"
        case displayNames = "display_names"
        case description
        case filename
        case ciks
        case items
        case fileNumber = "file_number"
        case filmNumber = "film_number"
        case businessLocations = "business_locations"
        case businessStates = "business_states"
        case incorporationStates = "incorporation_states"
        case sics
        case sequence
        case xsl
    }
}

struct DatamuleDownloadResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let cacheDir: String?
    let downloadedTarCount: Int?
    let files: [String]?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case cacheDir = "cache_dir"
        case downloadedTarCount = "downloaded_tar_count"
        case files
    }
}

struct DatamuleDocumentsResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let count: Int
    let submissions: [DatamuleSubmissionPayload]
}

struct DatamuleSubmissionPayload: Decodable {
    let accession: String
    let filingDate: String?
    let documents: [DatamuleDocumentPayload]

    enum CodingKeys: String, CodingKey {
        case accession
        case filingDate = "filing_date"
        case documents
    }
}

struct DatamuleDocumentPayload: Decodable {
    let sequence: String?
    let type: String?
    let filename: String?
    let description: String?
}

struct DatamuleDocumentContentResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let accession: String?
    let documentType: String?
    let filename: String?
    let path: String?
    let html: String?
    let text: String?
    let markdown: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case accession
        case documentType = "document_type"
        case filename
        case path
        case html
        case text
        case markdown
    }
}

struct DatamuleDocumentFileResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let accession: String?
    let documentType: String?
    let filename: String?
    let path: String?
    let contentType: String?
    let byteCount: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case accession
        case documentType = "document_type"
        case filename
        case path
        case contentType = "content_type"
        case byteCount = "byte_count"
    }
}

struct DatamuleSectionsResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let accession: String?
    let count: Int
    let sections: [DatamuleSectionSummary]
}

struct DatamuleSectionSummary: Decodable {
    let key: String?
    let lookupKey: String?
    let title: String?
    let sectionClass: String?
    let wordCount: Int?

    enum CodingKeys: String, CodingKey {
        case key
        case lookupKey = "lookup_key"
        case title
        case sectionClass = "class"
        case wordCount = "word_count"
    }
}

struct DatamuleSectionResponse: Decodable, DatamuleBridgeResponse {
    let ok: Bool
    let error: String?
    let accession: String?
    let documentType: String?
    let filename: String?
    let section: String?
    let count: Int
    let sections: [String]

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case accession
        case documentType = "document_type"
        case filename
        case section
        case count
        case sections
    }
}

enum DatamuleBridgeError: Error, LocalizedError {
    case processFailed(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let message), .decodeFailed(let message):
            message
        }
    }
}
