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
                        ? .init(title: "Otwórz Ustawienia", perform: openSettings)
                        : .init(title: "Pozwól na dostęp", perform: onRetry)
                )
                Spacer()
                SecondaryButton(title: "Zamknij", systemImage: "xmark") { onDismiss() }
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
            return "Włącz dostęp do aparatu w Ustawieniach, żebyśmy mogli skanować posiłki ze zdjęć."
        case .notDetermined:
            return "Skanujemy posiłki z aparatu. Zdjęcia trafiają tylko do naszego AI i nigdzie poza tym."
        case .authorized:
            return "Możesz zacząć skanować."
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
