import Foundation

public enum AccountingEngine {
    public static func balances(for data: LedgerData) -> [UUID: Int64] {
        var result = Dictionary(uniqueKeysWithValues: data.accounts.map { ($0.id, $0.openingBalanceCents) })

        for entry in data.entries {
            switch entry.kind {
            case .expense:
                result[entry.accountID, default: 0] -= entry.amountCents
            case .income:
                result[entry.accountID, default: 0] += entry.amountCents
            case .transfer:
                result[entry.accountID, default: 0] -= entry.amountCents
                if let destinationID = entry.destinationAccountID {
                    result[destinationID, default: 0] += entry.amountCents
                }
            }
        }

        return result
    }

    public static func balance(of accountID: UUID, in data: LedgerData) -> Int64 {
        balances(for: data)[accountID] ?? 0
    }

    public static func totalBalance(in data: LedgerData) -> Int64 {
        data.accounts.reduce(0) { $0 + balance(of: $1.id, in: data) }
    }
}
