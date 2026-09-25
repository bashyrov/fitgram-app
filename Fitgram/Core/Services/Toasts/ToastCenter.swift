import Foundation
import Observation
import SwiftUI

/// Lightweight toast bus for transient, non-blocking confirmations
/// ("Wysłano: Zachęć", "Zapisano do mojej książki" etc.). Mounted as
/// an overlay at the RootView level; any feature reaches it via the
/// environment and calls `success` / `info` / `warning` / `error`.
@MainActor
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String?
        let symbol: String
        let style: ToastStyle
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    /// Replace whatever is showing with the given toast. Default
    /// 2.5s lifetime so the user always reads it without it sticking
    /// around. `0` keeps it onscreen until manually dismissed.
    func present(_ toast: Toast, dismissAfter: TimeInterval = 2.5) {
        dismissTask?.cancel()
        current = toast
        guard dismissAfter > 0 else { return }
        let id = toast.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(dismissAfter))
            guard !Task.isCancelled,
                let self,
                self.current?.id == id
            else { return }
            self.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }

    // MARK: - Convenience builders

    func success(_ title: String, message: String? = nil) {
        present(
            Toast(title: title, message: message, symbol: "checkmark.circle.fill", style: .success)
        )
    }

    func info(_ title: String, message: String? = nil) {
        present(
            Toast(title: title, message: message, symbol: "info.circle.fill", style: .info)
        )
    }

    func warning(_ title: String, message: String? = nil) {
        present(
            Toast(title: title, message: message, symbol: "exclamationmark.triangle.fill", style: .warning)
        )
    }

    func error(_ title: String, message: String? = nil) {
        present(
            Toast(title: title, message: message, symbol: "xmark.octagon.fill", style: .error)
        )
    }
}

enum ToastStyle: Equatable {
    case success, info, warning, error

    var tint: Color {
        switch self {
        case .success: return Tokens.Palette.primary
        case .info: return Tokens.Palette.accent
        case .warning: return Tokens.Palette.warning
        case .error: return Tokens.Palette.error
        }
    }
}
