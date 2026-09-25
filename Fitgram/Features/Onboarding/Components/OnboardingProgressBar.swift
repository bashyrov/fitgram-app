import SwiftUI

/// Slim, calm progress bar at the top of each onboarding step. Avoids dots
/// so step count isn't visually intimidating.
struct OnboardingProgressBar: View {
    let index: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(index + 1) / Double(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Palette.surfaceMuted)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary,
                                Tokens.Palette.primary.opacity(0.7),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * progress))
                    .shadow(color: Tokens.Palette.primary.opacity(0.35), radius: 4, y: 0)
                    .animation(Tokens.Motion.gentle, value: progress)
            }
        }
        .frame(height: 8)
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
