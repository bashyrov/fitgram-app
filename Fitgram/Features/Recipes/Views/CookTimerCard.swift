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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
        .monoCard(padding: 16)
    }

    @ViewBuilder
    private func content(at now: Date) -> some View {
        let remaining = endsAt.map { max(0, Int($0.timeIntervalSince(now).rounded())) }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                MonoIconBox(systemName: "timer", style: .track, size: 36)
                Text("Minutnik kuchenny")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(format(remaining ?? cookMinutes * 60))
                    .font(Tokens.Font.monoNumber(26))
                    .foregroundStyle(remaining == 0 ? Tokens.Palette.warning : Tokens.Palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            HStack(spacing: 8) {
                MonoButton(title: L("Start"), kind: .dark, icon: "play.fill", height: 44) {
                    start()
                }
                MonoButton(title: L("Stop"), kind: .outline, icon: "stop.fill", height: 44) {
                    endsAt = nil
                    isFinishedAck = false
                    Haptics.light()
                }
                .disabled(endsAt == nil)
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
        }
    }

    private var finishedRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tokens.Palette.warning)
            Text("Done — review the dish")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
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
