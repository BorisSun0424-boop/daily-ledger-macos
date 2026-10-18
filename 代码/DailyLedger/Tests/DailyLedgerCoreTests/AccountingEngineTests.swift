import XCTest
@testable import DailyLedgerCore

final class AccountingEngineTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testIncomeAndExpenseUpdateBalance() {
        let account = LedgerAccount(name: "银行卡", openingBalanceCents: 100_000)
        let data = LedgerData(accounts: [account], entries: [
            LedgerEntry(kind: .income, amountCents: 20_000, accountID: account.id, date: date),
            LedgerEntry(kind: .expense, amountCents: 3_500, accountID: account.id, date: date)
        ])

        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 116_500)
    }

    func testTransferMovesMoneyWithoutChangingTotal() {
        let cash = LedgerAccount(name: "现金", openingBalanceCents: 50_000)
        let card = LedgerAccount(name: "银行卡", openingBalanceCents: 100_000)
        let transfer = LedgerEntry(kind: .transfer, amountCents: 20_000, accountID: card.id, destinationAccountID: cash.id, date: date)
        let data = LedgerData(accounts: [cash, card], entries: [transfer])

        XCTAssertEqual(AccountingEngine.balance(of: card.id, in: data), 80_000)
        XCTAssertEqual(AccountingEngine.balance(of: cash.id, in: data), 70_000)
        XCTAssertEqual(AccountingEngine.totalBalance(in: data), 150_000)
    }

    func testInactiveAccountKeepsHistoricalBalance() {
        let account = LedgerAccount(name: "旧卡", openingBalanceCents: 10_000, isActive: false)
        let expense = LedgerEntry(kind: .expense, amountCents: 1_500, accountID: account.id, date: date)
        let data = LedgerData(accounts: [account], entries: [expense])

        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 8_500)
    }

    func testEditingEntryRecalculatesBalance() {
        let account = LedgerAccount(name: "现金", openingBalanceCents: 10_000)
        var entry = LedgerEntry(kind: .expense, amountCents: 1_000, accountID: account.id, date: date)
        var data = LedgerData(accounts: [account], entries: [entry])
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 9_000)

        entry.amountCents = 2_500
        data.entries = [entry]
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 7_500)
    }

    func testDeletingEntryRestoresDerivedBalance() {
        let account = LedgerAccount(name: "现金", openingBalanceCents: 10_000)
        let entry = LedgerEntry(kind: .expense, amountCents: 1_000, accountID: account.id, date: date)
        var data = LedgerData(accounts: [account], entries: [entry])
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 9_000)

        data.entries.removeAll()
        XCTAssertEqual(AccountingEngine.balance(of: account.id, in: data), 10_000)
    }
}
