import Foundation

public struct MonthKey: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "month must be between 1 and 12")
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year!, month: parts.month!)
    }

    public var description: String { String(format: "%04d-%02d", year, month) }

    public var displayName: String { "\(year)年\(month)月" }

    public func adding(months offset: Int) -> MonthKey {
        let total = year * 12 + (month - 1) + offset
        return MonthKey(year: total / 12, month: total % 12 + 1)
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        MonthKey(date: date, calendar: calendar) == self
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
