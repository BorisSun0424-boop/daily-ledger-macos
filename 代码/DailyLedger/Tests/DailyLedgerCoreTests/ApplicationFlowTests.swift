import XCTest
@testable import DailyLedgerCore

final class ApplicationFlowTests: XCTestCase {
    func testFirstRunThroughReloadKeepsBalancesStatisticsAndBudget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyLedgerFlowTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalLedgerRepository(directoryURL: directory)
        var service = try LedgerService(repository: repository)

        XCTAssertTrue(service.data.accounts.isEmpty)
        XCTAssertEqual(service.data.categories.count, 14)

        let cash = try service.addAccount(name: "现金", openingBalanceCents: 10_000)
        let card = try service.addAccount(name: "银行卡", openingBalanceCents: 50_000)
        let food = service.data.categories.first { $0.kind == .expense && $0.name == "餐饮" }!
        let salary = service.data.categories.first { $0.kind == .income && $0.name == "工资" }!
        let month = MonthKey(year: 2026, month: 10)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!

        try service.setBudget(month: month, amountCents: 100_000)
        try service.addEntry(LedgerEntry(kind: .income, amountCents: 200_000, categoryID: salary.id, accountID: card.id, date: date, note: "工资"))
        try service.addEntry(LedgerEntry(kind: .expense, amountCents: 3_500, categoryID: food.id, accountID: cash.id, date: date, note: "午饭"))
        try service.addEntry(LedgerEntry(kind: .transfer, amountCents: 20_000, accountID: card.id, destinationAccountID: cash.id, date: date))

        let reloaded = try LedgerService(repository: repository)
        XCTAssertEqual(reloaded.data.entries.count, 3)
        XCTAssertEqual(AccountingEngine.balance(of: cash.id, in: reloaded.data), 26_500)
        XCTAssertEqual(AccountingEngine.balance(of: card.id, in: reloaded.data), 230_000)
        XCTAssertEqual(AccountingEngine.totalBalance(in: reloaded.data), 256_500)

        let statistics = StatisticsEngine.statistics(for: month, data: reloaded.data, calendar: calendar)
        XCTAssertEqual(statistics.incomeCents, 200_000)
        XCTAssertEqual(statistics.expenseCents, 3_500)
        XCTAssertEqual(statistics.netCents, 196_500)
        XCTAssertEqual(statistics.categorySpending.first?.name, "餐饮")

        let budget = StatisticsEngine.budgetSnapshot(for: month, data: reloaded.data, today: date, calendar: calendar)
        XCTAssertEqual(budget.budgetCents, 100_000)
        XCTAssertEqual(budget.remainingCents, 96_500)
        XCTAssertEqual(budget.level, .comfortable)
    }
}
