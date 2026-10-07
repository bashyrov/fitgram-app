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
                    VStack(alignment: .leading, spacing: 0) {
                        intro
                        Color.clear.frame(height: 18)
                        qrTile
                        Color.clear.frame(height: 10)
                        codeRow
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    shareButton
                }
            }
            .monoNavigationTitle(L("Mój kod"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
        }
        .task {
            qrImage = QRCodeRenderer.image(for: QRCodeRenderer.deepLink(forUserID: userID))
        }
    }

    private var codeBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    private var intro: some View {
        MonoH1(
            text: (displayName?.isEmpty == false ? displayName : nil) ?? L("Mój kod"),
            sub: L("Pokaż kod znajomemu. Może go zeskanować albo przepisać identyfikator poniżej.")
        )
    }

    private var qrTile: some View {
        VStack(spacing: 12) {
            ZStack {
                // QR stays dark-on-white in every theme so cameras can read it.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(10)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tokens.Mono.track)
                        .padding(10)
                }
            }
            .frame(width: 220, height: 220)
            .accessibilityLabel(Text(L("Mój kod")))
            Text("fitgram://friend")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .frame(maxWidth: .infinity)
        .monoCard(padding: 24)
    }

    private var codeRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Twój identyfikator"))
            HStack(spacing: 8) {
                Text(userID)
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MonoButton(
                    title: copied ? L("Skopiowane") : L("Skopiuj"),
                    kind: .outline,
                    icon: copied ? "checkmark" : "doc.on.doc",
                    height: 40,
                    fullWidth: false
                ) {
                    UIPasteboard.general.string = userID
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        copied = false
                    }
                }
                .fixedSize()
            }
        }
        .monoCard(padding: 16)
    }

    private var shareButton: some View {
        ShareLink(
            item: inviteMessage,
            subject: Text(L("Dodaj mnie na Fitgram")),
            preview: SharePreview(
                "Fitgram",
                icon: Image(systemName: "leaf.fill")
            )
        ) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                Text(L("Udostępnij"))
            }
        }
        .buttonStyle(MonoButtonStyle(kind: .dark))
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
