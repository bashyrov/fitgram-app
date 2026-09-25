import SwiftUI
import UIKit

/// Shown when the user hasn't yet granted camera access (or has denied it).
struct CameraPermissionView: View {
    let status: CameraPermission.Status
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.xl) {
                Spacer()
                EmptyState(
                    symbol: "camera.metering.unknown",
                    title: title,
                    message: message,
                    action: status == .denied
                        ? .init(title: "Open Settings", perform: openSettings)
                        : .init(title: "Allow access", perform: onRetry)
                )
                Spacer()
                SecondaryButton(title: "Close", systemImage: "xmark") { onDismiss() }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xl)
            }
        }
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
