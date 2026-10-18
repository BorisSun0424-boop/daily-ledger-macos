import XCTest
@testable import DailyLedgerCore

final class DomainModelTests: XCTestCase {
    func testMoneyParsingUsesExactCents() {
        XCTAssertEqual(Money.parseCents("12.34"), 1_234)
        XCTAssertEqual(Money.parseCents("¥ 1,234.56"), 123_456)
        XCTAssertEqual(Money.parseCents("0.005"), 1)
        XCTAssertNil(Money.parseCents(""))
        XCTAssertNil(Money.parseCents("十二元"))
    }

    func testMoneyFormattingUsesChineseYuan() {
        let formatted = Money.format(cents: 123_456)
        XCTAssertTrue(formatted.contains("1,234.56"))
        XCTAssertTrue(formatted.contains("¥") || formatted.contains("￥"))
    }

    func testDefaultCategoriesMatchPRD() {
        let categories = LedgerDefaults.categories()
        XCTAssertEqual(categories.filter { $0.kind == .expense }.map(\.name), LedgerDefaults.expenseCategoryNames)
        XCTAssertEqual(categories.filter { $0.kind == .income }.map(\.name), LedgerDefaults.incomeCategoryNames)
        XCTAssertTrue(categories.allSatisfy(\.isSystem))
    }

    func testMonthArithmeticCrossesYearBoundary() {
        XCTAssertEqual(MonthKey(year: 2026, month: 12).adding(months: 1), MonthKey(year: 2027, month: 1))
        XCTAssertEqual(MonthKey(year: 2026, month: 1).adding(months: -1), MonthKey(year: 2025, month: 12))
    }

    func testLedgerDataCodableRoundTrip() throws {
        let account = LedgerAccount(name: "现金", openingBalanceCents: 50_000)
        let category = LedgerCategory(name: "餐饮", kind: .expense, sortOrder: 0)
        let entry = LedgerEntry(kind: .expense, amountCents: 2_580, categoryID: category.id, accountID: account.id, date: Date(timeIntervalSince1970: 1_700_000_000), note: "午饭")
        let original = LedgerData(accounts: [account], categories: [category], entries: [entry], budgets: [MonthlyBudget(month: MonthKey(year: 2026, month: 10), amountCents: 300_000)])
        let decoded = try JSONDecoder().decode(LedgerData.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }
}
