import SwiftUI
import UIKit

/// Personal-code sheet — generates a QR + plain text fallback so the user
/// can hand their Mealgram id to a friend over any channel. Decoding back
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
                    VStack(spacing: Tokens.Space.lg) {
                        intro
                        qrTile
                        codeRow
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Mój kod"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
        .task {
            qrImage = QRCodeRenderer.image(for: QRCodeRenderer.deepLink(forUserID: userID))
        }
    }

    private var codeBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.42))
                .frame(width: 350, height: 350)
                .blur(radius: 108)
                .offset(x: -160, y: -210)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.24))
                .frame(width: 300, height: 300)
                .blur(radius: 112)
                .offset(x: 150, y: -10)
            Circle()
                .fill(Tokens.Palette.success.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 100)
                .offset(x: -80, y: 350)
        }
        .ignoresSafeArea()
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
            VStack(alignment: .leading, spacing: 5) {
                if let displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Text("Pokaż kod znajomemu. Może go zeskanować albo przepisać identyfikator poniżej.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.38), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.10), radius: 24, y: 14)
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
            Text("mealgram://friend")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Tokens.Palette.surface.opacity(0.86)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.42), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.12), radius: 24, y: 14)
    }

    private var codeRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Twój identyfikator")
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
                    title: copied ? "Skopiowane" : "Skopiuj",
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
                    subject: Text("Dodaj mnie na Mealgram"),
                    preview: SharePreview(
                        "Mealgram",
                        icon: Image(systemName: "leaf.fill")
                    )
                ) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Udostępnij")
                            .font(Tokens.Font.bodyEmphasized)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Tokens.Palette.primary))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.36), lineWidth: 1))
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
    /// mealgram:// scheme (the app itself, once we ship Universal Links
    /// for mealgram.xyz, an Open Graph preview later) can route on tap.
    private var inviteMessage: String {
        let opener: String
        if let displayName, !displayName.isEmpty {
            let format = L("%@ zaprasza Cię do Mealgram")
            opener = String.localizedStringWithFormat(format, displayName)
        } else {
            opener = L("Dodaj mnie na Mealgram")
        }
        let codeLine = String.localizedStringWithFormat(L("Mój kod: %@"), userID)
        return """
            \(opener)
            \(codeLine)
            \(QRCodeRenderer.deepLink(forUserID: userID))
            """
    }
}
