import Foundation

public enum EntryKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case transfer
}

public enum CategoryKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
}

public struct LedgerAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var openingBalanceCents: Int64
    public var isActive: Bool

    public init(id: UUID = UUID(), name: String, openingBalanceCents: Int64 = 0, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.openingBalanceCents = openingBalanceCents
        self.isActive = isActive
    }
}

public struct LedgerCategory: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: CategoryKind
    public var sortOrder: Int
    public var isSystem: Bool

    public init(id: UUID = UUID(), name: String, kind: CategoryKind, sortOrder: Int, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }
}

public struct LedgerEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: EntryKind
    public var amountCents: Int64
    public var categoryID: UUID?
    public var accountID: UUID
    public var destinationAccountID: UUID?
    public var date: Date
    public var note: String

    public init(
        id: UUID = UUID(),
        kind: EntryKind,
        amountCents: Int64,
        categoryID: UUID? = nil,
        accountID: UUID,
        destinationAccountID: UUID? = nil,
        date: Date,
        note: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.amountCents = amountCents
        self.categoryID = categoryID
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
        self.date = date
        self.note = note
    }
}

public struct MonthlyBudget: Codable, Equatable, Sendable {
    public var month: MonthKey
    public var amountCents: Int64

    public init(month: MonthKey, amountCents: Int64) {
        self.month = month
        self.amountCents = amountCents
    }
}

public struct LedgerData: Codable, Equatable, Sendable {
    public var accounts: [LedgerAccount]
    public var categories: [LedgerCategory]
    public var entries: [LedgerEntry]
    public var budgets: [MonthlyBudget]

    public init(
        accounts: [LedgerAccount] = [],
        categories: [LedgerCategory] = [],
        entries: [LedgerEntry] = [],
        budgets: [MonthlyBudget] = []
    ) {
        self.accounts = accounts
        self.categories = categories
        self.entries = entries
        self.budgets = budgets
    }
}
