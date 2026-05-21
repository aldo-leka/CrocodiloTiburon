import AppKit
import ApplicationServices
import Foundation

enum RunnerError: Error, CustomStringConvertible {
    case failure(String)

    var description: String {
        switch self {
        case .failure(let message): message
        }
    }
}

enum ID {
    static let appShell = "ct.app.shell"
    static let searchField = "ct.sidebar.searchField"
    static let companyRowPrefix = "ct.company.row."
    static let companyWorkspaceScroll = "ct.company.workspaceScroll"
    static let filingsList = "ct.filings.list"
    static let filingsCatalog = "ct.filings.catalog"
    static let filingRowPrefix = "ct.filings.row."
    static let readerDocumentButtonPrefix = "ct.reader.document."
    static let readerWorkspace = "ct.reader.workspace"
    static let readerLoading = "ct.reader.loading"
    static let readerText = "ct.reader.text"
    static let readerPDF = "ct.reader.pdf"
    static let readerEmpty = "ct.reader.empty"

    static func companyRow(ticker: String) -> String {
        companyRowPrefix + normalized(ticker)
    }

    static func filingRow(accession: String) -> String {
        filingRowPrefix + normalized(accession)
    }

    static func normalized(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar).lowercased() : "_"
        }
        .joined()
    }
}

struct Configuration {
    enum Mode {
        case smoke
        case stress
    }

    var mode: Mode = .smoke
    var tickerLimit = 100
    var documentLimit = 100
    var readerTimeout: TimeInterval = 120
    var documentListTimeout: TimeInterval {
        min(readerTimeout, 30)
    }
    var maxFilingsPerTicker = 40
    var allowPartial = false
    var isolatedDatabase = false
    var appPath: String?
    var tickers: [String] = []
}

struct ElementInfo {
    let identifier: String
    let value: String?

    private var fields: [String] {
        value?.split(separator: "|").map(String.init) ?? []
    }

    var documentID: String? {
        if identifier.hasPrefix(ID.readerDocumentButtonPrefix), fields.count >= 2 {
            return fields[1]
        }
        return fields.last
    }

    var filingID: String? {
        if identifier.hasPrefix(ID.readerDocumentButtonPrefix), fields.count >= 3 {
            return fields[2]
        }
        if identifier.hasPrefix(ID.filingRowPrefix), fields.count >= 2 {
            return fields[1]
        }
        return nil
    }

    var companyID: String? {
        if identifier.hasPrefix(ID.filingRowPrefix), fields.count >= 3 {
            return fields[2]
        }
        if identifier.hasPrefix(ID.companyRowPrefix), fields.count >= 2 {
            return fields[1]
        }
        return nil
    }
}

@main
struct CrocodiloTiburonUITestRunner {
    static func main() async {
        do {
            let configuration = try parseConfiguration()
            try await AccessibilityStressTest(configuration: configuration).run()
        } catch {
            fputs("UI stress test failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func parseConfiguration() throws -> Configuration {
        var configuration = Configuration()
        var arguments = Array(CommandLine.arguments.dropFirst())

        if arguments.isEmpty {
            arguments = ["--smoke"]
        }

        while let argument = arguments.first {
            arguments.removeFirst()

            switch argument {
            case "--smoke":
                configuration.mode = .smoke
                configuration.tickerLimit = 1
                configuration.documentLimit = intEnvironment("CROCODILO_UI_SMOKE_DOCUMENT_LIMIT", default: 12)
                configuration.tickers = ["A"]
            case "--stress":
                configuration.mode = .stress
                configuration.tickerLimit = intEnvironment("CROCODILO_UI_STRESS_TICKER_LIMIT", default: 100)
                configuration.documentLimit = intEnvironment("CROCODILO_UI_STRESS_DOCUMENT_LIMIT", default: 100)
            case "--ticker-limit":
                configuration.tickerLimit = try popInt(from: &arguments, name: argument)
            case "--document-limit":
                configuration.documentLimit = try popInt(from: &arguments, name: argument)
            case "--reader-timeout":
                configuration.readerTimeout = TimeInterval(try popInt(from: &arguments, name: argument))
            case "--max-filings":
                configuration.maxFilingsPerTicker = try popInt(from: &arguments, name: argument)
            case "--allow-partial":
                configuration.allowPartial = true
            case "--isolated-database":
                configuration.isolatedDatabase = true
            case "--app-path":
                configuration.appPath = try popString(from: &arguments, name: argument)
            case "--ticker":
                configuration.tickers.append(try popString(from: &arguments, name: argument).uppercased())
            default:
                throw RunnerError.failure("Unknown argument: \(argument)")
            }
        }

        if configuration.tickers.isEmpty {
            configuration.tickers = try loadStressTickers().map { $0.uppercased() }
        }

        configuration.readerTimeout = TimeInterval(
            intEnvironment("CROCODILO_UI_READER_TIMEOUT", default: Int(configuration.readerTimeout))
        )
        configuration.maxFilingsPerTicker = intEnvironment(
            "CROCODILO_UI_MAX_FILINGS_PER_TICKER",
            default: configuration.maxFilingsPerTicker
        )
        configuration.allowPartial = configuration.allowPartial || isEnabled("CROCODILO_UI_ALLOW_PARTIAL_STRESS")
        configuration.isolatedDatabase = configuration.isolatedDatabase || isEnabled("CROCODILO_UI_ISOLATED_DATABASE")

        return configuration
    }

    private static func popString(from arguments: inout [String], name: String) throws -> String {
        guard !arguments.isEmpty else {
            throw RunnerError.failure("\(name) requires a value.")
        }
        return arguments.removeFirst()
    }

    private static func popInt(from arguments: inout [String], name: String) throws -> Int {
        let value = try popString(from: &arguments, name: name)
        guard let intValue = Int(value) else {
            throw RunnerError.failure("\(name) requires an integer value.")
        }
        return intValue
    }

    private static func loadStressTickers() throws -> [String] {
        let root = try projectRoot()
        let url = root
            .appending(path: "Tests", directoryHint: .isDirectory)
            .appending(path: "CrocodiloTiburonUITests", directoryHint: .isDirectory)
            .appending(path: "Fixtures", directoryHint: .isDirectory)
            .appending(path: "StressTickers.txt")
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    fileprivate static func projectRoot() throws -> URL {
        var candidate = URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: candidate.appending(path: "Package.swift").path),
               FileManager.default.fileExists(atPath: candidate.appending(path: "tools/datamule_bridge.py").path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw RunnerError.failure("Could not find the project root.")
    }

    private static func isEnabled(_ key: String) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[key] else { return false }
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func intEnvironment(_ key: String, default defaultValue: Int) -> Int {
        guard let rawValue = ProcessInfo.processInfo.environment[key], let value = Int(rawValue) else {
            return defaultValue
        }
        return value
    }
}

struct AccessibilityStressTest {
    let configuration: Configuration
    private let fileManager = FileManager.default
    private let searchCommandURL = FileManager.default.temporaryDirectory
        .appending(path: "CrocodiloTiburonUITests", directoryHint: .isDirectory)
        .appending(path: "search-\(UUID().uuidString).txt")

    func run() async throws {
        try ensureAccessibilityTrusted()
        try prepareSearchCommandFile()

        let appBundleURL = try wrappedApplicationBundleURL()
        let application = try await launchApplication(at: appBundleURL)
        defer {
            try? fileManager.removeItem(at: searchCommandURL)
            application.terminate()
        }

        let automation = AXAutomation(processIdentifier: application.processIdentifier)
        _ = try automation.waitForElement(identifier: ID.searchField, timeout: 60)

        let tickers = Array(configuration.tickers.prefix(configuration.tickerLimit))
        guard !tickers.isEmpty else {
            throw RunnerError.failure("Ticker list is empty.")
        }

        for ticker in tickers {
            print("Testing \(ticker)...")
            let verifiedCount = try verify(ticker: ticker, automation: automation)
            print("Verified \(verifiedCount) reader documents for \(ticker).")

            if verifiedCount == 0 {
                throw RunnerError.failure("\(ticker) did not show any readable filing documents.")
            }
            if !configuration.allowPartial, verifiedCount < configuration.documentLimit {
                throw RunnerError.failure(
                    "\(ticker) only verified \(verifiedCount) of \(configuration.documentLimit) requested documents."
                )
            }
        }
    }

    private func launchApplication(at bundleURL: URL) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.environment = launchEnvironment()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let application else {
                    continuation.resume(throwing: RunnerError.failure("NSWorkspace did not return a launched application."))
                    return
                }

                continuation.resume(returning: application)
            }
        }
    }

    private func verify(ticker: String, automation: AXAutomation) throws -> Int {
        let companyID = try open(ticker: ticker, automation: automation)

        var verifiedDocumentIDs = Set<String>()
        var verifiedCount = 0
        let initialRows = try waitForFilingRows(companyID: companyID, automation: automation, timeout: 180)
        print("Found \(initialRows.count) filing candidates for \(ticker).")
        let initialFilingID = initialRows.first?.filingID
        let initialDocuments = (try? automation.waitForElementInfos(
            prefix: ID.readerDocumentButtonPrefix,
            minimumCount: 1,
            timeout: configuration.documentListTimeout,
            matching: { initialFilingID == nil || $0.filingID == initialFilingID }
        )) ?? []
        if let initialDocumentID = initialDocuments.first?.documentID {
            let state = try automation.waitForReaderContent(
                expectedDocumentID: initialDocumentID,
                timeout: configuration.readerTimeout
            )
            guard state.contains(initialDocumentID) else {
                throw RunnerError.failure("Initial reader loaded the wrong document. Expected \(initialDocumentID), got \(state).")
            }
            verifiedDocumentIDs.insert(initialDocumentID)
            verifiedCount = verifiedDocumentIDs.count
            if verifiedCount >= configuration.documentLimit {
                return verifiedCount
            }
        }

        var processedFilingRows = Set<String>()
        var stagnantScrolls = 0

        while processedFilingRows.count < configuration.maxFilingsPerTicker, stagnantScrolls < 8 {
            let filingRows = filingRows(companyID: companyID, automation: automation)
            let unprocessedRows = filingRows.filter { !processedFilingRows.contains($0.identifier) }

            guard !unprocessedRows.isEmpty else {
                if automation.scrollDown(identifier: ID.companyWorkspaceScroll) {
                    stagnantScrolls += 1
                    continue
                }
                break
            }

            stagnantScrolls = 0

            for filingRow in unprocessedRows {
                guard processedFilingRows.count < configuration.maxFilingsPerTicker else { break }
                processedFilingRows.insert(filingRow.identifier)

                let selectedFilingID = filingRow.filingID
                try selectFiling(filingRow, automation: automation)

                let documents = (try? automation.waitForElementInfos(
                    prefix: ID.readerDocumentButtonPrefix,
                    minimumCount: 1,
                    timeout: configuration.documentListTimeout,
                    matching: { selectedFilingID == nil || $0.filingID == selectedFilingID }
                )) ?? []

                guard !documents.isEmpty else {
                    continue
                }

                for (documentIndex, document) in documents.enumerated() {
                    guard let documentID = document.documentID, !verifiedDocumentIDs.contains(documentID) else {
                        continue
                    }

                    let state: String
                    if documentIndex == 0,
                       let autoSelectedState = try? automation.waitForReaderContent(
                        expectedDocumentID: documentID,
                        timeout: min(configuration.readerTimeout, 30)
                       ) {
                        state = autoSelectedState
                    } else if documentIndex == 0,
                              selectedFilingID != nil,
                              let reselectedState = try? reselectFilingAndWaitForPrimaryDocument(
                                filingRow,
                                expectedDocumentID: documentID,
                                automation: automation
                              ) {
                        state = reselectedState
                    } else {
                        state = try verifyDocument(document, expectedDocumentID: documentID, automation: automation)
                    }
                    guard state.contains(documentID) else {
                        throw RunnerError.failure("Reader loaded the wrong document. Expected \(documentID), got \(state).")
                    }

                    verifiedDocumentIDs.insert(documentID)
                    verifiedCount = verifiedDocumentIDs.count
                    if verifiedCount >= configuration.documentLimit {
                        return verifiedCount
                    }
                }

                if documents.count >= 2 {
                    try verifyRapidSwitch(from: documents[0], to: documents[1], automation: automation)
                }
            }

            if verifiedCount >= configuration.documentLimit {
                return verifiedCount
            }

            _ = automation.scrollDown(identifier: ID.companyWorkspaceScroll)
        }

        return verifiedCount
    }

    private func reselectFilingAndWaitForPrimaryDocument(
        _ filingRow: ElementInfo,
        expectedDocumentID: String,
        automation: AXAutomation
    ) throws -> String {
        try selectFiling(filingRow, automation: automation)
        return try automation.waitForReaderContent(
            expectedDocumentID: expectedDocumentID,
            timeout: configuration.readerTimeout
        )
    }

    private func verifyDocument(
        _ document: ElementInfo,
        expectedDocumentID: String,
        automation: AXAutomation
    ) throws -> String {
        var lastError: Error?
        var lastContentError: Error?
        let firstAttemptTimeout = min(configuration.readerTimeout, 30)

        for attempt in 0..<3 {
            do {
                try automation.press(identifier: document.identifier, timeout: 10)
            } catch {
                if let state = try? automation.waitForReaderContent(
                    expectedDocumentID: expectedDocumentID,
                    timeout: firstAttemptTimeout
                ) {
                    return state
                }
                do {
                    _ = try automation.waitForReaderContent(
                        expectedDocumentID: expectedDocumentID,
                        timeout: 1
                    )
                } catch {
                    lastContentError = error
                }
                lastError = error
                continue
            }
            do {
                return try automation.waitForReaderContent(
                    expectedDocumentID: expectedDocumentID,
                    timeout: attempt == 2 ? configuration.readerTimeout : firstAttemptTimeout
                )
            } catch {
                lastContentError = error
                lastError = error
            }
        }

        throw lastContentError ?? lastError ?? RunnerError.failure("Reader did not load document \(expectedDocumentID).")
    }

    private func open(ticker: String, automation: AXAutomation) throws -> String? {
        _ = try automation.waitForElement(identifier: ID.searchField, timeout: 30)
        try writeSearchCommand(ticker)

        guard let row = automation.waitForOptionalElement(identifier: ID.companyRow(ticker: ticker), timeout: 180) else {
            throw RunnerError.failure("Could not find ticker row \(ticker).")
        }
        let companyID = automation.elementInfo(from: row).companyID

        try automation.press(row)
        _ = try waitForFilingRows(companyID: companyID, automation: automation, timeout: 180)
        return companyID
    }

    private func waitForFilingRows(
        companyID: String?,
        automation: AXAutomation,
        timeout: TimeInterval
    ) throws -> [ElementInfo] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let matches = filingRows(companyID: companyID, automation: automation)
            if !matches.isEmpty {
                return matches
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        throw RunnerError.failure("Timed out waiting for filing rows.")
    }

    private func filingRows(companyID: String?, automation: AXAutomation) -> [ElementInfo] {
        let catalogRows = filingCatalogRows(companyID: companyID, automation: automation)
        if !catalogRows.isEmpty {
            return catalogRows
        }

        return automation.elementInfos(prefix: ID.filingRowPrefix)
            .filter { companyID == nil || $0.companyID == companyID }
    }

    private func filingCatalogRows(companyID: String?, automation: AXAutomation) -> [ElementInfo] {
        guard let catalog = automation.value(identifier: ID.filingsCatalog)
            ?? automation.value(identifier: ID.filingsList)
        else {
            return []
        }

        return catalog.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3 else { return nil }
            guard companyID == nil || fields[2] == companyID else { return nil }
            return ElementInfo(identifier: ID.filingRow(accession: fields[0]), value: String(line))
        }
    }

    private func selectFiling(_ filingRow: ElementInfo, automation: AXAutomation) throws {
        guard let filingID = filingRow.filingID else {
            try automation.press(identifier: filingRow.identifier, timeout: 10)
            return
        }

        try writeFilingCommand(filingID)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }

    private func verifyRapidSwitch(from firstDocument: ElementInfo, to secondDocument: ElementInfo, automation: AXAutomation) throws {
        guard let expectedDocumentID = secondDocument.documentID else {
            throw RunnerError.failure("Could not read the second document identifier before rapid switching.")
        }

        try automation.press(identifier: firstDocument.identifier, timeout: 10)
        let state = try verifyDocument(secondDocument, expectedDocumentID: expectedDocumentID, automation: automation)

        guard state.contains(expectedDocumentID) else {
            throw RunnerError.failure("Rapid switch loaded the wrong content. Expected \(expectedDocumentID), got \(state).")
        }
    }

    private func ensureAccessibilityTrusted() throws {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw RunnerError.failure(
                "Accessibility permission is required. Grant Terminal or your IDE permission in System Settings > Privacy & Security > Accessibility, then rerun the UI test."
            )
        }
    }

    private func prepareSearchCommandFile() throws {
        try fileManager.createDirectory(
            at: searchCommandURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "".write(to: searchCommandURL, atomically: true, encoding: .utf8)
    }

    private func writeSearchCommand(_ ticker: String) throws {
        try "search:\(ticker)".write(to: searchCommandURL, atomically: true, encoding: .utf8)
    }

    private func writeFilingCommand(_ filingID: String) throws {
        try "filing:\(filingID)".write(to: searchCommandURL, atomically: true, encoding: .utf8)
    }

    private func launchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CROCODILO_UI_TESTING"] = "1"
        environment["CROCODILO_INCLUDE_OWNERSHIP_REPORTS"] = "1"
        environment["CROCODILO_PROJECT_ROOT"] = (try? CrocodiloTiburonUITestRunner.projectRoot().path) ?? fileManager.currentDirectoryPath
        environment["CROCODILO_UI_SEARCH_COMMAND_PATH"] = searchCommandURL.path

        if configuration.isolatedDatabase {
            let databaseURL = fileManager.temporaryDirectory
                .appending(path: "CrocodiloTiburonUITests", directoryHint: .isDirectory)
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
                .appending(path: "CrocodiloTiburon.sqlite")
            environment["CROCODILO_DATABASE_PATH"] = databaseURL.path
        }

        return environment
    }

    private func wrappedApplicationBundleURL() throws -> URL {
        let executableURL = try appExecutableURL()
        guard executableURL.pathExtension != "app" else { return executableURL }

        let productsURL = executableURL.deletingLastPathComponent()
        let bundleURL = productsURL.appending(path: "CrocodiloTiburonUITest.app", directoryHint: .isDirectory)
        let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        let macOSURL = contentsURL.appending(path: "MacOS", directoryHint: .isDirectory)
        let bundledExecutableURL = macOSURL.appending(path: "CrocodiloTiburon")

        if fileManager.fileExists(atPath: bundleURL.path) {
            try fileManager.removeItem(at: bundleURL)
        }

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: executableURL, to: bundledExecutableURL)

        for bundleName in [
            "CrocodiloTiburon_CrocodiloTiburonApp.bundle",
            "GRDB_GRDB.bundle"
        ] {
            let sourceURL = productsURL.appending(path: bundleName, directoryHint: .isDirectory)
            let destinationURL = bundleURL.appending(path: bundleName, directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleExecutable</key>
            <string>CrocodiloTiburon</string>
            <key>CFBundleIdentifier</key>
            <string>com.aldo-leka.CrocodiloTiburon.UITests</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>Crocodilo Tiburon UITest</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSMinimumSystemVersion</key>
            <string>15.0</string>
            <key>NSHighResolutionCapable</key>
            <true/>
        </dict>
        </plist>
        """

        try infoPlist.write(to: contentsURL.appending(path: "Info.plist"), atomically: true, encoding: .utf8)
        return bundleURL
    }

    private func appExecutableURL() throws -> URL {
        if let appPath = configuration.appPath {
            let url = URL(filePath: appPath)
            guard fileManager.fileExists(atPath: url.path) else {
                throw RunnerError.failure("--app-path does not exist: \(appPath)")
            }
            return url
        }

        let root = try CrocodiloTiburonUITestRunner.projectRoot()
        let candidates = [
            root.appending(path: ".build/arm64-apple-macosx/debug/CrocodiloTiburon"),
            root.appending(path: ".build/debug/CrocodiloTiburon")
        ]

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw RunnerError.failure("Could not find the built app executable. Run swift build first.")
    }
}

final class AXAutomation {
    private let app: AXUIElement
    private let processIdentifier: pid_t

    init(processIdentifier: pid_t) {
        self.processIdentifier = processIdentifier
        self.app = AXUIElementCreateApplication(processIdentifier)
    }

    func waitForElement(identifier: String, timeout: TimeInterval) throws -> AXUIElement {
        if let element = waitForOptionalElement(identifier: identifier, timeout: timeout) {
            return element
        }
        throw RunnerError.failure("Timed out waiting for \(identifier). \(elementDiagnostic())")
    }

    func waitForOptionalElement(identifier: String, timeout: TimeInterval) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let element = element(identifier: identifier) {
                return element
            }
            pumpRunLoop()
        }
        return nil
    }

    func waitForElements(prefix: String, minimumCount: Int, timeout: TimeInterval) throws -> [AXUIElement] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let matches = elements(prefix: prefix)
            if matches.count >= minimumCount {
                return matches
            }
            pumpRunLoop()
        }
        throw RunnerError.failure("Timed out waiting for \(minimumCount) elements with prefix \(prefix).")
    }

    func waitForElementInfos(
        prefix: String,
        minimumCount: Int,
        timeout: TimeInterval,
        matching predicate: (ElementInfo) -> Bool = { _ in true }
    ) throws -> [ElementInfo] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let matches = elementInfos(prefix: prefix).filter(predicate)
            if matches.count >= minimumCount {
                return matches
            }
            pumpRunLoop()
        }
        throw RunnerError.failure("Timed out waiting for \(minimumCount) elements with prefix \(prefix).")
    }

    func elements(prefix: String) -> [AXUIElement] {
        allElements().filter { identifier(of: $0)?.hasPrefix(prefix) == true }
    }

    func elementInfos(prefix: String) -> [ElementInfo] {
        var seen = Set<String>()
        var matches: [ElementInfo] = []

        for element in allElements() {
            guard let identifier = identifier(of: element), identifier.hasPrefix(prefix) else {
                continue
            }
            guard seen.insert(identifier).inserted else {
                continue
            }
            matches.append(ElementInfo(identifier: identifier, value: stringAttribute(kAXValueAttribute, from: element)))
        }

        return matches
    }

    func elementInfo(from element: AXUIElement) -> ElementInfo {
        ElementInfo(identifier: identifier(of: element) ?? "", value: stringAttribute(kAXValueAttribute, from: element))
    }

    func value(identifier: String) -> String? {
        element(identifier: identifier).flatMap { stringAttribute(kAXValueAttribute, from: $0) }
    }

    func documentID(from element: AXUIElement) -> String? {
        guard let value = stringAttribute(kAXValueAttribute, from: element) else { return nil }
        return value.split(separator: "|").last.map(String.init)
    }

    func setText(_ text: String, in element: AXUIElement) throws {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        pumpRunLoop(0.4)

        guard stringAttribute(kAXValueAttribute, from: element) == text else {
            throw RunnerError.failure("Could not enter \(text) in the ticker search field.")
        }
    }

    func press(identifier: String, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?

        while Date() < deadline {
            if let element = element(identifier: identifier) {
                do {
                    try press(element)
                    return
                } catch {
                    lastError = error
                }
            }
            pumpRunLoop(0.1)
        }

        if let lastError {
            throw RunnerError.failure("Could not press \(identifier): \(lastError).")
        }
        throw RunnerError.failure("Could not find \(identifier) to press.")
    }

    func press(_ element: AXUIElement) throws {
        if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            pumpRunLoop(0.2)
            return
        }

        throw RunnerError.failure("Could not press \(debugDescription(of: element)).")
    }

    func scrollDown(identifier: String) -> Bool {
        guard let element = element(identifier: identifier) else {
            return false
        }

        guard AXUIElementPerformAction(element, "AXScrollDown" as CFString) == .success else {
            return false
        }
        pumpRunLoop(0.5)
        return true
    }

    func waitForReaderContent(expectedDocumentID: String, timeout: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var sawEmptyReader = false

        while Date() < deadline {
            guard isAppRunning else {
                throw RunnerError.failure("App process exited while waiting for reader content for document \(expectedDocumentID).")
            }

            if let state = loadedReaderState(expectedDocumentID: expectedDocumentID) {
                return state
            }

            let emptyReader = element(identifier: ID.readerEmpty)
            if emptyReader != nil, element(identifier: ID.readerLoading) == nil {
                sawEmptyReader = true
            }

            pumpRunLoop(0.25)
        }

        if sawEmptyReader {
            throw RunnerError.failure(
                "Timed out waiting for reader content for document \(expectedDocumentID) after seeing an empty reader state. \(readerDiagnostic())"
            )
        }

        throw RunnerError.failure("Timed out waiting for reader content for document \(expectedDocumentID). \(readerDiagnostic())")
    }

    private var isAppRunning: Bool {
        kill(processIdentifier, 0) == 0
    }

    private func loadedReaderState(expectedDocumentID: String) -> String? {
        for textIdentifier in [ID.readerText, ID.readerWorkspace] {
            for textReader in elements(identifier: textIdentifier) {
                if let value = stringAttribute(kAXValueAttribute, from: textReader),
                   (value.hasPrefix("text:") || value.hasPrefix("markdown:")),
                   value.contains(expectedDocumentID) {
                    return value
                }
            }
        }

        for pdfReader in elements(identifier: ID.readerPDF) {
            if let value = stringAttribute(kAXValueAttribute, from: pdfReader),
               value.hasPrefix("pdf:"),
               value.contains(expectedDocumentID) {
                return value
            }
        }

        return nil
    }

    private func readerDiagnostic() -> String {
        let appState = element(identifier: ID.appShell).flatMap { stringAttribute(kAXValueAttribute, from: $0) } ?? "no app state"
        let emptyState = element(identifier: ID.readerEmpty).flatMap { stringAttribute(kAXValueAttribute, from: $0) } ?? "no empty state"
        let textStates = elements(identifier: ID.readerText)
            .compactMap { stringAttribute(kAXValueAttribute, from: $0) }
            .prefix(3)
            .joined(separator: ", ")
        let pdfStates = elements(identifier: ID.readerPDF)
            .compactMap { stringAttribute(kAXValueAttribute, from: $0) }
            .prefix(3)
            .joined(separator: ", ")

        return "app=\(appState) empty=\(emptyState) text=[\(textStates)] pdf=[\(pdfStates)]"
    }

    private func elementDiagnostic() -> String {
        let identifiers = allElements()
            .compactMap { identifier(of: $0) }
            .prefix(40)
            .joined(separator: ", ")
        let windows: [AXUIElement]? = attribute(kAXWindowsAttribute, from: app)
        let windowCount = windows?.count ?? 0
        let windowDetails = (windows ?? [])
            .prefix(3)
            .map { window -> String in
                let role = stringAttribute(kAXRoleAttribute, from: window) ?? "?"
                let title = stringAttribute(kAXTitleAttribute, from: window) ?? "?"
                let children: [AXUIElement]? = attribute(kAXChildrenAttribute, from: window)
                let navigationChildren: [AXUIElement]? = attribute("AXChildrenInNavigationOrder", from: window)
                let contents: [AXUIElement]? = attribute("AXContents", from: window)
                return "\(role):\(title):children=\(children?.count ?? 0):nav=\(navigationChildren?.count ?? 0):contents=\(contents?.count ?? 0)"
            }
            .joined(separator: ", ")
        return "running=\(isAppRunning) windows=\(windowCount) windowDetails=[\(windowDetails)] identifiers=[\(identifiers)]"
    }

    private func element(identifier: String) -> AXUIElement? {
        elements(identifier: identifier).first
    }

    private func elements(identifier: String) -> [AXUIElement] {
        allElements().filter { self.identifier(of: $0) == identifier }
    }

    private func allElements() -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue = [app]
        var queueIndex = 0
        var scannedCount = 0

        while queueIndex < queue.count, scannedCount < 100_000 {
            let current = queue[queueIndex]
            queueIndex += 1
            scannedCount += 1
            result.append(current)

            if scannedCount == 1 {
                if let focusedWindow: AXUIElement = attribute(kAXFocusedWindowAttribute, from: current) {
                    queue.append(focusedWindow)
                }
                if let windows: [AXUIElement] = attribute(kAXWindowsAttribute, from: current) {
                    queue.append(contentsOf: windows)
                }
                if let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: current) {
                    queue.append(contentsOf: children)
                }
                appendAuxiliaryChildren(of: current, to: &queue)
                continue
            }

            let currentIdentifier = identifier(of: current)
            if currentIdentifier == ID.readerText
                || currentIdentifier == ID.readerPDF
                || currentIdentifier == ID.filingsCatalog {
                continue
            }

            if let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: current) {
                queue.append(contentsOf: children)
            }
            appendAuxiliaryChildren(of: current, to: &queue)
        }

        return result
    }

    private func appendAuxiliaryChildren(of element: AXUIElement, to queue: inout [AXUIElement]) {
        if let navigationChildren: [AXUIElement] = attribute("AXChildrenInNavigationOrder", from: element) {
            queue.append(contentsOf: navigationChildren)
        }
        if let contents: [AXUIElement] = attribute("AXContents", from: element) {
            queue.append(contentsOf: contents)
        } else if let content: AXUIElement = attribute("AXContents", from: element) {
            queue.append(content)
        }
    }

    private func identifier(of element: AXUIElement) -> String? {
        stringAttribute("AXIdentifier", from: element)
    }

    private func debugDescription(of element: AXUIElement) -> String {
        let role = stringAttribute(kAXRoleAttribute, from: element) ?? "unknown role"
        let identifier = identifier(of: element) ?? "no identifier"
        let title = stringAttribute(kAXTitleAttribute, from: element) ?? "no title"
        return "\(role) \(identifier) \(title)"
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        attribute(name, from: element) as String?
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func pumpRunLoop(_ interval: TimeInterval = 0.1) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }
}
