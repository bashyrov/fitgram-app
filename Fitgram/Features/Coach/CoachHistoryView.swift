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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        if logs.isEmpty {
                            empty
                        } else {
                            filterChips
                            if visibleLogs.isEmpty {
                                Text(L("No entries match this filter."))
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                    .padding(.vertical, Tokens.Space.lg)
                            }
                            ForEach(visibleLogs) { log in
                                row(log)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("Ola history")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Close"), action: onDismiss)
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach([Filter.all, .helpful, .unhelpful], id: \.self) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.label)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(filter == option ? .white : Tokens.Palette.ink)
                            .padding(.horizontal, Tokens.Space.md)
                            .padding(.vertical, Tokens.Space.sm)
                            .background(
                                Capsule().fill(
                                    filter == option ? Tokens.Palette.primary : Tokens.Palette.surface
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    filter == option ? Tokens.Palette.primary : Tokens.Palette.separator,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ log: CoachInsightLog) -> some View {
        let isExpanded = expandedID == log.id
        let insights = isExpanded ? decode(log) : []
        return Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Button {
                    expandedID = isExpanded ? nil : log.id
                } label: {
                    HStack(alignment: .top, spacing: Tokens.Space.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.headline)
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(rangeCaption(for: log.weekStartAt))
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                }
                .buttonStyle(.plain)
                if isExpanded {
                    Divider().background(Tokens.Palette.separator)
                    ForEach(insights) { insight in
                        insightRow(insight)
                    }
                }
            }
        }
    }

    private func insightRow(_ insight: CoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(insight.headline)
                .font(Tokens.Font.footnote.bold())
                .foregroundStyle(Tokens.Palette.primary)
            Text(insight.body)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(L("No history yet"))
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Text(L("After the first weekly summary, all Ola entries will appear here."))
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Tokens.Space.xxxl)
    }

    private func rangeCaption(for weekStart: Date) -> String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return Self.weekFormatter.string(from: weekStart)
        }
        return "\(Self.weekFormatter.string(from: weekStart)) – \(Self.weekFormatter.string(from: weekEnd))"
    }
}
