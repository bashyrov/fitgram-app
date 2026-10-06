import SwiftUI

/// Top of the Today screen in design D ("Graphite Mono"): greeting row,
/// dark calorie hero with skewed ticks, macro strip and water row.
/// Public API is unchanged — only the visuals moved to `Tokens.Mono`.
struct TodayDashboardHero: View {
    let greeting: LocalizedStringKey
    let displayName: String?
    let streakLength: Int
    let viewingDate: Date
    let isViewingToday: Bool
    let consumed: Double
    let calorieGoal: Int
    let calorieProgress: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int
    let waterTotalMilliliters: Int
    let waterGoalMilliliters: Int
    let showsWater: Bool
    let onTapProfile: () -> Void
    let onPreviousDay: () -> Void
    let onPickDate: () -> Void
    let onNextDay: () -> Void
    let onTapGoal: (() -> Void)?
    let onAddWater: () -> Void
    let onUndoWater: () -> Void
    let onEditWaterGoal: () -> Void
    let onEditMacroGoals: () -> Void

    @State private var isStreakExplanationPresented = false
    @State private var ringPulse = false

    private var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return L("ty")
    }

    private var initial: String {
        if let first = displayName?.first { return String(first).uppercased() }
        return "M"
    }

    private var remainingCalories: Int {
        max(0, calorieGoal - Int(consumed))
    }

    private var isGoalClosed: Bool { remainingCalories == 0 }

    private var ringColor: Color {
        if calorieProgress >= 1.2 { return Tokens.Palette.error }
        if calorieProgress >= 1.0 { return Tokens.Mono.goalDone }
        return Tokens.Mono.hi
    }

    private var dayIdentity: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: viewingDate)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    var body: some View {
        VStack(spacing: 10) {
            topBar
            caloriePanel
            metricsGrid
        }
        .padding(.vertical, Tokens.Space.xs)
        .onChange(of: dayIdentity) { _, _ in
            pulseHero()
        }
        .onChange(of: Int(consumed.rounded())) { _, _ in
            pulseHero()
        }
        .onChange(of: waterTotalMilliliters) { _, _ in
            pulseHero()
        }
        .sheet(isPresented: $isStreakExplanationPresented) {
            StreakExplanationSheet(streakLength: streakLength) {
                isStreakExplanationPresented = false
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Header
extension TodayDashboardHero {
    private var topBar: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.muted)
                Text(name)
                    .font(Tokens.Font.archivo(size: 30, weight: 800, width: 122))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: Tokens.Space.sm)
            Button {
                isStreakExplanationPresented = true
                Haptics.light()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: streakLength > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(streakLength > 0 ? Tokens.Mono.fat : Tokens.Mono.muted)
                    Text(String.localizedStringWithFormat(L("%lld"), streakLength))
                        .font(Tokens.Font.archivo(size: 16, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                .padding(.horizontal, 13)
                .frame(height: 44)
                .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String.localizedStringWithFormat(L("Seria %lld dni"), streakLength)))

            Button(action: onTapProfile) {
                Text(initial)
                    .font(Tokens.Font.archivo(size: 16, weight: 800, width: 110))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Tokens.Mono.hero))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Profile"))
        }
        .padding(.horizontal, Tokens.Space.xs)
    }
}

// MARK: - Calorie hero
extension TodayDashboardHero {
    private var bigNumber: String {
        isGoalClosed ? "\(Int(consumed))" : "\(remainingCalories)"
    }

    /// 3 digits → 96 pt, 4 → 72 pt, 5+ → 58 pt; `minimumScaleFactor` is a last resort.
    private var bigNumberSize: CGFloat {
        switch bigNumber.count {
        case ..<4: return 96
        case 4: return 72
        default: return 58
        }
    }

    private var caloriePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSelector
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel(
                    text: isGoalClosed
                        ? TL(
                            pl: "Cel domknięty", en: "Goal closed", uk: "Ціль закрито", ru: "Цель закрыта",
                            es: "Objetivo cumplido")
                        : TL(pl: "Pozostało", en: "Remaining", uk: "Залишилось", ru: "Осталось", es: "Restante"),
                    onHero: true
                )
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(bigNumber)
                        .font(Tokens.Font.monoNumber(bigNumberSize))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .contentTransition(.numericText())
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    Text(
                        isGoalClosed
                            ? String.localizedStringWithFormat(L("z %lld kcal"), calorieGoal)
                            : TL(
                                pl: "kcal do celu", en: "kcal to goal", uk: "ккал до цілі", ru: "ккал до цели",
                                es: "kcal hasta el objetivo")
                    )
                    .font(Tokens.Font.archivo(size: 15, weight: 700, width: 112))
                    .foregroundStyle(ringColor)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 104, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .scaleEffect(ringPulse ? 1.015 : 1, anchor: .leading)

                MonoTicks(progress: calorieProgress, fill: ringColor)
                    .padding(.top, 16)
                HStack {
                    Text("0")
                    Spacer()
                    Text("\(Int((calorieProgress * 100).rounded()))%")
                    Spacer()
                    Text("\(calorieGoal)")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .padding(.top, 8)

                Rectangle().fill(Tokens.Mono.heroLine).frame(height: 1)
                    .padding(.vertical, 14)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel(
                            text: TL(pl: "Zjedzone", en: "Eaten", uk: "Зʼїдено", ru: "Съедено", es: "Consumido"),
                            onHero: true)
                        Text("\(Int(consumed))")
                            .font(Tokens.Font.archivo(size: 18, weight: 800, width: 112))
                            .foregroundStyle(Tokens.Mono.onHero)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if let onTapGoal {
                        Button(action: onTapGoal) {
                            HStack(spacing: 8) {
                                MonoLabel(
                                    text: TL(pl: "Cel", en: "Goal", uk: "Ціль", ru: "Цель", es: "Meta"), onHero: true)
                                Text("\(calorieGoal)")
                                    .font(Tokens.Font.archivo(size: 15, weight: 800, width: 112))
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Tokens.Mono.onHero)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .overlay(Capsule().stroke(Tokens.Mono.heroLine, lineWidth: 1))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Pierścień kalorii"))
        .accessibilityValue(
            Text("\(Int(consumed)) z \(calorieGoal) kilokalorii, \(Int((calorieProgress * 100).rounded())) procent")
        )
    }

    private var dateSelector: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button(action: onPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Tokens.Mono.heroMuted)
            .accessibilityLabel(
                Text(
                    TL(
                        pl: "Poprzedni dzień", en: "Previous day", uk: "Попередній день", ru: "Предыдущий день",
                        es: "Día anterior")))

            Button(action: onPickDate) {
                HStack(spacing: 8) {
                    Circle().fill(ringColor).frame(width: 6, height: 6)
                    Text(isViewingToday ? L("Today") : Self.dayLabel(viewingDate))
                        .font(Tokens.Font.manrope(11, weight: 800))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Tokens.Mono.onHero)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .contentTransition(.opacity)
            }
            .buttonStyle(.plain)

            Button(action: onNextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isViewingToday ? Tokens.Mono.heroLine : Tokens.Mono.heroMuted)
            .disabled(isViewingToday)
            .accessibilityLabel(
                Text(
                    TL(
                        pl: "Następny dzień", en: "Next day", uk: "Наступний день", ru: "Следующий день",
                        es: "Día siguiente")))
        }
    }
}

// MARK: - Macros + water
extension TodayDashboardHero {
    private var metricsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                macroColumn(title: L("Białko"), value: protein, goal: proteinGoal, color: Tokens.Mono.strong)
                Rectangle().fill(Tokens.Mono.line).frame(width: 1)
                macroColumn(title: L("Węgle"), value: carbs, goal: carbsGoal, color: Tokens.Mono.accent)
                Rectangle().fill(Tokens.Mono.line).frame(width: 1)
                macroColumn(title: L("Tłuszcz"), value: fat, goal: fatGoal, color: Tokens.Mono.fat)
            }
            .fixedSize(horizontal: false, vertical: true)
            .monoCard(padding: nil)

            if showsWater {
                waterTile
            }
        }
    }

    private func macroColumn(title: String, value: Double, goal: Int, color: Color) -> some View {
        Button(action: onEditMacroGoals) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: title)
                Text("\(Int(value))")
                    .font(Tokens.Font.monoNumber(28))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(verbatim: "/ \(goal) \(L("g"))")
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
                MonoBar(progress: progress(value, goal: goal), color: color)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title) \(Int(value)) / \(goal) g"))
    }

    private var waterGlasses: Int {
        guard waterGoalMilliliters > 0 else { return 0 }
        return min(8, Int((Double(waterTotalMilliliters) / Double(waterGoalMilliliters) * 8).rounded(.down)))
    }

    private var waterTile: some View {
        HStack(spacing: Tokens.Space.md) {
            Button(action: onEditWaterGoal) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MonoLabel(text: L("Woda"))
                        Text("\(waterTotalMilliliters)")
                            .font(Tokens.Font.archivo(size: 16, weight: 800, width: 112))
                            .foregroundStyle(Tokens.Palette.ink)
                            + Text(verbatim: " / \(waterGoalMilliliters) \(L("ml"))")
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<8, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(index < waterGlasses ? Tokens.Mono.strong : Tokens.Mono.track)
                                .frame(height: 8)
                                .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.42, d: 1, tx: 1.7, ty: 0))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Woda \(waterTotalMilliliters) / \(waterGoalMilliliters) ml"))

            if waterTotalMilliliters > 0 {
                Button(action: onUndoWater) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Mono.muted)
                .accessibilityLabel(Text("Undo last glass"))
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            Button(action: onAddWater) {
                Text(verbatim: "+250 \(L("ml"))")
                    .font(Tokens.Font.manrope(13, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(Tokens.Mono.hero))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .monoCard(padding: nil)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: waterTotalMilliliters)
    }
}

// MARK: - Helpers
extension TodayDashboardHero {
    private func progress(_ value: Double, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, max(0, value / Double(goal)))
    }

    private func pulseHero() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            ringPulse = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                ringPulse = false
            }
        }
    }

    private static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date).capitalized
    }
}
