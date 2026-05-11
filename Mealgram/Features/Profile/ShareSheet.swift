import SwiftUI
import UIKit

/// Thin UIKit bridge for the system share sheet. ShareLink doesn't support
/// content generated on-tap, so we trigger the export then present this.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable URL wrapper so `.sheet(item:)` works directly.
struct SharedFile: Identifiable, Equatable {
    var url: URL
    var id: URL { url }
}
