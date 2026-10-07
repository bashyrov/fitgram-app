import SwiftUI

/// Slim, calm progress bar at the top of each onboarding step (design D:
/// 6 pt track + "N / M" label).
struct OnboardingProgressBar: View {
    let index: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(index + 1) / Double(total)
    }

    private var stepNumber: Int { min(index + 1, max(total, 1)) }

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.Mono.track)
                    Capsule()
                        .fill(Tokens.Mono.strong)
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 6)
            .animation(Tokens.Motion.gentle, value: progress)

            Text(verbatim: "\(stepNumber) / \(total)")
                .font(Tokens.Font.manrope(11, weight: 800))
                .tracking(1.5)
                .foregroundStyle(Tokens.Mono.muted)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement()
        .accessibilityLabel("Krok \(index + 1) z \(total)")
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingProgressBar(index: 0, total: 7)
        OnboardingProgressBar(index: 3, total: 7)
        OnboardingProgressBar(index: 6, total: 7)
    }
    .padding(32)
    .background(Tokens.Palette.background)
}
