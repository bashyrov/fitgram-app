import SwiftUI

/// Confirmation screen after a successful barcode lookup. Mirrors the
/// shape of `ScanResultView` but reuses none of its internals because
/// the data model is simpler (single line item, no AI confidence display).
struct BarcodeProductView: View {
    let product: BarcodeProduct
    let onSave: (Double) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void

    @State private var portion: Double = 1.0

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryCard
                        portionCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                footer
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            preview
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.leading, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)
                .accessibilityLabel(Text("Zamknij"))
                Spacer()
            }
        }
        .frame(height: 200)
    }

    @ViewBuilder
    private var preview: some View {
        if let imageURL = product.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackGradient
                }
            }
        } else {
            fallbackGradient
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [Tokens.Palette.primarySoft, Tokens.Palette.surfaceMuted],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Tokens.Palette.primary)
        )
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(product.name)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                if let brand = product.brand {
                    Text(brand)
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text("\(Int(adjustedCalories)) kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)

                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Białko", grams: adjustedProtein, color: Tokens.Palette.primary)
                    macroPill(label: "Węgle", grams: adjustedCarbs, color: Tokens.Palette.warning)
                    macroPill(label: "Tłuszcz", grams: adjustedFat, color: Tokens.Palette.accent)
                }

                Text("Kod \(product.barcode)")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text("\(Int(grams)) g · ×\(String(format: "%.2f", portion))")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Palette.primary)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(title: "Dodaj do dziennika", systemImage: "checkmark") {
                onSave(portion)
            }
            Button(action: onRetake) {
                Text("Skanuj inny kod")
                    .font(Tokens.Font.callout)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, Tokens.Space.xl)
        .padding(.top, Tokens.Space.md)
        .background(Tokens.Palette.background)
    }

    // MARK: - Helpers

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams)) g")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var grams: Double { (product.servingGrams ?? 100) * portion }
    private var adjustedCalories: Double { product.nutrition.caloriesKcalPer100g * grams / 100 }
    private var adjustedProtein: Double { product.nutrition.proteinPer100g * grams / 100 }
    private var adjustedCarbs: Double { product.nutrition.carbsPer100g * grams / 100 }
    private var adjustedFat: Double { product.nutrition.fatPer100g * grams / 100 }
}
