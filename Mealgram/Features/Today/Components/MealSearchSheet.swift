import SwiftUI

/// "Szukaj posiłku" sheet — global query across the user's meal history.
/// Results group by calendar day, newest first; tapping a row dismisses
/// the sheet and raises the meal-detail sheet for the picked entry.
struct MealSearchSheet: View {
    let service: MealSearchService
    let onSelect: (MealEntry) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var results: [MealEntry] = []

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale.current
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: Tokens.Space.md) {
                    searchField
                    body(for: results)
                }
                .padding(.top, Tokens.Space.md)
            }
            .navigationTitle(Text("Szukaj posiłku"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField(
                "Nazwa składnika lub potrawy",
                text: Binding(
                    get: { query },
                    set: { value in
                        query = value
                        runSearch()
                    }
                )
            )
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    @ViewBuilder
    private func body(for results: [MealEntry]) -> some View {
        if query.isEmpty {
            VStack(spacing: Tokens.Space.md) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                Text("Szukaj wśród wszystkich zapisanych posiłków.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
        } else if results.isEmpty {
            VStack(spacing: Tokens.Space.md) {
                Spacer()
                Text("Nic nie znaleziono dla \"\(query)\".")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    ForEach(grouped(), id: \.0) { day, meals in
                        Text(Self.dayFormatter.string(from: day).capitalized)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                            .padding(.top, Tokens.Space.sm)
                        ForEach(meals) { meal in
                            row(meal)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    private func row(_ meal: MealEntry) -> some View {
        Button {
            onSelect(meal)
        } label: {
            HStack(spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.items.first?.name ?? "Posiłek")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(Self.timeFormatter.string(from: meal.consumedAt))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
                Text("\(Int(meal.totalCaloriesKcal)) kcal")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(Tokens.Palette.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func grouped() -> [(Date, [MealEntry])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: results) { calendar.startOfDay(for: $0.consumedAt) }
        return buckets.sorted { $0.key > $1.key }
    }

    private func runSearch() {
        guard !query.isEmpty else {
            results = []
            return
        }
        results = (try? service.search(query: query)) ?? []
    }
}
