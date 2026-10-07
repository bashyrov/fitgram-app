import SwiftUI

extension View {
    /// Mount the toast overlay on top of the current view. Needed for
    /// surfaces presented as sheets / fullScreenCover — those live in
    /// a separate window, so the RootView-level overlay can't reach
    /// them. Reads the centre from the SwiftUI environment.
    func toastSurface() -> some View {
        modifier(ToastSurfaceModifier())
    }
}

private struct ToastSurfaceModifier: ViewModifier {
    @Environment(ToastCenter.self) private var center

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ToastOverlay(center: center)
        }
    }
}

/// Drops a single toast banner from the top safe-area when
/// `ToastCenter.current` is non-nil. Auto-dismiss runs from the
/// center; this view just animates in and renders.
struct ToastOverlay: View {
    @Bindable var center: ToastCenter

    var body: some View {
        VStack {
            if let toast = center.current {
                ToastBanner(toast: toast, onDismiss: center.dismiss)
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .id(toast.id)
            }
            Spacer()
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: center.current?.id)
        .allowsHitTesting(center.current != nil)
    }
}

struct ToastBanner: View {
    let toast: ToastCenter.Toast
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            iconPuck
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(2)
                if let message = toast.message, !message.isEmpty {
                    Text(message)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Tokens.Mono.heroLine)
                    )
            }
            .accessibilityLabel(Text("Close"))
        }
        .padding(.vertical, Tokens.Space.sm)
        .padding(.horizontal, Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        onDismiss()
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
    }

    private var iconPuck: some View {
        Image(systemName: toast.symbol)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Tokens.Mono.onHi)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                    .fill(Tokens.Mono.hi)
            )
    }
}
