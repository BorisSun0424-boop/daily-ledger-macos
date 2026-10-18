import Foundation

public enum LedgerValidationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidAmount
    case accountNotFound
    case inactiveAccount
    case categoryNotFound
    case categoryKindMismatch
    case destinationAccountRequired
    case sameTransferAccount
    case entryNotFound
    case categoryInUse

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "名称不能为空。"
        case .invalidAmount: return "金额必须大于零。"
        case .accountNotFound: return "没有找到所选账户。"
        case .inactiveAccount: return "已停用的账户不能用于新增账目。"
        case .categoryNotFound: return "没有找到所选分类。"
        case .categoryKindMismatch: return "分类与收支类型不匹配。"
        case .destinationAccountRequired: return "转账需要选择转入账户。"
        case .sameTransferAccount: return "转出和转入账户不能相同。"
        case .entryNotFound: return "没有找到这笔账目。"
        case .categoryInUse: return "该分类已有历史账目，请先迁移后再删除。"
        }
    }
}

public struct LedgerService {
    public private(set) var data: LedgerData
    public let repository: LocalLedgerRepository

    public init(repository: LocalLedgerRepository) throws {
        self.repository = repository
        self.data = try repository.load()
    }

    public var activeAccounts: [LedgerAccount] {
        data.accounts.filter(\.isActive)
    }

    @discardableResult
    public mutating func addAccount(name: String, openingBalanceCents: Int64) throws -> LedgerAccount {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw LedgerValidationError.emptyName }
        let account = LedgerAccount(name: cleanName, openingBalanceCents: openingBalanceCents)
        try commit { $0.accounts.append(account) }
        return account
    }

    public mutating func updateAccount(_ account: LedgerAccount) throws {
        let cleanName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw LedgerValidationError.emptyName }
        guard let index = data.accounts.firstIndex(where: { $0.id == account.id }) else {
            throw LedgerValidationError.accountNotFound
        }
        var updated = account
        updated.name = cleanName
        try commit { $0.accounts[index] = updated }
    }

    @discardableResult
    public mutating func addCategory(name: String, kind: CategoryKind) throws -> LedgerCategory {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw LedgerValidationError.emptyName }
        let nextOrder = (data.categories.filter { $0.kind == kind }.map(\.sortOrder).max() ?? -1) + 1
        let category = LedgerCategory(name: cleanName, kind: kind, sortOrder: nextOrder)
        try commit { $0.categories.append(category) }
        return category
    }

    public mutating func renameCategory(id: UUID, name: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw LedgerValidationError.emptyName }
        guard let index = data.categories.firstIndex(where: { $0.id == id }) else {
            throw LedgerValidationError.categoryNotFound
        }
        try commit { $0.categories[index].name = cleanName }
    }

    public mutating func deleteCategory(id: UUID) throws {
        guard data.categories.contains(where: { $0.id == id }) else { throw LedgerValidationError.categoryNotFound }
        guard !data.entries.contains(where: { $0.categoryID == id }) else { throw LedgerValidationError.categoryInUse }
        try commit { $0.categories.removeAll { $0.id == id } }
    }

    public mutating func migrateAndDeleteCategory(from sourceID: UUID, to destinationID: UUID) throws {
        guard let source = data.categories.first(where: { $0.id == sourceID }),
              let destination = data.categories.first(where: { $0.id == destinationID }) else {
            throw LedgerValidationError.categoryNotFound
        }
        guard source.kind == destination.kind else { throw LedgerValidationError.categoryKindMismatch }
        try commit { draft in
            for index in draft.entries.indices where draft.entries[index].categoryID == sourceID {
                draft.entries[index].categoryID = destinationID
            }
            draft.categories.removeAll { $0.id == sourceID }
        }
    }

    @discardableResult
    public mutating func addEntry(_ entry: LedgerEntry) throws -> LedgerEntry {
        try validate(entry, in: data)
        try commit { $0.entries.append(entry) }
        return entry
    }

    public mutating func updateEntry(_ entry: LedgerEntry) throws {
        guard let index = data.entries.firstIndex(where: { $0.id == entry.id }) else {
            throw LedgerValidationError.entryNotFound
        }
        try validate(entry, in: data, allowInactiveReferencedAccounts: true)
        try commit { $0.entries[index] = entry }
    }

    public mutating func deleteEntry(id: UUID) throws {
        guard data.entries.contains(where: { $0.id == id }) else { throw LedgerValidationError.entryNotFound }
        try commit { $0.entries.removeAll { $0.id == id } }
    }

    public mutating func setBudget(month: MonthKey, amountCents: Int64?) throws {
        if let amountCents, amountCents <= 0 { throw LedgerValidationError.invalidAmount }
        try commit { draft in
            draft.budgets.removeAll { $0.month == month }
            if let amountCents {
                draft.budgets.append(MonthlyBudget(month: month, amountCents: amountCents))
            }
        }
    }

    private func validate(
        _ entry: LedgerEntry,
        in data: LedgerData,
        allowInactiveReferencedAccounts: Bool = false
    ) throws {
        guard entry.amountCents > 0 else { throw LedgerValidationError.invalidAmount }
        guard let account = data.accounts.first(where: { $0.id == entry.accountID }) else {
            throw LedgerValidationError.accountNotFound
        }
        if !allowInactiveReferencedAccounts && !account.isActive { throw LedgerValidationError.inactiveAccount }

        switch entry.kind {
        case .expense, .income:
            guard let categoryID = entry.categoryID,
                  let category = data.categories.first(where: { $0.id == categoryID }) else {
                throw LedgerValidationError.categoryNotFound
            }
            let expected: CategoryKind = entry.kind == .expense ? .expense : .income
            guard category.kind == expected else { throw LedgerValidationError.categoryKindMismatch }
        case .transfer:
            guard let destinationID = entry.destinationAccountID,
                  let destination = data.accounts.first(where: { $0.id == destinationID }) else {
                throw LedgerValidationError.destinationAccountRequired
            }
            guard destinationID != entry.accountID else { throw LedgerValidationError.sameTransferAccount }
            if !allowInactiveReferencedAccounts && !destination.isActive { throw LedgerValidationError.inactiveAccount }
        }
    }

    private mutating func commit(_ mutation: (inout LedgerData) -> Void) throws {
        var draft = data
        mutation(&draft)
        try repository.save(draft)
        data = draft
    }
}
