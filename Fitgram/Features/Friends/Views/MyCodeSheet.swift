import SwiftUI
import UIKit

/// Personal-code sheet — generates a QR + plain text fallback so the user
/// can hand their Fitgram id to a friend over any channel. Decoding back
/// into an `addFriend` flow lands when the social backend is wired.
struct MyCodeSheet: View {
    let userID: String
    let displayName: String?
    let onDismiss: () -> Void

    @State private var qrImage: UIImage?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                codeBackground
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.lg) {
                        intro
                        qrTile
                        codeRow
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("Mój kod")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Zamknij"), action: onDismiss)
                }
            }
        }
        .task {
            qrImage = QRCodeRenderer.image(for: QRCodeRenderer.deepLink(forUserID: userID))
        }
    }

    private var codeBackground: some View {
        ScreenBackground(mood: .social)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Tokens.Palette.onPrimary)
                .frame(width: 58, height: 58)
                .background(
                    Circle().fill(
                        Tokens.Palette.primary
                    )
                )
            VStack(alignment: .leading, spacing: 5) {
                if let displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(Tokens.Font.archivo(size: 28, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Text(L("Pokaż kod znajomemu. Może go zeskanować albo przepisać identyfikator poniżej."))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.lg)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55)
        )
    }

    private var qrTile: some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
                    .aspectRatio(1, contentMode: .fit)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(Tokens.Space.lg)
                } else {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted)
                        .padding(Tokens.Space.lg)
                }
            }
            Text("fitgram://friend")
                .font(Tokens.Font.manrope(12, weight: 700))
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.md)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Tokens.Palette.surface.opacity(0.86)))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55)
        )
    }

    private var codeRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text(L("Twój identyfikator"))
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Text(userID)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .padding(Tokens.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted.opacity(0.78))
                )
            HStack(spacing: Tokens.Space.sm) {
                actionButton(
                    title: copied ? L("Skopiowane") : L("Skopiuj"),
                    symbol: copied ? "checkmark" : "doc.on.doc"
                ) {
                    UIPasteboard.general.string = userID
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        copied = false
                    }
                }

                ShareLink(
                    item: inviteMessage,
                    subject: Text(L("Dodaj mnie na Fitgram")),
                    preview: SharePreview(
                        "Fitgram",
                        icon: Image(systemName: "leaf.fill")
                    )
                ) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L("Udostępnij"))
                            .font(Tokens.Font.bodyEmphasized)
                    }
                    .foregroundStyle(Tokens.Palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Tokens.Palette.primary))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Tokens.Space.lg)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84)))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55))
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
            }
            .foregroundStyle(Tokens.Palette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(Tokens.Palette.primarySoft))
        }
        .buttonStyle(.pressable)
    }

    /// Plain-text invite the user can paste anywhere. Includes the deep
    /// link form of the id so any client that recognises the
    /// fitgram:// scheme (the app itself, once we ship Universal Links
    /// for fitgram.space, an Open Graph preview later) can route on tap.
    private var inviteMessage: String {
        let opener: String
        if let displayName, !displayName.isEmpty {
            let format = L("%@ zaprasza Cię do Fitgram")
            opener = String.localizedStringWithFormat(format, displayName)
        } else {
            opener = L("Dodaj mnie na Fitgram")
        }
        let codeLine = String.localizedStringWithFormat(L("Mój kod: %@"), userID)
        return """
            \(opener)
            \(codeLine)
            \(QRCodeRenderer.deepLink(forUserID: userID))
            """
    }
}
