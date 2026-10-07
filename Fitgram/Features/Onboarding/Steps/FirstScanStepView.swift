import PhotosUI
import SwiftUI
import UIKit

/// One-shot AI demo. The user takes (or picks) a single photo; we run it
/// through the real `FoodDetector` and display the result inline. Nothing
/// is persisted to SwiftData — this exists purely to convince the user the
/// pipeline is real before they commit to onboarding the rest of the way.
struct FirstScanStepView: View {
    let onContinue: () -> Void

    @State private var stage: Stage = .idle
    @State private var pickedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false

    private let detector: any FoodDetector = FoodDetectorFactory.make()

    private enum Stage: Equatable {
        case idle
        case processing
        case result(ScanResult)
        case failed(String)

        var isResult: Bool {
            if case .result = self { return true }
            return false
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: titleKey,
            subtitle: subtitleKey,
            primaryTitle: ctaKey,
            primarySystemImage: "arrow.right",
            secondaryTitle: stage.isResult ? "Try again" : nil,
            secondaryAction: stage.isResult ? { reset() } : nil,
            onPrimary: onContinue,
            content: {
                content
            }
        )
        .photosPicker(
            isPresented: Binding(
                get: { selectedPhoto == nil && stage == .idle && pickedImage == nil && pickerVisible },
                set: { if !$0 { pickerVisible = false } }),
            selection: $selectedPhoto,
            matching: .images
        )
        .fullScreenCover(isPresented: $showingCamera) {
            DemoCameraSheet { image in
                showingCamera = false
                pickedImage = image
                Task { await runDetection(on: image) }
            } onCancel: {
                showingCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                {
                    pickedImage = image
                    await runDetection(on: image)
                }
                selectedPhoto = nil
            }
        }
    }

    @State private var pickerVisible = false

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 10) {
            photoSlot
            switch stage {
            case .idle:
                EmptyView()
            case .processing:
                LoadingHero(title: "Reading the plate…")
                    .frame(height: 200)
            case .result(let result):
                DemoScanResultCard(result: result)
            case .failed(let message):
                DemoScanFailureCard(message: message) { reset() }
            }
            if stage != .processing {
                DemoScanCTA(
                    onCamera: {
                        reset()
                        presentCamera()
                    },
                    onLibrary: {
                        reset()
                        pickerVisible = true
                    }
                )
            }
        }
    }

    /// 240 pt photo slot — the picked photo, or the striped placeholder.
    @ViewBuilder
    private var photoSlot: some View {
        if let pickedImage {
            Color.clear
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(uiImage: pickedImage)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                        .stroke(Tokens.Mono.line, lineWidth: 1)
                )
        } else {
            DemoPlatePlaceholder()
        }
    }

    private var titleKey: String {
        switch stage {
        case .idle, .processing:
            return "Try a scan in 5 seconds"
        case .result:
            return "That's how it works"
        case .failed:
            return "Something went wrong"
        }
    }

    private var subtitleKey: String {
        switch stage {
        case .idle:
            return "Point the camera at your plate or pick a photo from the library. Nothing is saved."
        case .processing:
            return "Analysing your photo — this takes a moment."
        case .result:
            return "Everything is editable. This is just a demo — nothing is saved to Today yet."
        case .failed:
            return "Try again or skip this step."
        }
    }

    private var ctaKey: LocalizedStringKey {
        switch stage {
        case .idle, .processing, .failed:
            return "Skip demo"
        case .result:
            return "Great, next"
        }
    }

    private func presentCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showingCamera = true
        } else {
            pickerVisible = true
        }
    }

    private func reset() {
        stage = .idle
        pickedImage = nil
        selectedPhoto = nil
    }

    @MainActor
    private func runDetection(on image: UIImage) async {
        stage = .processing
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            stage = .failed("Couldn't prepare the photo.")
            return
        }
        do {
            let result = try await detector.detect(from: data, suggestedMealType: nil)
            withAnimation(Tokens.Motion.gentle) {
                stage = .result(result)
            }
        } catch {
            stage = .failed("The scanner isn't responding. Try again.")
        }
    }
}

private struct DemoScanCTA: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            MonoButton(title: L("Take a photo"), kind: .outline, icon: "camera", height: 46, action: onCamera)
            MonoButton(title: L("Wybierz z galerii"), kind: .outline, icon: "photo", height: 46, action: onLibrary)
        }
    }
}

/// Striped image slot from the mockup (`placeholder_img(240, …, 24)`).
private struct DemoPlatePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
            .fill(Tokens.Palette.surface)
            .overlay(
                Canvas { context, size in
                    let stripe: CGFloat = 14
                    var offset: CGFloat = -size.height
                    while offset < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: size.height))
                        path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                        path.addLine(to: CGPoint(x: offset + size.height + stripe, y: 0))
                        path.addLine(to: CGPoint(x: offset + stripe, y: size.height))
                        path.closeSubpath()
                        context.fill(path, with: .color(Tokens.Mono.track))
                        offset += stripe * 2
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
            .overlay(
                Label(L("Wybierz z galerii"), systemImage: "photo")
                    .font(Tokens.Font.manrope(13, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            )
            .frame(height: 240)
            .accessibilityHidden(true)
    }
}

private struct DemoScanResultCard: View {
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: headlineName)
                Spacer(minLength: 8)
                Text(verbatim: "~\(Int(result.totalCalories.rounded())) kcal")
                    .font(Tokens.Font.monoNumber(24))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
            }
            FlowLayout(spacing: 6) {
                ForEach(result.items) { item in
                    Text(verbatim: "\(item.name) · \(Int(item.quantityGrams.rounded())) g")
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Capsule().fill(Tokens.Mono.track))
                }
            }
            MonoMacroRow(protein: result.totalProtein, carbs: result.totalCarbs, fat: result.totalFat)
        }
        .monoCard(padding: 16)
    }

    private var headlineName: String {
        if let first = result.items.first {
            return result.items.count > 1 ? "\(first.name) + \(result.items.count - 1)" : first.name
        }
        return L("Your meal")
    }
}

private struct DemoScanFailureCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.Mono.danger)
                Text(LocalizedStringKey(message))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MonoButton(title: L("Try again"), kind: .outline, icon: "arrow.clockwise", height: 46, action: onRetry)
        }
        .monoCard(padding: 16)
    }
}

private struct DemoCameraSheet: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraDevice = .rear
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
