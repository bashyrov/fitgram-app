import SwiftUI
import UIKit

/// Scan-a-food-label flow. Step 1 raises the camera picker; step 2
/// runs FoodLabelScanner against the captured photo and shows the
/// parsed nutrition values pre-populated into a CustomFoodFormSheet
/// the user confirms before saving into the catalogue.
struct LabelScannerSheet: View {
    let scanner: FoodLabelScanner
    let onSave: (Food) -> Void
    let onDismiss: () -> Void

    enum Stage: Equatable {
        case capturing
        case scanning
        case confirm(Food, String)
        case failed(String)
    }

    @State private var stage: Stage = .capturing

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            switch stage {
            case .capturing:
                CameraImagePicker(
                    onPicked: { image in run(image: image) },
                    onDismiss: onDismiss
                )
                .ignoresSafeArea()
            case .scanning:
                VStack(spacing: Tokens.Space.md) {
                    ProgressView().tint(Tokens.Palette.primary)
                    Text("Odczytuję etykietę…")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            case .confirm(let prefilled, let raw):
                CustomFoodFormSheet(
                    prefilled: prefilled,
                    rawOCR: raw,
                    onSave: onSave,
                    onDismiss: onDismiss
                )
            case .failed(let message):
                VStack(spacing: Tokens.Space.lg) {
                    Spacer()
                    EmptyState(
                        symbol: "exclamationmark.triangle.fill",
                        title: "Nie udało się odczytać",
                        message: LocalizedStringKey(message),
                        action: .init(title: "Spróbuj ponownie", perform: { stage = .capturing })
                    )
                    Spacer()
                    SecondaryButton(title: "Zamknij", systemImage: "xmark", action: onDismiss)
                        .padding(.horizontal, Tokens.Space.screenPadding)
                        .padding(.bottom, Tokens.Space.xl)
                }
            }
        }
    }

    private func run(image: UIImage) {
        stage = .scanning
        Task {
            do {
                let result = try await scanner.scan(image)
                let prefilled = Food(
                    name: "",
                    category: .packaged,
                    caloriesKcalPer100g: result.parsed.kcalPer100g,
                    proteinGramsPer100g: result.parsed.proteinGramsPer100g,
                    carbsGramsPer100g: result.parsed.carbsGramsPer100g,
                    fatGramsPer100g: result.parsed.fatGramsPer100g,
                    verified: false
                )
                stage = .confirm(prefilled, result.rawText)
            } catch let error as FoodLabelScanner.ScanError {
                let message: String
                switch error {
                case .unsupportedImage:
                    message = String(localized: "Zdjęcie jest nieczytelne. Spróbuj ponownie w lepszym świetle.")
                case .visionFailed(let reason):
                    message = String(localized: "Vision nie odpowiedział: \(reason)")
                case .noNutritionFound:
                    message = String(localized: "Nie znalazłam wartości odżywczych na etykiecie.")
                }
                stage = .failed(message)
            } catch {
                stage = .failed(String(describing: error))
            }
        }
    }
}
