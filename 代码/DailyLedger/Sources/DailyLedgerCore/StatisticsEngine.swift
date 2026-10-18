import Foundation

public struct CategorySpending: Equatable, Sendable, Identifiable {
    public var id: UUID { categoryID }
    public let categoryID: UUID
    public let name: String
    public let amountCents: Int64
    public let fraction: Double
}

public struct MonthlyStatistics: Equatable, Sendable {
    public let month: MonthKey
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let netCents: Int64
    public let previousMonthExpenseCents: Int64
    public let expenseChangeCents: Int64
    public let categorySpending: [CategorySpending]
    public let topCategories: [CategorySpending]
    public let entries: [LedgerEntry]
}

public enum BudgetLevel: String, Equatable, Sendable {
    case notSet
    case comfortable
    case approaching
    case exceeded
}

public struct BudgetSnapshot: Equatable, Sendable {
    public let budgetCents: Int64?
    public let spentCents: Int64
    public let remainingCents: Int64?
    public let remainingDays: Int
    public let level: BudgetLevel
    public let progress: Double
}

public enum StatisticsEngine {
    public static func statistics(
        for month: MonthKey,
        data: LedgerData,
        calendar: Calendar = .current
    ) -> MonthlyStatistics {
        let entries = data.entries
            .filter { month.contains($0.date, calendar: calendar) }
            .sorted { $0.date > $1.date }
        let income = entries.filter { $0.kind == .income }.reduce(Int64(0)) { $0 + $1.amountCents }
        let expense = entries.filter { $0.kind == .expense }.reduce(Int64(0)) { $0 + $1.amountCents }
        let previousMonth = month.adding(months: -1)
        let previousExpense = data.entries
            .filter { $0.kind == .expense && previousMonth.contains($0.date, calendar: calendar) }
            .reduce(Int64(0)) { $0 + $1.amountCents }

        let expenseEntries = entries.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: expenseEntries.compactMap { entry -> (UUID, Int64)? in
            guard let categoryID = entry.categoryID else { return nil }
            return (categoryID, entry.amountCents)
        }, by: { $0.0 })

        let categoryLookup = Dictionary(uniqueKeysWithValues: data.categories.map { ($0.id, $0.name) })
        let spending = grouped.map { categoryID, values in
            let amount = values.reduce(Int64(0)) { $0 + $1.1 }
            return CategorySpending(
                categoryID: categoryID,
                name: categoryLookup[categoryID] ?? "未分类",
                amountCents: amount,
                fraction: expense == 0 ? 0 : Double(amount) / Double(expense)
            )
        }.sorted {
            if $0.amountCents == $1.amountCents { return $0.name < $1.name }
            return $0.amountCents > $1.amountCents
        }

        return MonthlyStatistics(
            month: month,
            incomeCents: income,
            expenseCents: expense,
            netCents: income - expense,
            previousMonthExpenseCents: previousExpense,
            expenseChangeCents: expense - previousExpense,
            categorySpending: spending,
            topCategories: Array(spending.prefix(3)),
            entries: entries
        )
    }

    public static func budgetSnapshot(
        for month: MonthKey,
        data: LedgerData,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> BudgetSnapshot {
        let spent = statistics(for: month, data: data, calendar: calendar).expenseCents
        let budget = data.budgets.first { $0.month == month }?.amountCents
        let days = remainingDays(in: month, from: today, calendar: calendar)

        guard let budget, budget > 0 else {
            return BudgetSnapshot(budgetCents: nil, spentCents: spent, remainingCents: nil, remainingDays: days, level: .notSet, progress: 0)
        }

        let progress = Double(spent) / Double(budget)
        let level: BudgetLevel = progress > 1 ? .exceeded : (progress >= 0.8 ? .approaching : .comfortable)
        return BudgetSnapshot(
            budgetCents: budget,
            spentCents: spent,
            remainingCents: budget - spent,
            remainingDays: days,
            level: level,
            progress: progress
        )
    }

    private static func remainingDays(in month: MonthKey, from today: Date, calendar: Calendar) -> Int {
        let currentMonth = MonthKey(date: today, calendar: calendar)
        if month < currentMonth { return 0 }
        guard let start = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: start) else { return 0 }
        if currentMonth < month { return range.count }
        let day = calendar.component(.day, from: today)
        return max(0, range.count - day)
    }
}
