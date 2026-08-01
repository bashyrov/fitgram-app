import SwiftUI

/// Full-screen photo viewer raised when the user taps the inline photo
/// header in MealDetailSheet. Supports pinch-to-zoom (1×…4×) and pan
/// while zoomed; tap to dismiss when at base zoom.
struct MealPhotoZoomView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnificationGesture)
                .simultaneousGesture(panGesture)
                .onTapGesture {
                    if scale > 1 {
                        resetZoom()
                    } else {
                        onDismiss()
                    }
                }
                .animation(Tokens.Motion.gentle, value: scale)
                .animation(Tokens.Motion.gentle, value: offset)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel(Text("Close"))
            .padding(Tokens.Space.lg)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    resetZoom()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
