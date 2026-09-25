import SwiftUI
import WatchKit

/// Single screen of the Watch companion: three concentric progress
/// rings (kcal / protein / water) with a "+1 szklanka" button below.
/// All numeric values come from the latest `WatchSnapshot` the
/// iPhone has pushed via WCSession.
struct ContentView: View {
    @Environment(WatchStore.self) private var store

    private var snapshot: WatchSnapshot {
        if let real = store.snapshot { return real }
        #if DEBUG
        // No iPhone paired in the screenshot simulator — fall back to the
        // rich preview snapshot so the rings actually have data to render.
        return .preview
        #else
        return .placeholder
        #endif
    }

    var body: some View {
        VStack(spacing: 8) {
            RingsView(snapshot: snapshot)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            WaterButton(
                isLoading: store.isAddingWater,
                action: {
                    WKInterfaceDevice.current().play(.click)
                    store.sendAddWater()
                }
            )

            if let status = store.statusMessage {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}

// MARK: - Rings

private struct RingsView: View {
    let snapshot: WatchSnapshot

    private let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            ring(
                progress: snapshot.kcalProgress,
                color: Color("BrandPrimary"),
                inset: 0
            )
            ring(
                progress: snapshot.proteinProgress,
                color: Color("BrandAccent"),
                inset: lineWidth + 4
            )
            ring(
                progress: snapshot.waterProgress,
                color: Color("BrandWaterBlue"),
                inset: (lineWidth + 4) * 2
            )

            VStack(spacing: 0) {
                Text("\(snapshot.kcalConsumed)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("/ \(snapshot.kcalGoal) kcal")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(snapshot.kcalConsumed) z \(snapshot.kcalGoal) kcal")
        )
    }

    @ViewBuilder
    private func ring(progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)
        }
        .padding(inset)
    }
}

// MARK: - Water button

private struct WaterButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("+1 glass")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color("BrandPrimary"))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text("Add a glass of water"))
    }
}

#Preview {
    ContentView()
        .environment({
            let store = WatchStore()
            return store
        }())
}
