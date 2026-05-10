import SwiftUI

/// Temporary root view for the bootstrap milestone. Once auth + onboarding land
/// (Phase 1), this becomes the routing host that chooses between the auth
/// stack, onboarding, and the main `TabView`.
struct RootView: View {
    var body: some View {
        ZStack {
            Tokens.Palette.background
                .ignoresSafeArea()

            VStack(spacing: Tokens.Space.xxl) {
                Spacer()

                VStack(spacing: Tokens.Space.md) {
                    ZStack {
                        Circle()
                            .fill(Tokens.Palette.primarySoft)
                            .frame(width: 140, height: 140)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 56, weight: .regular))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .mealgramShadow(Tokens.Shadow.float)

                    Text("Mealgram")
                        .font(Tokens.Font.display)
                        .foregroundStyle(Tokens.Palette.ink)

                    Text("Twój spokojny tracker kalorii.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: Tokens.Space.md) {
                    PrimaryButton(title: "Zacznij", systemImage: "sparkles") {}
                    SecondaryButton(title: "Mam już konto") {}
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
        }
    }
}

#Preview("Root") {
    RootView()
}
