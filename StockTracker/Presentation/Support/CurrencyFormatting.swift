import Foundation

enum CurrencyFormatting {
    static func currencyString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        decimal.formatted(.currency(code: "USD").precision(.fractionLength(2)).locale(locale))
    }

    static func signedCurrencyString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        decimal.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(2))
                .sign(strategy: .always(showZero: false))
                .locale(locale)
        )
    }

    /// Domain percentages are percentage points (12.5 means 12.5%, rather than 1,250%).
    static func signedPercentString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        (decimal / 100).formatted(
            .percent.precision(.fractionLength(2))
                .sign(strategy: .always(includingZero: false))
                .locale(locale)
        )
    }
}
