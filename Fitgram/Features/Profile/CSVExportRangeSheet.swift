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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: titleText)
                    presetCard
                        .padding(.top, 14)
                    if preset == .custom {
                        customCard
                            .padding(.top, 10)
                    } else {
                        MonoHint(text: presetNote)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MonoBottomBar {
                    MonoButton(title: exportCSVText, kind: .dark, icon: "arrow.down.to.line") {
                        commit()
                    }
                }
            }
            .monoNavigationTitle(titleText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: cancelText, action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: exportText) { commit() }
                }
            }
        }
    }

    /// card: LBL "Co eksportować?" + segmented presets.
    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: whatToExportText)
            MonoSegmented(
                selection: $preset,
                options: [
                    (value: Preset.all, title: allText),
                    (value: Preset.last30, title: last30Text),
                    (value: Preset.last7, title: last7Text),
                    (value: Preset.custom, title: customText),
                ]
            )
        }
        .monoCard(padding: 16)
    }

    /// rows: Od / Do with calendar icon boxes; the compact date picker is the trailing control.
    private var customCard: some View {
        VStack(spacing: 0) {
            MonoRow(icon: "calendar", title: fromText) {
                DatePicker(fromText, selection: $fromDate, in: ...toDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Tokens.Palette.ink)
            }
            MonoRowDivider()
            MonoRow(icon: "calendar", title: toText) {
                DatePicker(toText, selection: $toDate, in: fromDate...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Tokens.Palette.ink)
            }
        }
        .monoRowsCard()
    }

    // MARK: - Copy

    private var presetNote: String {
        switch preset {
        case .all:
            return TL(
                pl: "Wszystkie wpisy.", en: "All entries.", uk: "Усі записи.", ru: "Все записи.",
                es: "Todas las entradas.")
        case .last30:
            return TL(
                pl: "Świetne na miesięczny przegląd.", en: "Great for a monthly review.",
                uk: "Чудово для місячного огляду.", ru: "Отлично для месячного обзора.",
                es: "Ideal para un repaso mensual."
            )
        case .last7:
            return TL(
                pl: "Krótki tydzień.", en: "Short week.", uk: "Короткий тиждень.", ru: "Короткая неделя.",
                es: "Semana corta.")
        case .custom:
            return ""
        }
    }

    private var titleText: String {
        TL(
            pl: "Zakres eksportu", en: "Export range", uk: "Діапазон експорту", ru: "Диапазон экспорта",
            es: "Rango de exportación")
    }

    private var whatToExportText: String {
        TL(
            pl: "Co eksportować?", en: "What to export?", uk: "Що експортувати?", ru: "Что экспортировать?",
            es: "¿Qué exportar?")
    }

    private var allText: String {
        TL(pl: "Wszystko", en: "All", uk: "Усе", ru: "Всё", es: "Todo")
    }

    private var last30Text: String {
        TL(pl: "30 dni", en: "30 days", uk: "30 днів", ru: "30 дней", es: "30 días")
    }

    private var last7Text: String {
        TL(pl: "7 dni", en: "7 days", uk: "7 днів", ru: "7 дней", es: "7 días")
    }

    private var customText: String {
        TL(pl: "Zakres dat", en: "Date range", uk: "Діапазон", ru: "Диапазон", es: "Fechas")
    }

    private var fromText: String {
        TL(pl: "Od", en: "From", uk: "Від", ru: "С", es: "Desde")
    }

    private var toText: String {
        TL(pl: "Do", en: "To", uk: "До", ru: "По", es: "Hasta")
    }

    private var cancelText: String {
        TL(pl: "Anuluj", en: "Cancel", uk: "Скасувати", ru: "Отмена", es: "Cancelar")
    }

    private var exportText: String {
        TL(pl: "Eksportuj", en: "Export", uk: "Експорт", ru: "Экспорт", es: "Exportar")
    }

    private var exportCSVText: String {
        TL(pl: "Eksportuj CSV", en: "Export CSV", uk: "Експортувати CSV", ru: "Экспорт CSV", es: "Exportar CSV")
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
