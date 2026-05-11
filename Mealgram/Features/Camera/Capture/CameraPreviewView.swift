import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI bridge for `AVCaptureVideoPreviewLayer`. The hosting UIView keeps
/// the preview layer sized to its bounds so rotation and split-view
/// transitions behave correctly.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
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
