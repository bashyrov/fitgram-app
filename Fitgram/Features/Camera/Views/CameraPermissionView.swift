import SwiftUI
import UIKit

/// Shown when the user hasn't yet granted camera access (or has denied it).
struct CameraPermissionView: View {
    let status: CameraPermission.Status
    let onRetry: () -> Void
    let onDismiss: () -> Void

    /// Mockup `Permissions` camera card: nav "Uprawnienia", dark 56 pt icon box, 20 pt display title,
    /// muted 13 pt copy and the primary action beside an outline "Zamknij" (both 46 pt).
    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(
                title: TL(pl: "Uprawnienia", en: "Permissions", uk: "Дозволи", ru: "Разрешения", es: "Permisos"),
                onLeft: onDismiss
            )
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    MonoIconBox(systemName: "camera.fill", style: .dark, size: 56)
                    Text(title)
                        .font(Tokens.Font.monoDisplay(20))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                HStack(spacing: 8) {
                    Button {
                        if status == .denied {
                            openSettings()
                        } else {
                            onRetry()
                        }
                    } label: {
                        Text(status == .denied ? "Open Settings" : "Allow access")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(MonoButtonStyle(kind: .dark, height: 46))
                    MonoButton(title: L("Close"), kind: .outline, height: 46, action: onDismiss)
                }
            }
            .monoCard(padding: 16)
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
    }

    private var title: LocalizedStringKey {
        switch status {
        case .denied, .restricted: return "Aparat zablokowany"
        case .notDetermined: return "Potrzebujemy aparatu"
        case .authorized: return "Aparat gotowy"
        }
    }

    private var message: LocalizedStringKey {
        switch status {
        case .denied, .restricted:
            return "Enable camera access in Settings so we can scan meals from photos."
        case .notDetermined:
            return "We scan meals with the camera. Photos go only to our AI and nowhere else."
        case .authorized:
            return "Ready to scan."
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
