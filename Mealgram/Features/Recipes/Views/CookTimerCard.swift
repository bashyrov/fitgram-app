import SwiftUI

/// Inline cook-along timer for RecipeDetailView. Pure SwiftUI; uses a
/// TimelineView at 1 Hz so the countdown stays in step with wall clock
/// without the view owning a heavyweight Timer. Runs entirely in-app —
/// no background notification yet.
struct CookTimerCard: View {
    let cookMinutes: Int

    @State private var endsAt: Date?
    @State private var isFinishedAck = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Minutnik kuchenny")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    body(at: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func body(at now: Date) -> some View {
        if let endsAt {
            let remaining = max(0, Int(endsAt.timeIntervalSince(now).rounded()))
            HStack(spacing: Tokens.Space.md) {
                Text(format(remaining))
                    .font(Tokens.Font.counter)
                    .foregroundStyle(
                        remaining == 0 ? Tokens.Palette.warning : Tokens.Palette.primary
                    )
                Spacer()
                Button(role: .destructive) {
                    self.endsAt = nil
                    isFinishedAck = false
                    Haptics.light()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(Tokens.Font.bodyEmphasized)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Palette.warning)
            }
            if remaining == 0 {
                finishedRow
                    .task(id: endsAt) {
                        if !isFinishedAck {
                            Haptics.success()
                            isFinishedAck = true
                        }
                    }
            }
        } else {
            HStack(spacing: Tokens.Space.md) {
                Text("\(cookMinutes) min")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
                Button {
                    start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(Tokens.Font.bodyEmphasized)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Palette.primary)
            }
        }
    }

    private var finishedRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tokens.Palette.warning)
            Text("Gotowe — sprawdź danie")
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private func start() {
        endsAt = Date().addingTimeInterval(TimeInterval(cookMinutes * 60))
        isFinishedAck = false
        Haptics.light()
    }

    private func format(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
