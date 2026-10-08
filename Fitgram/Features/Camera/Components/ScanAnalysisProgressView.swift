import SwiftUI
import UIKit

/// Animated "AI is reading your plate" card shared by the camera scanner and
/// the onboarding demo. The detector gives no real progress, so the ring eases
/// towards 95 % (fast at first, then slowing) and the three steps tick off as
/// it passes each threshold; the caller swaps this view out once the result
/// arrives.
struct ScanAnalysisProgressView: View {
    /// The photo being analysed; shown with a moving scan line when present.
    var image: UIImage?

    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let thumbSize: CGFloat = 112
    private static let ringSize: CGFloat = 136

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            let progress = Self.progress(after: elapsed)
            let phase = Self.phase(for: progress)
            VStack(spacing: 18) {
                ring(progress: progress, elapsed: elapsed)
                VStack(spacing: 6) {
                    Text(L(Self.titles[phase]))
                        .font(Tokens.Font.monoDisplay(20))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                        .multilineTextAlignment(.center)
                    Text(L(Self.subtitles[phase]))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .animation(Tokens.Motion.gentle, value: phase)
                steps(phase: phase)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L(Self.titles[phase])))
            .accessibilityValue(Text(verbatim: "\(Int(progress * 100))%"))
        }
        .onAppear { startedAt = Date() }
    }

    // MARK: - Pieces

    private func ring(progress: Double, elapsed: TimeInterval) -> some View {
        ZStack {
            Circle()
                .stroke(Tokens.Mono.heroLine, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Tokens.Mono.hi, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            thumbnail(elapsed: elapsed)
            Text(verbatim: "\(Int(progress * 100))%")
                .font(Tokens.Font.monoNumber(15))
                .foregroundStyle(Tokens.Mono.onHi)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(Tokens.Mono.hi))
                .offset(y: Self.ringSize / 2)
        }
        .frame(width: Self.ringSize, height: Self.ringSize)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func thumbnail(elapsed: TimeInterval) -> some View {
        let size = Self.thumbSize
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle().fill(Tokens.Mono.heroLine)
                Image(systemName: "fork.knife")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Tokens.Mono.hi)
            }
            if !reduceMotion {
                // Scan line sweeping up and down over the plate.
                let sweep = (sin(elapsed * 2.4) + 1) / 2
                LinearGradient(
                    colors: [Tokens.Mono.hi.opacity(0), Tokens.Mono.hi.opacity(0.55), Tokens.Mono.hi.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
                .offset(y: (sweep - 0.5) * size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func steps(phase: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(Self.stepTitles.indices, id: \.self) { index in
                stepChip(title: L(Self.stepTitles[index]), state: stepState(index, phase: phase))
            }
        }
    }

    private enum StepState { case done, active, pending }

    private func stepState(_ index: Int, phase: Int) -> StepState {
        index < phase ? .done : (index == phase ? .active : .pending)
    }

    private func stepChip(title: String, state: StepState) -> some View {
        HStack(spacing: 5) {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
            case .active:
                ProgressView()
                    .controlSize(.mini)
                    .tint(Tokens.Mono.onHi)
            case .pending:
                Image(systemName: "circle")
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(Tokens.Font.manrope(12, weight: 800))
        .foregroundStyle(chipForeground(state))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Capsule().fill(state == .active ? Tokens.Mono.hi : Tokens.Mono.heroLine))
        .animation(Tokens.Motion.gentle, value: state == .active)
    }

    private func chipForeground(_ state: StepState) -> Color {
        switch state {
        case .done: return Tokens.Mono.hi
        case .active: return Tokens.Mono.onHi
        case .pending: return Tokens.Mono.heroMuted
        }
    }

    // MARK: - Timing

    /// Eases from 0 towards 95 % (~65 % after 2.5 s, ~90 % after 7 s).
    static func progress(after seconds: TimeInterval) -> Double {
        0.95 * (1 - exp(-max(0, seconds) / 2.4))
    }

    static func phase(for progress: Double) -> Int {
        progress < 0.35 ? 0 : (progress < 0.72 ? 1 : 2)
    }

    private static let stepTitles = ["Photo", "Food", "Macros"]
    private static let titles = ["Analizujemy zdjęcie", "Rozpoznajemy produkty", "Liczymy kalorie i makro"]
    private static let subtitles = [
        "Sprawdzamy kadr i porcję.",
        "AI szuka składników na talerzu.",
        "Za chwilę pokażemy wynik do poprawienia.",
    ]
}
