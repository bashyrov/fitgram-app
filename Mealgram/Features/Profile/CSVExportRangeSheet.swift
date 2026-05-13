import SwiftUI

/// Date-range picker raised before MealCSV export. Three preset chips
/// (Wszystko / 30 dni / 7 dni) handle the 90 % case; custom Od / Do
/// pickers below cover the rest. From/To may be nil — open-ended.
struct CSVExportRangeSheet: View {
    let onExport: (Date?, Date?) -> Void
    let onDismiss: () -> Void

    enum Preset {
        case all
        case last30
        case last7
        case custom
    }

    @State private var preset = Preset.all
    @State private var fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        presetCard
                        if preset == .custom {
                            customCard
                        }
                        PrimaryButton(title: "Eksportuj", systemImage: "tablecells") {
                            commit()
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Zakres eksportu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Anuluj", action: onDismiss)
                }
            }
        }
    }

    private var presetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Co eksportować?")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                presetRow(.all, label: "Cała historia", note: "Wszystkie wpisy.")
                Divider().background(Tokens.Palette.separator)
                presetRow(.last30, label: "Ostatnie 30 dni", note: "Świetne na miesięczny przegląd.")
                Divider().background(Tokens.Palette.separator)
                presetRow(.last7, label: "Ostatnie 7 dni", note: "Krótki tydzień.")
                Divider().background(Tokens.Palette.separator)
                presetRow(.custom, label: "Własny zakres", note: "Wybierz daty Od i Do.")
            }
        }
    }

    private func presetRow(_ option: Preset, label: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        Button {
            preset = option
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: preset == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(preset == option ? Tokens.Palette.primary : Tokens.Palette.inkSubtle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(note)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var customCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Zakres dat")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                DatePicker("Od", selection: $fromDate, in: ...toDate, displayedComponents: .date)
                    .tint(Tokens.Palette.primary)
                DatePicker("Do", selection: $toDate, in: fromDate...Date(), displayedComponents: .date)
                    .tint(Tokens.Palette.primary)
            }
        }
    }

    private func commit() {
        let now = Date()
        let calendar = Calendar.current
        switch preset {
        case .all:
            onExport(nil, nil)
        case .last30:
            let from = calendar.date(byAdding: .day, value: -30, to: now)
            onExport(from, now)
        case .last7:
            let from = calendar.date(byAdding: .day, value: -7, to: now)
            onExport(from, now)
        case .custom:
            onExport(fromDate, toDate)
        }
    }
}
