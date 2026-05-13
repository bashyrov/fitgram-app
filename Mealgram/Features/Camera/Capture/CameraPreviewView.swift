import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI bridge for `AVCaptureVideoPreviewLayer`. The hosting UIView keeps
/// the preview layer sized to its bounds so rotation and split-view
/// transitions behave correctly. `gravity` controls letterbox vs crop —
/// barcode scanner uses `.resizeAspect` so the user sees the full frame,
/// food-photo scanner uses `.resizeAspectFill` for the wider preview.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = gravity
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        if uiView.previewLayer.videoGravity != gravity {
            uiView.previewLayer.videoGravity = gravity
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("Layer class misconfigured for CameraPreviewView")
            }
            return layer
        }
    }
}
