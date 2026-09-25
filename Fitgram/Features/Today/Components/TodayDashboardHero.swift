import SwiftUI

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

    private var ringColor: Color {
        if calorieProgress >= 1.2 { return Tokens.Palette.error }
        if calorieProgress >= 1.0 { return Tokens.Palette.warning }
        return Tokens.Palette.primary
    }

    private var dayIdentity: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: viewingDate)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            topBar
            caloriePanel
            metricsGrid
        }
        .padding(.vertical, Tokens.Space.sm)
        .background(alignment: .topTrailing) {
            Circle()
                .fill(ringColor.opacity(0.10))
                .frame(width: 230, height: 230)
                .scaleEffect(1.12)
                .offset(x: 96, y: 46)
                .allowsHitTesting(false)
        }
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

// MARK: - Sections
extension TodayDashboardHero {
    private var topBar: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(Tokens.Palette.primary)
                    .textCase(.uppercase)
                Text(name)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: Tokens.Space.sm)
            Button {
                isStreakExplanationPresented = true
                Haptics.light()
            } label: {
                Label(
                    String.localizedStringWithFormat(L("%lld"), streakLength),
                    systemImage: streakLength > 0 ? "flame.fill" : "flame"
                )
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(streakLength > 0 ? Tokens.Palette.warning : Tokens.Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Tokens.Palette.surfaceMuted.opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35))
            }
            .buttonStyle(.plain)

            Button(action: onTapProfile) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Tokens.Palette.primary,
                                    Tokens.Palette.accent,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Text(initial)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.onPrimary)
                }
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Tokens.Palette.warmWhite.opacity(0.18),
                                    Tokens.Palette.primary.opacity(0.42),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Tokens.Palette.primary.opacity(0.16), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Profile"))
        }
    }

    private var caloriePanel: some View {
        VStack(spacing: Tokens.Space.lg) {
            dateSelector

            VStack(spacing: Tokens.Space.md) {
                calorieRing
                VStack(spacing: Tokens.Space.xs) {
                    Text(remainingCalories > 0 ? "Pozostało" : "Cel domknięty")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .textCase(.uppercase)
                    Text(remainingCalories > 0 ? "\(remainingCalories)" : "\(Int(consumed))")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(remainingCalories > 0 ? "kcal do celu" : "\(Int(consumed)) / \(calorieGoal) kcal")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(ringColor)
                        .contentTransition(.numericText())

                    if let onTapGoal {
                        Button(action: onTapGoal) {
                            Label("Cel \(calorieGoal) kcal", systemImage: "slider.horizontal.3")
                                .font(Tokens.Font.footnote.weight(.bold))
                                .foregroundStyle(Tokens.Palette.primary)
                                .padding(.horizontal, Tokens.Space.md)
                                .frame(height: 36)
                                .background(Tokens.Palette.primarySoft, in: Capsule())
                                .overlay(Capsule().stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.top, Tokens.Space.xxl)
            .padding(.bottom, Tokens.Space.xl)
            .padding(.horizontal, Tokens.Space.lg)
            .frame(minHeight: 360)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.surface,
                                Tokens.Palette.surfaceMuted,
                                Tokens.Palette.primarySoft,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35)
            )
            .shadow(color: Tokens.Palette.primary.opacity(0.16), radius: 22, y: 12)
        }
    }

    private var dateSelector: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button(action: onPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Tokens.Palette.primary)

            Button(action: onPickDate) {
                HStack(spacing: Tokens.Space.xs) {
                    Image(systemName: "calendar")
                    Text(isViewingToday ? L("Today") : Self.dayLabel(viewingDate))
                }
                .font(Tokens.Font.footnote.weight(.semibold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Tokens.Palette.primarySoft, in: Capsule())
                .overlay(Capsule().stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35))
                .contentTransition(.opacity)
            }
            .buttonStyle(.plain)

            Button(action: onNextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isViewingToday ? Tokens.Palette.inkSubtle : Tokens.Palette.primary)
            .disabled(isViewingToday)
        }
    }

    private var calorieRing: some View {
        ZStack {
            Circle()
                .stroke(Tokens.Palette.primarySoft, lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, calorieProgress)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Tokens.Motion.gentle, value: calorieProgress)
                .shadow(color: ringColor.opacity(ringPulse ? 0.34 : 0.16), radius: ringPulse ? 16 : 8, y: 4)
            Circle()
                .fill(Tokens.Palette.surfaceMuted.opacity(0.72))
                .frame(width: 92, height: 92)
                .overlay {
                    Image(systemName: calorieProgress >= 1 ? "checkmark" : "fork.knife")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(ringColor)
                }
                .overlay(Circle().stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35))
                .scaleEffect(ringPulse ? 1.035 : 1)
        }
        .frame(width: 152, height: 152)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: ringPulse)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Pierścień kalorii"))
        .accessibilityValue(
            Text(
                "\(Int(consumed)) z \(calorieGoal) kilokalorii, \(Int((calorieProgress * 100).rounded())) procent"
            )
        )
    }

    private var metricsGrid: some View {
        VStack(spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                metricTile(
                    title: "Białko",
                    value: "\(Int(protein)) / \(proteinGoal) g",
                    progress: progress(protein, goal: proteinGoal),
                    color: Tokens.Palette.primary
                )
                metricTile(
                    title: "Węgle",
                    value: "\(Int(carbs)) / \(carbsGoal) g",
                    progress: progress(carbs, goal: carbsGoal),
                    color: Tokens.Palette.mutedGreen
                )
                metricTile(
                    title: "Tłuszcz",
                    value: "\(Int(fat)) / \(fatGoal) g",
                    progress: progress(fat, goal: fatGoal),
                    color: Tokens.Palette.warning
                )
            }
            if showsWater {
                waterTile
            }
        }
    }

    private func metricTile(
        title: LocalizedStringKey,
        value: String,
        progress: Double,
        color: Color
    ) -> some View {
        Button(action: onEditMacroGoals) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text(title)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(value)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.14))
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * progress)
                            .animation(Tokens.Motion.gentle, value: progress)
                    }
                }
                .frame(height: 5)
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(progress >= 1 ? 1.01 : 1)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Tokens.Palette.surfaceMuted.opacity(0.88))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35)
            }
        }
        .buttonStyle(.plain)
    }

    private var waterTile: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "drop.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Tokens.Palette.primarySoft))
            VStack(alignment: .leading, spacing: 3) {
                Button(action: onEditWaterGoal) {
                    Text("\(waterTotalMilliliters) / \(waterGoalMilliliters) ml")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.plain)
                Text("Woda")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
            if waterTotalMilliliters > 0 {
                Button(action: onUndoWater) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .accessibilityLabel(Text("Undo last glass"))
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            Button(action: onAddWater) {
                Label("250 ml", systemImage: "plus")
                    .font(Tokens.Font.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.onPrimary)
                    .padding(.horizontal, Tokens.Space.md)
                    .frame(height: 36)
                    .background(Capsule().fill(Tokens.Palette.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Space.md)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.88))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Tokens.Palette.primary.opacity(0.06), lineWidth: 0.35)
        }
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
