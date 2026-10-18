import XCTest
@testable import DailyLedgerCore

final class LedgerServiceTests: XCTestCase {
    private var directory: URL!
    private var repository: LocalLedgerRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("DailyLedgerServiceTests-\(UUID().uuidString)")
        repository = LocalLedgerRepository(directoryURL: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testAddEditDeleteEntryPersistsAndUpdatesBalance() throws {
        var service = try LedgerService(repository: repository)
        let account = try service.addAccount(name: "现金", openingBalanceCents: 10_000)
        let category = service.data.categories.first { $0.kind == .expense }!
        var entry = LedgerEntry(kind: .expense, amountCents: 1_000, categoryID: category.id, accountID: account.id, date: Date())

        try service.addEntry(entry)
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: service.data), 9_000)

        entry.amountCents = 2_500
        try service.updateEntry(entry)
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: service.data), 7_500)

        try service.deleteEntry(id: entry.id)
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: service.data), 10_000)
        XCTAssertEqual(try repository.load(), service.data)
    }

    func testEntryValidationRejectsInvalidCategoryAndTransfer() throws {
        var service = try LedgerService(repository: repository)
        let account = try service.addAccount(name: "现金", openingBalanceCents: 0)
        let incomeCategory = service.data.categories.first { $0.kind == .income }!

        XCTAssertThrowsError(try service.addEntry(LedgerEntry(kind: .expense, amountCents: 100, categoryID: incomeCategory.id, accountID: account.id, date: Date()))) {
            XCTAssertEqual($0 as? LedgerValidationError, .categoryKindMismatch)
        }
        XCTAssertThrowsError(try service.addEntry(LedgerEntry(kind: .transfer, amountCents: 100, accountID: account.id, destinationAccountID: account.id, date: Date()))) {
            XCTAssertEqual($0 as? LedgerValidationError, .sameTransferAccount)
        }
    }

    func testUsedCategoryRequiresMigrationBeforeDeletion() throws {
        var service = try LedgerService(repository: repository)
        let account = try service.addAccount(name: "现金", openingBalanceCents: 0)
        let source = service.data.categories.first { $0.kind == .expense }!
        let destination = service.data.categories.first { $0.kind == .expense && $0.id != source.id }!
        let entry = LedgerEntry(kind: .expense, amountCents: 100, categoryID: source.id, accountID: account.id, date: Date())
        try service.addEntry(entry)

        XCTAssertThrowsError(try service.deleteCategory(id: source.id)) {
            XCTAssertEqual($0 as? LedgerValidationError, .categoryInUse)
        }
        try service.migrateAndDeleteCategory(from: source.id, to: destination.id)
        XCTAssertFalse(service.data.categories.contains { $0.id == source.id })
        XCTAssertEqual(service.data.entries.first?.categoryID, destination.id)
    }

    func testInactiveAccountIsExcludedAndCannotReceiveNewEntry() throws {
        var service = try LedgerService(repository: repository)
        var account = try service.addAccount(name: "旧卡", openingBalanceCents: 0)
        account.isActive = false
        try service.updateAccount(account)
        let category = service.data.categories.first { $0.kind == .expense }!

        XCTAssertTrue(service.activeAccounts.isEmpty)
        XCTAssertThrowsError(try service.addEntry(LedgerEntry(kind: .expense, amountCents: 100, categoryID: category.id, accountID: account.id, date: Date()))) {
            XCTAssertEqual($0 as? LedgerValidationError, .inactiveAccount)
        }
    }

    func testBudgetReplacesExistingMonthAndPersists() throws {
        var service = try LedgerService(repository: repository)
        let month = MonthKey(year: 2026, month: 10)
        try service.setBudget(month: month, amountCents: 100_000)
        try service.setBudget(month: month, amountCents: 80_000)

        XCTAssertEqual(service.data.budgets, [MonthlyBudget(month: month, amountCents: 80_000)])
        XCTAssertEqual(try repository.load().budgets, service.data.budgets)
    }
}
