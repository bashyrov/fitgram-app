import SwiftUI

/// Detected items + portion adjustment + save. Items can be tapped to
/// edit, swiped to delete, or added manually via the footer. The portion
/// slider scales totals globally.
struct ScanResultView: View {
    let initialResult: ScanResult
    let imageData: Data?
    let onSave: (ScanResult, Double) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void

    @State private var result: ScanResult
    @State private var portion: Double = 1.0
    @State private var editorMode: FoodItemEditorSheet.Mode?

    init(
        result: ScanResult,
        imageData: Data?,
        onSave: @escaping (ScanResult, Double) -> Void,
        onRetake: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialResult = result
        self.imageData = imageData
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDismiss = onDismiss
        self._result = State(initialValue: result)
    }

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryCard
                        portionCard
                        itemsCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                footer
            }
        }
        .sheet(item: $editorMode) { mode in
            FoodItemEditorSheet(
                mode: mode,
                onCommit: { item in apply(edited: item, mode: mode) },
                onDismiss: { editorMode = nil }
            )
        }
    }

    private func apply(edited item: ScanResult.DetectedItem, mode: FoodItemEditorSheet.Mode) {
        switch mode {
        case .adding:
            result.items.append(item)
        case .editing(let original):
            if let index = result.items.firstIndex(where: { $0.id == original.id }) {
                result.items[index] = item
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

    private var preview: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Tokens.Palette.primarySoft, Tokens.Palette.surfaceMuted],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mealTypeLabel(for: result.suggestedMealType))
                            .font(Tokens.Font.subheadline)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text("\(Int(adjustedCalories)) kcal")
                            .font(Tokens.Font.counter)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    Spacer()
                    confidenceBadge
                }
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Białko", grams: adjustedProtein, color: Tokens.Palette.primary)
                    macroPill(label: "Węgle", grams: adjustedCarbs, color: Tokens.Palette.warning)
                    macroPill(label: "Tłuszcz", grams: adjustedFat, color: Tokens.Palette.accent)
                }
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
                    Text(String(format: "×%.2f", portion))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Palette.primary)
                HStack {
                    Text("Mniej")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("Pełna")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("Większa")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
    }

    private var itemsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text("Co widzimy")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text("\(result.items.count) elementów")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                ForEach(result.items) { item in
                    itemRow(item)
                        .contentShape(Rectangle())
                        .onTapGesture { editorMode = .editing(item) }
                        .contextMenu {
                            Button {
                                editorMode = .editing(item)
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                result.items.removeAll(where: { $0.id == item.id })
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                        }
                }
                Button {
                    editorMode = .adding
                } label: {
                    HStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Dodaj składnik ręcznie")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Tokens.Space.sm)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scan.results.addItem")
            }
        }
    }

    private func itemRow(_ item: ScanResult.DetectedItem) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("\(Int(item.quantityGrams)) g")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(item.caloriesKcal * portion)) kcal")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var confidenceBadge: some View {
        let pct = Int(result.confidence * 100)
        return Text("\(pct)% pewności")
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Tokens.Palette.primarySoft)
            )
    }

    private var footer: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(title: "Dodaj do dziennika", systemImage: "checkmark") {
                onSave(result, portion)
            }
            Button(action: onRetake) {
                Text("Zrób jeszcze raz")
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

    private func mealTypeLabel(for kind: MealType) -> LocalizedStringKey {
        switch kind {
        case .breakfast: return "Śniadanie"
        case .lunch: return "Obiad"
        case .dinner: return "Kolacja"
        case .snack: return "Przekąska"
        }
    }

    private var adjustedCalories: Double { result.totalCalories * portion }
    private var adjustedProtein: Double { result.totalProtein * portion }
    private var adjustedCarbs: Double { result.totalCarbs * portion }
    private var adjustedFat: Double { result.totalFat * portion }
}
