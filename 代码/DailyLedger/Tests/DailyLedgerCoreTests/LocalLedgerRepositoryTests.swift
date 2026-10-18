import XCTest
@testable import DailyLedgerCore

final class LocalLedgerRepositoryTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyLedgerTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testMissingFileLoadsDefaultCategoriesWithoutWriting() throws {
        let repository = LocalLedgerRepository(directoryURL: directory)
        let data = try repository.load()

        XCTAssertEqual(data.categories.count, 14)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testSaveAndLoadRoundTrip() throws {
        let repository = LocalLedgerRepository(directoryURL: directory)
        let account = LedgerAccount(name: "现金", openingBalanceCents: 12_300)
        let category = LedgerCategory(name: "餐饮", kind: .expense, sortOrder: 0)
        let original = LedgerData(
            accounts: [account],
            categories: [category],
            entries: [LedgerEntry(kind: .expense, amountCents: 500, categoryID: category.id, accountID: account.id, date: Date(timeIntervalSince1970: 1_700_000_000))],
            budgets: [MonthlyBudget(month: MonthKey(year: 2026, month: 10), amountCents: 50_000)]
        )

        try repository.save(original)
        XCTAssertEqual(try repository.load(), original)
    }

    func testCorruptFileThrowsAndRemainsUnchanged() throws {
        let repository = LocalLedgerRepository(directoryURL: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: repository.fileURL)

        XCTAssertThrowsError(try repository.load()) { error in
            XCTAssertEqual(error as? RepositoryError, .unreadableData)
        }
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
    }

    func testRepositoryWritesOnlyInsideProvidedDirectory() throws {
        let repository = LocalLedgerRepository(directoryURL: directory)
        try repository.save(LedgerDefaults.emptyData())

        XCTAssertEqual(repository.fileURL.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["ledger.json"])
    }
}
