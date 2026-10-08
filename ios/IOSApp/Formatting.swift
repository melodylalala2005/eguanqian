import Foundation

enum FinanceFormatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.multiplier = 100
        return formatter
    }()
}

enum FinanceTrendDirection {
    case up
    case down
    case flat
}

extension Decimal {
    func formattedCurrency() -> String {
        FinanceFormatters.currency.string(from: NSDecimalNumber(decimal: self)) ?? description
    }

    func formattedNumber() -> String {
        FinanceFormatters.decimal.string(from: NSDecimalNumber(decimal: self)) ?? description
    }

    func formattedPercentage() -> String {
        FinanceFormatters.percentage.string(from: NSDecimalNumber(decimal: self)) ?? description
    }

    var asDouble: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

