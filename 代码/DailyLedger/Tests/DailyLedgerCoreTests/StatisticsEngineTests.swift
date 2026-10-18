import XCTest
@testable import DailyLedgerCore

final class StatisticsEngineTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testMonthlyStatisticsExcludeOtherMonthsAndTransfers() {
        let account = LedgerAccount(name: "现金")
        let other = LedgerAccount(name: "银行卡")
        let food = LedgerCategory(name: "餐饮", kind: .expense, sortOrder: 0)
        let data = LedgerData(accounts: [account, other], categories: [food], entries: [
            LedgerEntry(kind: .income, amountCents: 100_000, accountID: account.id, date: date(2026, 10, 1)),
            LedgerEntry(kind: .expense, amountCents: 25_000, categoryID: food.id, accountID: account.id, date: date(2026, 10, 2)),
            LedgerEntry(kind: .transfer, amountCents: 10_000, accountID: account.id, destinationAccountID: other.id, date: date(2026, 10, 3)),
            LedgerEntry(kind: .expense, amountCents: 9_000, categoryID: food.id, accountID: account.id, date: date(2026, 9, 30))
        ])

        let stats = StatisticsEngine.statistics(for: MonthKey(year: 2026, month: 10), data: data, calendar: calendar)
        XCTAssertEqual(stats.incomeCents, 100_000)
        XCTAssertEqual(stats.expenseCents, 25_000)
        XCTAssertEqual(stats.netCents, 75_000)
        XCTAssertEqual(stats.previousMonthExpenseCents, 9_000)
        XCTAssertEqual(stats.expenseChangeCents, 16_000)
    }

    func testCategoryBreakdownIsSortedAndLimitedToTopThree() {
        let account = LedgerAccount(name: "现金")
        let categories = [
            LedgerCategory(name: "餐饮", kind: .expense, sortOrder: 0),
            LedgerCategory(name: "交通", kind: .expense, sortOrder: 1),
            LedgerCategory(name: "购物", kind: .expense, sortOrder: 2),
            LedgerCategory(name: "娱乐", kind: .expense, sortOrder: 3)
        ]
        let amounts: [Int64] = [4_000, 3_000, 2_000, 1_000]
        let entries = zip(categories, amounts).map {
            LedgerEntry(kind: .expense, amountCents: $0.1, categoryID: $0.0.id, accountID: account.id, date: date(2026, 10, 5))
        }
        let stats = StatisticsEngine.statistics(for: MonthKey(year: 2026, month: 10), data: LedgerData(accounts: [account], categories: categories, entries: entries), calendar: calendar)

        XCTAssertEqual(stats.categorySpending.map(\.name), ["餐饮", "交通", "购物", "娱乐"])
        XCTAssertEqual(stats.topCategories.map(\.name), ["餐饮", "交通", "购物"])
        XCTAssertEqual(stats.categorySpending[0].fraction, 0.4, accuracy: 0.0001)
    }

    func testBudgetLevelsAndRemainingAmount() {
        let account = LedgerAccount(name: "现金")
        let category = LedgerCategory(name: "餐饮", kind: .expense, sortOrder: 0)
        let month = MonthKey(year: 2026, month: 10)

        func snapshot(spent: Int64) -> BudgetSnapshot {
            let data = LedgerData(
                accounts: [account],
                categories: [category],
                entries: [LedgerEntry(kind: .expense, amountCents: spent, categoryID: category.id, accountID: account.id, date: date(2026, 10, 10))],
                budgets: [MonthlyBudget(month: month, amountCents: 100_000)]
            )
            return StatisticsEngine.budgetSnapshot(for: month, data: data, today: date(2026, 10, 18), calendar: calendar)
        }

        XCTAssertEqual(snapshot(spent: 50_000).level, .comfortable)
        XCTAssertEqual(snapshot(spent: 80_000).level, .approaching)
        XCTAssertEqual(snapshot(spent: 120_000).level, .exceeded)
        XCTAssertEqual(snapshot(spent: 120_000).remainingCents, -20_000)
        XCTAssertEqual(snapshot(spent: 50_000).remainingDays, 13)
    }

    func testMissingBudgetHasNotSetState() {
        let snapshot = StatisticsEngine.budgetSnapshot(
            for: MonthKey(year: 2026, month: 10),
            data: LedgerData(),
            today: date(2026, 10, 18),
            calendar: calendar
        )
        XCTAssertEqual(snapshot.level, .notSet)
        XCTAssertNil(snapshot.budgetCents)
    }
}
