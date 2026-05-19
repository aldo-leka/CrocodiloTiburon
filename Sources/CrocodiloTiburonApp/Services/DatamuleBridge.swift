import Foundation

struct DatamuleBridge {
    var pythonExecutable: URL = URL(fileURLWithPath: "/usr/bin/python3")
    var scriptURL: URL

    init(projectRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.scriptURL = projectRoot.appendingPathComponent("tools/datamule_bridge.py")
    }

    func resolve(ticker: String) async throws -> Data {
        try await run(arguments: ["resolve", ticker])
    }

    func search(ticker: String, forms: [String], start: String, end: String) async throws -> Data {
        try await run(arguments: ["search", ticker, "--forms"] + forms + ["--start", start, "--end", end])
    }

    private func run(arguments: [String]) async throws -> Data {
        let executable = pythonExecutable
        let script = scriptURL
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = executable
            process.arguments = [script.path] + arguments
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus == 0 {
                return output
            }

            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown datamule bridge error"
            throw DatamuleBridgeError.processFailed(message)
        }.value
    }
}

enum DatamuleBridgeError: Error, LocalizedError {
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let message): message
        }
    }
}
