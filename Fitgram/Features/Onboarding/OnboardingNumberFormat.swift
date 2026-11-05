import Foundation

/// Decimal numbers in onboarding follow the app language ("70,0" in Polish,
/// "70.0" in English), not the device region.
enum OnboardingNumberFormat {
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(1))
                .grouping(.never)
                .locale(Locale(identifier: LocalizationStore.currentLanguageCode()))
        )
    }
}
