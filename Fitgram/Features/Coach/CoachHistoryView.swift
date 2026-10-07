import SwiftUI

/// "Historia Oli" — chronological feed of every weekly debrief the user
/// has seen. Newest first. Tapping a row expands to show the headline
/// stats + the rule-engine insights that fired that week.
struct CoachHistoryView: View {
    let logs: [CoachInsightLog]
    let decode: (CoachInsightLog) -> [CoachInsight]
    let onDismiss: () -> Void

    @State private var expandedID: UUID?
    @State private var filter = Filter.all

    enum Filter: Hashable {
        case all
        case helpful
        case unhelpful

        var label: LocalizedStringKey {
            switch self {
            case .all: return LocalizedStringKey(L("All"))
            case .helpful: return LocalizedStringKey("👍 \(L("Helpful"))")
            case .unhelpful: return LocalizedStringKey("👎 \(L("Not helpful"))")
            }
        }
    }

    private var visibleLogs: [CoachInsightLog] {
        switch filter {
        case .all: return logs
        case .helpful: return logs.filter { $0.helpful == true }
        case .unhelpful: return logs.filter { $0.helpful == false }
        }
    }

    private static var weekFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM"
        return formatter

    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: L("Ola history"),
                        sub: logs.isEmpty
                            ? nil
                            : TL(
                                pl: "Wszystkie tygodniowe podsumowania w jednym miejscu.",
                                en: "All weekly summaries in one place.",
                                uk: "Усі тижневі підсумки в одному місці.",
                                ru: "Все недельные итоги в одном месте.",
                                es: "Todos los resúmenes semanales en un solo lugar.")
                    )
                    if logs.isEmpty {
                        empty
                            .padding(.top, 30)
                    } else {
                        filterChips
                            .padding(.top, 14)
                        VStack(spacing: 8) {
                            if visibleLogs.isEmpty {
                                Text(L("No entries match this filter."))
                                    .font(Tokens.Font.manrope(13, weight: 600))
                                    .foregroundStyle(Tokens.Mono.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Tokens.Space.lg)
                            }
                            ForEach(visibleLogs) { log in
                                row(log)
                            }
                        }
                        .padding(.top, 14)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Ola history"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach([Filter.all, .helpful, .unhelpful], id: \.self) { option in
                    MonoChip(title: chipTitle(option), isSelected: filter == option) {
                        Haptics.selection()
                        filter = option
                    }
                }
            }
        }
    }

    private func chipTitle(_ option: Filter) -> String {
        switch option {
        case .all: return L("All")
        case .helpful: return L("Helpful")
        case .unhelpful: return L("Not helpful")
        }
    }

    /// Week card (mockup `wkcard`): range label + "helpful" badge, 17/800 headline and a
    /// "show details" toggle that expands the week's insights inline.
    private func row(_ log: CoachInsightLog) -> some View {
        let isExpanded = expandedID == log.id
        let insights = isExpanded ? decode(log) : []
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(Tokens.Motion.gentle) {
                    expandedID = isExpanded ? nil : log.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 8) {
                        MonoLabel(text: rangeCaption(for: log.weekStartAt))
                        Spacer(minLength: 0)
                        if let helpful = log.helpful {
                            helpfulBadge(helpful)
                        }
                    }
                    Text(log.headline)
                        .font(Tokens.Font.manrope(17, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(
                            isExpanded
                                ? TL(
                                    pl: "Ukryj szczegóły", en: "Hide details", uk: "Сховати деталі",
                                    ru: "Скрыть детали",
                                    es: "Ocultar detalles")
                                : TL(
                                    pl: "Pokaż szczegóły", en: "Show details", uk: "Показати деталі",
                                    ru: "Показать детали", es: "Ver detalles")
                        )
                        .font(Tokens.Font.manrope(13, weight: 800))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Tokens.Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                Rectangle().fill(Tokens.Mono.line).frame(height: 1)
                ForEach(insights) { insight in
                    insightRow(insight)
                }
            }
        }
        .monoCard(padding: 16)
    }

    private func helpfulBadge(_ helpful: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: helpful ? "hand.thumbsup" : "hand.thumbsdown")
                .font(.system(size: 10, weight: .bold))
            Text(helpful ? L("Helpful") : L("Not helpful"))
                .font(Tokens.Font.manrope(11, weight: 800))
        }
        .foregroundStyle(Tokens.Palette.ink)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Capsule().fill(Tokens.Mono.track))
    }

    private func insightRow(_ insight: CoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(insight.headline)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(insight.body)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            MonoIconBox(systemName: "clock.arrow.circlepath", style: .track, size: 44)
            Text(L("No history yet"))
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(L("After the first weekly summary, all Ola entries will appear here."))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private func rangeCaption(for weekStart: Date) -> String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return Self.weekFormatter.string(from: weekStart)
        }
        return "\(Self.weekFormatter.string(from: weekStart)) – \(Self.weekFormatter.string(from: weekEnd))"
    }
}
