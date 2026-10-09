import SwiftUI

/// Pick a logged day (whole day or one meal) to attach to a post.
struct PostMacroPickerSheet: View {
    let calorieGoalKcal: Int?
    let onPick: (PostMacroSnapshot) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var day = Date()
    @State private var meals: [MealEntry] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        TL(pl: "Dzień", en: "Day", uk: "День", ru: "День", es: "Día"),
                        selection: $day,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Tokens.Mono.strong)
                    .monoCard(padding: 12)
                    if meals.isEmpty {
                        MonoHint(
                            text: TL(
                                pl: "Tego dnia nic nie zapisano. Wybierz inny dzień.",
                                en: "Nothing was logged that day. Pick another day.",
                                uk: "Цього дня нічого не записано. Обери інший день.",
                                ru: "В этот день ничего не записано. Выбери другой день.",
                                es: "Ese día no se registró nada. Elige otro día."))
                    } else {
                        if let whole = PostMacroBuilder.day(meals, goalKcal: calorieGoalKcal) {
                            option(
                                title: TL(
                                    pl: "Cały dzień", en: "Whole day", uk: "Весь день", ru: "Весь день",
                                    es: "Día completo"),
                                snapshot: whole)
                        }
                        ForEach(meals, id: \.id) { meal in
                            option(
                                title: PostMacroBuilder.mealLabel(meal.mealType) + " · "
                                    + meal.consumedAt.formatted(.dateTime.hour().minute()),
                                snapshot: PostMacroBuilder.meal(meal, goalKcal: calorieGoalKcal))
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(
                TL(
                    pl: "Makro do posta", en: "Macros for the post", uk: "Макро для поста",
                    ru: "Макро для поста", es: "Macros para la publicación")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Zamknij"), action: onDismiss)
                }
            }
            .onAppear { reload() }
            .onChange(of: day) { _, _ in reload() }
        }
    }

    private func option(title: String, snapshot: PostMacroSnapshot) -> some View {
        Button {
            Haptics.selection()
            onPick(snapshot)
        } label: {
            MonoRow(
                icon: snapshot.scope == .day ? "calendar" : "fork.knife",
                iconStyle: snapshot.scope == .day ? .dark : .track,
                title: title,
                sub: Self.summary(snapshot)
            ) {
                MonoChevron()
            }
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    private func reload() {
        meals = PostMacroBuilder.meals(on: day, in: modelContext)
    }

    /// "1535 kcal · B 79 g · W 159 g · T 63 g" in the app language.
    static func summary(_ snapshot: PostMacroSnapshot) -> String {
        let letters = TL(pl: "B W T", en: "P C F", uk: "Б В Ж", ru: "Б У Ж", es: "P C G").split(separator: " ")
        let kcal = TL(pl: "kcal", en: "kcal", uk: "ккал", ru: "ккал", es: "kcal")
        let grams = TL(pl: "g", en: "g", uk: "г", ru: "г", es: "g")
        let values = [snapshot.proteinG, snapshot.carbsG, snapshot.fatG]
        let macros = zip(letters, values).map { "\($0) \($1) \(grams)" }
        return (["\(snapshot.kcal) \(kcal)"] + macros).joined(separator: " · ")
    }
}
