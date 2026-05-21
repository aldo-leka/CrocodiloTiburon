import Foundation
import XCTest

final class StressTickerFixtureTests: XCTestCase {
    func testStressTickerFixtureContainsOneHundredTickersStartingWithA() throws {
        let fixtureURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "CrocodiloTiburonUITests", directoryHint: .isDirectory)
            .appending(path: "Fixtures", directoryHint: .isDirectory)
            .appending(path: "StressTickers.txt")

        let tickers = try String(contentsOf: fixtureURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(tickers.count, 100)
        XCTAssertEqual(tickers.first, "A")
        XCTAssertEqual(Set(tickers).count, tickers.count)
    }
}
