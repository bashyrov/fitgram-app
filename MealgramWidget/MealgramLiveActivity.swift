import ActivityKit
import SwiftUI
import WidgetKit

/// "Mealgram — Today" Live Activity. Renders the same calorie + macro
/// snapshot shown on the home-screen widget, but in two ActivityKit
/// surfaces: the Lock Screen card and the Dynamic Island.
///
/// Layouts (per brief):
/// - Lock Screen: big calorie ring on the left, big kcal number center,
///   "/ goal" under it, three thin macro bars on the right (P/C/F),
///   bottom row with today's date + a small "Mealgram" mark, all sat
///   on a subtle lime → cream gradient.
/// - Dynamic Island compact leading: lime ring with kcal remaining.
/// - Dynamic Island compact trailing: small "g" badge with protein.
/// - Dynamic Island expanded: full ring + macro bars + a "+1 szklanka"
///   button (deep-link `mealgram://add-water` — ActivityKit forbids
///   mutating data directly from an activity view).
/// - Dynamic Island minimal: just the lime ring.
struct MealgramLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealgramActivityAttributes.self) { context in
            MealgramLockScreenView(state: context.state)
                .activityBackgroundTint(Color("BrandBackground"))
                .activitySystemActionForegroundColor(Color("BrandInk"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandRingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandMacroBars(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandWaterButton()
                }
            } compactLeading: {
                CompactRing(state: context.state)
            } compactTrailing: {
                CompactProteinBadge(state: context.state)
            } minimal: {
                MinimalRing(state: context.state)
            }
            .widgetURL(MealgramActivityDeepLink.addWater)
            .keylineTint(Color("BrandPrimary"))
        }
    }
}

// MARK: - Lock Screen

private struct MealgramLockScreenView: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color("BrandPrimarySoft").opacity(0.55),
                    Color("BrandBackground"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(
                                Color("BrandInkSubtle").opacity(0.25),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                        Circle()
                            .trim(from: 0, to: max(0.001, state.calorieProgress))
                            .stroke(
                                Color("BrandPrimary"),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(state.kcalConsumed)")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color("BrandInk"))
                                .minimumScaleFactor(0.7)
                            if state.kcalGoal > 0 {
                                Text("/ \(state.kcalGoal)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color("BrandInkMuted"))
                            }
                            Text("kcal")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color("BrandInkSubtle"))
                        }
                    }
                    .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 8) {
                        LockScreenMacroBar(
                            name: WL("Białko"),
                            consumed: state.proteinConsumed,
                            goal: state.proteinGoal,
                            progress: state.proteinProgress,
                            color: Color("BrandPrimary")
                        )
                        LockScreenMacroBar(
                            name: WL("Węgle"),
                            consumed: state.carbsConsumed,
                            goal: state.carbsGoal,
                            progress: state.carbsProgress,
                            color: Color("BrandAccent")
                        )
                        LockScreenMacroBar(
                            name: WL("Tłuszcz"),
                            consumed: state.fatConsumed,
                            goal: state.fatGoal,
                            progress: state.fatProgress,
                            color: Color("BrandWarning")
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text(state.updatedAt, style: .date)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color("BrandInkSubtle"))
                    Spacer()
                    Text("Mealgram")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("BrandInkMuted"))
                }
            }
            .padding(16)
        }
    }
}

private struct LockScreenMacroBar: View {
    let name: String
    let consumed: Int
    let goal: Int
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("BrandInkMuted"))
                Spacer(minLength: 4)
                Text(goal > 0 ? "\(consumed)/\(goal) g" : "\(consumed) g")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color("BrandInk"))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color("BrandInkSubtle").opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Dynamic Island

private struct CompactRing: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("BrandInkSubtle").opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, state.calorieProgress))
                .stroke(
                    Color("BrandPrimary"),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(state.kcalRemaining)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Color("BrandInk"))
                .minimumScaleFactor(0.6)
        }
    }
}

private struct CompactProteinBadge: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        Text("\(state.proteinConsumed)g")
            .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(Color("BrandPrimary"))
    }
}

private struct MinimalRing: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("BrandInkSubtle").opacity(0.3), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.001, state.calorieProgress))
                .stroke(
                    Color("BrandPrimary"),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct DynamicIslandRingView: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("BrandInkSubtle").opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, state.calorieProgress))
                .stroke(
                    Color("BrandPrimary"),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(state.kcalConsumed)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                Text("kcal")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .padding(.leading, 4)
    }
}

private struct DynamicIslandMacroBars: View {
    let state: MealgramActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            islandMacroLine(
                name: "B",
                consumed: state.proteinConsumed,
                goal: state.proteinGoal,
                progress: state.proteinProgress,
                color: Color("BrandPrimary")
            )
            islandMacroLine(
                name: "W",
                consumed: state.carbsConsumed,
                goal: state.carbsGoal,
                progress: state.carbsProgress,
                color: Color("BrandAccent")
            )
            islandMacroLine(
                name: "T",
                consumed: state.fatConsumed,
                goal: state.fatGoal,
                progress: state.fatProgress,
                color: Color("BrandWarning")
            )
        }
        .padding(.trailing, 4)
    }

    private func islandMacroLine(
        name: String,
        consumed: Int,
        goal: Int,
        progress: Double,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
            Text(goal > 0 ? "\(consumed)/\(goal)" : "\(consumed)")
                .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}

private struct DynamicIslandWaterButton: View {
    var body: some View {
        HStack {
            Spacer()
            Link(destination: MealgramActivityDeepLink.addWater) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                    Text(WL("+1 szklanka"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color("BrandPrimary"))
                )
            }
            Spacer()
        }
        .padding(.top, 2)
    }
}

// MARK: - Preview

#Preview(
    "Lock Screen",
    as: .content,
    using: MealgramActivityAttributes()
) {
    MealgramLiveActivity()
} contentStates: {
    MealgramActivityAttributes.ContentState.preview
}

#Preview(
    "Dynamic Island compact",
    as: .dynamicIsland(.compact),
    using: MealgramActivityAttributes()
) {
    MealgramLiveActivity()
} contentStates: {
    MealgramActivityAttributes.ContentState.preview
}

#Preview(
    "Dynamic Island expanded",
    as: .dynamicIsland(.expanded),
    using: MealgramActivityAttributes()
) {
    MealgramLiveActivity()
} contentStates: {
    MealgramActivityAttributes.ContentState.preview
}
