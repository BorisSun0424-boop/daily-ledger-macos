import Foundation

public enum LedgerDefaults {
    public static let expenseCategoryNames = ["餐饮", "交通", "购物", "居住", "娱乐", "医疗", "学习", "人情", "其他"]
    public static let incomeCategoryNames = ["工资", "兼职", "理财", "红包", "其他"]

    public static func categories() -> [LedgerCategory] {
        let expenses = expenseCategoryNames.enumerated().map {
            LedgerCategory(name: $0.element, kind: .expense, sortOrder: $0.offset, isSystem: true)
        }
        let incomes = incomeCategoryNames.enumerated().map {
            LedgerCategory(name: $0.element, kind: .income, sortOrder: $0.offset, isSystem: true)
        }
        return expenses + incomes
    }

    public static func emptyData() -> LedgerData {
        LedgerData(categories: categories())
    }
}
