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
    @State private var capturedImage: UIImage?

    var body: some View {
        switch stage {
        case .capturing:
            CameraImagePicker(
                onPicked: { image in run(image: image) },
                onDismiss: onDismiss
            )
            .ignoresSafeArea()
        case .confirm(let prefilled, let raw):
            CustomFoodFormSheet(
                prefilled: prefilled,
                rawOCR: raw,
                onSave: onSave,
                onDismiss: onDismiss
            )
        case .scanning:
            statusScreen { scanningCard }
        case .failed(let message):
            statusScreen { failedCard(message) }
        }
    }

    /// `nav('Skan etykiety', 'Zamknij')` + label photo (300 pt) + one state card.
    private func statusScreen<CardContent: View>(@ViewBuilder card: () -> CardContent) -> some View {
        let content = card()
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    labelPhoto
                    content
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(
                TL(
                    pl: "Skan etykiety", en: "Label scan", uk: "Скан етикетки", ru: "Скан этикетки",
                    es: "Escaneo de etiqueta")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
        }
    }

    /// The captured photo when we have it, otherwise the striped placeholder.
    @ViewBuilder
    private var labelPhoto: some View {
        if let capturedImage {
            Color.clear
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Tokens.Mono.line, lineWidth: 1)
                )
                .accessibilityHidden(true)
        } else {
            MonoImagePlaceholder(
                height: 300,
                label: TL(
                    pl: "Zdjęcie etykiety", en: "Label photo", uk: "Фото етикетки", ru: "Фото этикетки",
                    es: "Foto de la etiqueta"
                )
            )
        }
    }

    private var scanningCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "doc.text", style: .dark, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("Odczytuję etykietę…")
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Tekst rozpoznawany lokalnie na telefonie.",
                        en: "Text is recognised locally on your phone.",
                        uk: "Текст розпізнається локально на телефоні.", ru: "Текст распознаётся локально на телефоне.",
                        es: "El texto se reconoce localmente en tu teléfono."
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ProgressView()
                .tint(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
    }

    private func failedCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "exclamationmark.triangle", style: .track, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Nie udało się odczytać")
                        .font(Tokens.Font.manrope(16, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(message)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                MonoButton(title: L("Try again"), kind: .dark, icon: "arrow.clockwise", height: 44) {
                    stage = .capturing
                }
                MonoButton(title: L("Close"), kind: .outline, height: 44, action: onDismiss)
            }
        }
        .monoCard(padding: 16)
    }

    private func run(image: UIImage) {
        capturedImage = image
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
                    message = L("The photo is unreadable. Try again in better light.")
                case .visionFailed(let reason):
                    message = String.localizedStringWithFormat(L("Vision didn't respond: %@"), reason)
                case .noNutritionFound:
                    message = L("I couldn't find nutrition values on the label.")
                }
                stage = .failed(message)
            } catch {
                stage = .failed(String(describing: error))
            }
        }
    }
}
