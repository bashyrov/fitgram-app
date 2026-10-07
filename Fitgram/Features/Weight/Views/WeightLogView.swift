import Charts
import SwiftUI

// swiftlint:disable file_length

// swiftlint:disable type_body_length

/// History + trend chart for weigh-ins. Reachable from Profile → "Weight".
struct WeightLogView: View {
    let userRemoteID: String
    let initialWeight: Double?
    var heightCm: Int?
    @Bindable var state: WeightLogState
    let healthImporter: HealthImporter?
    let onDismiss: () -> Void

    @State private var isAddingPresented = false
    @State private var editingEntry: WeightEntry?
    @State private var importStatus: String?
    @State private var isImporting = false
    @State private var isEditingTarget = false
    @State private var targetDraftKg: Double = 70

    @AppStorage("weight.targetKg") private var targetWeightStored: Double = 0

    private static var dayFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter

    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("Weight"))
                        .padding(.bottom, 14)
                    if let summary = state.summary {
                        summaryCard(summary)
                        chartCard
                            .padding(.top, 10)
                    } else {
                        emptyCard
                    }
                    tilesGrid
                        .padding(.top, 10)
                    MonoSectionHeader(title: L("Historia"))
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    entriesCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable { await state.refresh(for: userRemoteID) }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Dodaj wpis"), kind: .dark, icon: "plus") {
                        isAddingPresented = true
                    }
                }
            }
            .monoNavigationTitle(L("Weight"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavIcon(systemName: "plus", accessibilityLabel: L("Add weight entry")) {
                        isAddingPresented = true
                    }
                }
            }
            .task { await state.refresh(for: userRemoteID) }
            .sheet(isPresented: $isAddingPresented) {
                AddWeightSheet(
                    initialWeight: state.entries.first?.weightKg ?? initialWeight,
                    onCommit: { weight, note in
                        Task { await state.log(weight, for: userRemoteID, note: note) }
                    },
                    onDismiss: { isAddingPresented = false }
                )
            }
            .sheet(item: $editingEntry) { entry in
                AddWeightSheet(
                    initialWeight: entry.weightKg,
                    initialNote: entry.note,
                    title: "Edit entry",
                    onCommit: { weight, note in
                        Task {
                            await state.update(
                                entry, weightKg: weight, note: note,
                                for: userRemoteID
                            )
                        }
                    },
                    onDismiss: { editingEntry = nil }
                )
            }
            .alert("Weight goal", isPresented: $isEditingTarget) {
                TextField("kg", value: $targetDraftKg, format: .number)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    targetWeightStored = targetDraftKg
                    Haptics.light()
                }
                if targetWeightStored > 0 {
                    Button("Clear", role: .destructive) {
                        targetWeightStored = 0
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Goal line will appear on the chart.")
            }
            .alert(
                "Nie udało się zapisać zmian",
                isPresented: Binding(
                    get: { state.errorMessage != nil },
                    set: { if !$0 { state.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? L("Couldn't save. Try again."))
            }
        }
    }

    /// Mockup `hero` with three dark stats: latest, 7-day average, weekly trend.
    private func summaryCard(_ summary: WeightService.Summary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MonoStat(
                label: L("Latest"),
                value: String(format: "%.1f", summary.latest.weightKg),
                unit: "kg",
                dark: true
            )
            MonoStat(
                label: L("7-day average"),
                value: summary.sevenDayAverageKg.map { String(format: "%.1f", $0) } ?? "—",
                unit: summary.sevenDayAverageKg == nil ? "" : "kg",
                dark: true
            )
            MonoStat(
                label: L("Trend"),
                value: summary.weeklyRateKg.map { signedValue($0, decimals: 2) } ?? "—",
                unit: summary.weeklyRateKg == nil ? "" : "kg/tyg.",
                dark: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoHero(padding: 18)
    }

    /// "30 DNI · −1.2 KG" header of the trend card.
    private var thirtyDayLabel: String {
        guard let summary = state.summary else { return L("30 days") }
        return L("30 days") + " · " + deltaText(summary.thirtyDayDelta)
    }

    /// Signed number with a typographic minus ("+0.4", "−0.2", "0.0").
    private func signedValue(_ value: Double, decimals: Int = 1) -> String {
        let threshold = decimals >= 2 ? 0.005 : 0.05
        let formatted = String(format: "%.\(decimals)f", abs(value))
        if abs(value) < threshold { return formatted }
        return (value > 0 ? "+" : "−") + formatted
    }

    /// Dynamic x-axis range so a freshly-started log with 2-3 entries
    /// still reads as a chart instead of two points on top of each
    /// other. Spans the earliest entry minus 12h up to the latest entry
    /// plus one full day.
    private var weightChartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let dates = state.entries.map(\.recordedAt)
        guard let earliest = dates.min(), let latest = dates.max() else {
            let today = Date()
            return today...(calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        }
        let lower = calendar.date(byAdding: .hour, value: -12, to: earliest) ?? earliest
        let upper = calendar.date(byAdding: .day, value: 1, to: latest) ?? latest
        return lower...max(upper, calendar.date(byAdding: .day, value: 1, to: lower) ?? upper)
    }

    private func rateText(_ value: Double) -> String {
        if abs(value) < 0.05 { return "≈ stable" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value)) kg/tyg."
    }

    private var chronologicalEntries: [WeightEntry] {
        Array(state.entries.reversed())
    }

    /// Mockup trend card: "30 dni" label + goal on the right, strong line, dashed goal line, hi end dot.
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MonoLabel(text: thirtyDayLabel)
                Spacer(minLength: 8)
                Button {
                    targetDraftKg =
                        targetWeightStored > 0
                        ? targetWeightStored
                        : (state.summary?.latest.weightKg ?? 70)
                    isEditingTarget = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 11, weight: .bold))
                        Text(
                            targetWeightStored > 0
                                ? String(format: "%.1f kg", targetWeightStored)
                                : L("Set")
                        )
                    }
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Weight goal"))
            }
            if state.entries.count >= 2 {
                Chart {
                    if targetWeightStored > 0 {
                        RuleMark(y: .value("Target", targetWeightStored))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    ForEach(chronologicalEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.recordedAt),
                            y: .value("Weight", entry.weightKg)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Tokens.Mono.strong)
                    }
                    if let latest = state.entries.first {
                        PointMark(
                            x: .value("Date", latest.recordedAt),
                            y: .value("Weight", latest.weightKg)
                        )
                        .symbol {
                            Circle()
                                .fill(Tokens.Mono.hi)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Tokens.Mono.strong, lineWidth: 2))
                        }
                    }
                }
                .chartXScale(domain: weightChartXDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month())
                            .font(Tokens.Font.manrope(10, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Tokens.Mono.line)
                        AxisValueLabel()
                            .font(Tokens.Font.manrope(10, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                }
                .frame(height: 140)
            } else {
                Text("Add one more entry to see a trend.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    private var currentBMI: BMI? {
        guard let summary = state.summary else { return nil }
        return bmiSummary(latest: summary.latest.weightKg)
    }

    /// Mockup 2-column grid: BMI tile + Apple Health tile.
    @ViewBuilder
    private var tilesGrid: some View {
        if currentBMI != nil || healthImporter != nil {
            HStack(alignment: .top, spacing: 8) {
                if let bmi = currentBMI {
                    bmiTile(bmi)
                }
                if healthImporter != nil {
                    healthImportTile
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var healthImportTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "Apple Health")
            Text("Pobierz wpisy wagi zapisane w Apple Health. Importujemy tylko nowe wpisy.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let importStatus {
                Text(importStatus)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                Task { await runHealthImport() }
            } label: {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Tokens.Palette.ink)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(isImporting ? "Importing…" : "Importuj z Apple Health")
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .font(Tokens.Font.manrope(13, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monoTile()
    }

    private var emptyCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "scalemass", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("No weight entries")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Dodaj pierwszy wpis, żeby śledzić trend. Aktualizujemy też wagę w Twoim profilu.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    /// Mockup `rows([...], inset=16)`: weight title, date subtitle, muted delta vs. the previous entry.
    @ViewBuilder
    private var entriesCard: some View {
        if state.entries.isEmpty {
            Text("Pusto. Dodaj pierwszy wpis ↑")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .monoRowsCard()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(state.entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        MonoRowDivider(inset: 16)
                    }
                    Button {
                        editingEntry = entry
                    } label: {
                        row(entry, previous: index + 1 < state.entries.count ? state.entries[index + 1] : nil)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            Task { await state.delete(entry, for: userRemoteID) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .monoRowsCard()
        }
    }

    private func row(_ entry: WeightEntry, previous: WeightEntry?) -> some View {
        MonoRow(title: String(format: "%.1f kg", entry.weightKg), sub: rowSubtitle(entry)) {
            if let previous {
                Text(signedValue(entry.weightKg - previous.weightKg))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
    }

    private func rowSubtitle(_ entry: WeightEntry) -> String {
        let date = Self.dayFormatter.string(from: entry.recordedAt)
        guard let note = entry.note, !note.isEmpty else { return date }
        return date + " · " + note
    }

    /// BMI calculation + WHO band label. Returns nil when the user hasn't
    /// recorded a height (e.g., skipped onboarding) — the card simply
    /// hides itself in that case.
    private struct BMI: Equatable {
        let value: Double
        let label: LocalizedStringKey
        let color: Color
    }

    private func bmiSummary(latest weightKg: Double) -> BMI? {
        guard let heightCm, heightCm > 0 else { return nil }
        let meters = Double(heightCm) / 100
        let value = weightKg / (meters * meters)
        let label: LocalizedStringKey
        let color: Color
        switch value {
        case ..<18.5:
            label = "Niedowaga"
            color = Tokens.Palette.warning
        case 18.5..<25:
            label = "Norma"
            color = Tokens.Palette.primary
        case 25..<30:
            label = "Nadwaga"
            color = Tokens.Palette.warning
        default:
            label = "Otyłość"
            color = Tokens.Palette.error
        }
        return BMI(value: value, label: label, color: color)
    }

    private func bmiTile(_ bmi: BMI) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "BMI")
            Text(String(format: "%.1f", bmi.value))
                .font(Tokens.Font.monoNumber(24))
                .foregroundStyle(Tokens.Palette.ink)
            HStack(spacing: 6) {
                Circle()
                    .fill(bmi.color)
                    .frame(width: 7, height: 7)
                Text(bmi.label)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monoTile()
    }

    private func deltaText(_ value: Double) -> String {
        if abs(value) < 0.05 { return "bez zmian" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) kg"
    }

    private func deltaColor(_ value: Double) -> Color {
        if abs(value) < 0.05 { return Tokens.Palette.inkMuted }
        return value > 0 ? Tokens.Palette.warning : Tokens.Palette.success
    }

    private func runHealthImport() async {
        guard let importer = healthImporter, !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        let result = await importer.runImport(for: userRemoteID)
        importStatus = Self.statusMessage(for: result)
        if case .imported = result {
            await state.refresh(for: userRemoteID)
        }
    }

    private static func statusMessage(for result: HealthImporter.ImportResult) -> String {
        switch result {
        case .unavailable: return L("Apple Health is unavailable on this device.")
        case .denied: return L("Apple Health access denied.")
        case .imported(let count): return String.localizedStringWithFormat(L("Imported %lld entries."), count)
        case .noNewSamples: return L("No new entries.")
        case .failed(let reason): return String.localizedStringWithFormat(L("Import failed: %@"), reason)
        }
    }
}

// swiftlint:enable type_body_length
