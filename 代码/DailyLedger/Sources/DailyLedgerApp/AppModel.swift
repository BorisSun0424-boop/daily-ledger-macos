import Foundation
import SwiftUI
import DailyLedgerCore

@MainActor
final class AppModel: ObservableObject {
    enum Page: String, CaseIterable, Identifiable {
        case overview = "月度概览"
        case entries = "账目明细"
        case accounts = "账户"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: "chart.bar.xaxis"
            case .entries: "list.bullet.rectangle"
            case .accounts: "wallet.bifold"
            }
        }
    }

    @Published private(set) var data: LedgerData = LedgerDefaults.emptyData()
    @Published var selection: Page = .overview
    @Published var selectedMonth = MonthKey(date: Date())
    @Published var showNewEntry = false
    @Published var showOnboarding = false
    @Published var errorMessage: String?
    @Published private(set) var isReadOnly = false

    private var service: LedgerService?

    init(repository: LocalLedgerRepository? = nil) {
        do {
            let resolved = try repository ?? .applicationSupport()
            let loaded = try LedgerService(repository: resolved)
            service = loaded
            data = loaded.data
            showOnboarding = loaded.data.accounts.isEmpty
        } catch {
            isReadOnly = true
            errorMessage = error.localizedDescription
        }
    }

    var statistics: MonthlyStatistics {
        StatisticsEngine.statistics(for: selectedMonth, data: data)
    }

    var budgetSnapshot: BudgetSnapshot {
        StatisticsEngine.budgetSnapshot(for: selectedMonth, data: data)
    }

    var balances: [UUID: Int64] { AccountingEngine.balances(for: data) }
    var totalBalance: Int64 { AccountingEngine.totalBalance(in: data) }

    func moveMonth(_ offset: Int) { selectedMonth = selectedMonth.adding(months: offset) }

    func addAccount(name: String, openingBalanceCents: Int64) -> Bool {
        perform { try $0.addAccount(name: name, openingBalanceCents: openingBalanceCents) }
    }

    func updateAccount(_ account: LedgerAccount) -> Bool {
        perform { try $0.updateAccount(account) }
    }

    func saveEntry(_ entry: LedgerEntry, isEditing: Bool) -> Bool {
        perform { service in
            if isEditing { try service.updateEntry(entry) }
            else { try service.addEntry(entry) }
        }
    }

    func deleteEntry(_ entry: LedgerEntry) -> Bool {
        perform { try $0.deleteEntry(id: entry.id) }
    }

    func setBudget(_ cents: Int64?) -> Bool {
        perform { try $0.setBudget(month: selectedMonth, amountCents: cents) }
    }

    func addCategory(name: String, kind: CategoryKind) -> Bool {
        perform { try $0.addCategory(name: name, kind: kind) }
    }

    func renameCategory(_ category: LedgerCategory, name: String) -> Bool {
        perform { try $0.renameCategory(id: category.id, name: name) }
    }

    func deleteCategory(_ category: LedgerCategory) -> Bool {
        perform { try $0.deleteCategory(id: category.id) }
    }

    func migrateAndDeleteCategory(_ category: LedgerCategory, to destination: LedgerCategory) -> Bool {
        perform { try $0.migrateAndDeleteCategory(from: category.id, to: destination.id) }
    }

    func finishOnboarding(accountName: String, openingBalanceCents: Int64, budgetCents: Int64?) -> Bool {
        guard addAccount(name: accountName, openingBalanceCents: openingBalanceCents) else { return false }
        if let budgetCents, !setBudget(budgetCents) { return false }
        showOnboarding = false
        return true
    }

    @discardableResult
    private func perform(_ work: (inout LedgerService) throws -> Void) -> Bool {
        guard var current = service, !isReadOnly else { return false }
        do {
            try work(&current)
            service = current
            data = current.data
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
