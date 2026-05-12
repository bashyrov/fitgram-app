import Charts
import SwiftUI

/// History + trend chart for weigh-ins. Reachable from Profile → "Waga".
struct WeightLogView: View {
    let userRemoteID: String
    let initialWeight: Double?
    @Bindable var state: WeightLogState
    let healthImporter: HealthImporter?
    let onDismiss: () -> Void

    @State private var isAddingPresented = false
    @State private var importStatus: String?
    @State private var isImporting = false

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        if let summary = state.summary {
                            summaryCard(summary)
                            chartCard
                        } else {
                            emptyCard
                        }
                        if healthImporter != nil {
                            healthImportCard
                        }
                        entriesCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .refreshable { await state.refresh(for: userRemoteID) }
            }
            .navigationTitle(Text("Waga"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Dodaj wpis wagi"))
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
        }
    }

    private func summaryCard(_ summary: WeightService.Summary) -> some View {
        Card(elevation: Tokens.Shadow.float) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ostatnio")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Text(String(format: "%.1f kg", summary.latest.weightKg))
                        .font(Tokens.Font.counter)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("30 dni")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Text(deltaText(summary.thirtyDayDelta))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(deltaColor(summary.thirtyDayDelta))
                }
            }
        }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Trend")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                if state.entries.count >= 2 {
                    Chart(state.entries.reversed()) { entry in
                        LineMark(
                            x: .value("Data", entry.recordedAt),
                            y: .value("Waga", entry.weightKg)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Tokens.Palette.primary)
                        PointMark(
                            x: .value("Data", entry.recordedAt),
                            y: .value("Waga", entry.weightKg)
                        )
                        .symbolSize(28)
                        .foregroundStyle(Tokens.Palette.primary)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: .dateTime.day().month())
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                            AxisValueLabel()
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                    .frame(height: 180)
                } else {
                    Text("Dodaj jeszcze jeden wpis, żeby zobaczyć trend.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private var healthImportCard: some View {
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                    Text("Apple Health")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Text("Pobierz wpisy wagi zapisane w Apple Health. Importujemy tylko nowe wpisy.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                if let importStatus {
                    Text(importStatus)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Button {
                    Task { await runHealthImport() }
                } label: {
                    HStack(spacing: Tokens.Space.sm) {
                        if isImporting {
                            ProgressView().tint(Tokens.Palette.primary)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isImporting ? "Importuję…" : "Importuj z Apple Health")
                    }
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                }
                .disabled(isImporting)
            }
        }
    }

    private var emptyCard: some View {
        Card {
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Brak wpisów wagi")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Dodaj pierwszy wpis, żeby śledzić trend. Aktualizujemy też wagę w Twoim profilu.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Dodaj wpis", systemImage: "plus") {
                    isAddingPresented = true
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var entriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Historia")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                if state.entries.isEmpty {
                    Text("Pusto. Dodaj pierwszy wpis ↑")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                } else {
                    ForEach(state.entries) { entry in
                        row(entry)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await state.delete(entry, for: userRemoteID) }
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                        if entry.id != state.entries.last?.id {
                            Divider().background(Tokens.Palette.separator)
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: WeightEntry) -> some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f kg", entry.weightKg))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Text(Self.dayFormatter.string(from: entry.recordedAt))
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
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
        case .unavailable: return "Apple Health niedostępne na tym urządzeniu."
        case .denied: return "Brak zgody na dostęp do wagi z Apple Health."
        case .imported(let count): return "Zaimportowano \(count) wpisów."
        case .noNewSamples: return "Brak nowych wpisów."
        case .failed(let reason): return "Nie udało się zaimportować: \(reason)"
        }
    }
}
