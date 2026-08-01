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
        switch stage {
        case .idle:
            DemoScanCTA(
                onCamera: { presentCamera() },
                onLibrary: { pickerVisible = true }
            )
        case .processing:
            VStack(spacing: Tokens.Space.md) {
                if let pickedImage {
                    Image(uiImage: pickedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
                        .mealgramShadow(Tokens.Shadow.float)
                }
                LoadingHero(title: "Reading the plate…")
                    .frame(height: 200)
            }
        case .result(let result):
            DemoScanResultCard(image: pickedImage, result: result)
        case .failed(let message):
            DemoScanFailureCard(message: message) { reset() }
        }
    }

    private var titleKey: LocalizedStringKey {
        switch stage {
        case .idle, .processing:
            return "Try a scan in 5 seconds"
        case .result:
            return "That's how it works"
        case .failed:
            return "Something went wrong"
        }
    }

    private var subtitleKey: LocalizedStringKey {
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
        VStack(spacing: Tokens.Space.md) {
            Button(action: onCamera) {
                heroTile(
                    symbol: "camera.viewfinder",
                    title: "Take a photo",
                    caption: "Camera opens right away"
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: onLibrary) {
                heroTile(
                    symbol: "photo.on.rectangle",
                    title: "Wybierz z galerii",
                    caption: "Idealne na symulatorze"
                )
                .frame(maxWidth: .infinity, minHeight: 0)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func heroTile(symbol: String, title: LocalizedStringKey, caption: LocalizedStringKey) -> some View {
        VStack(spacing: Tokens.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .fill(Tokens.Palette.primarySoft)
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .frame(height: 160)
            .mealgramShadow(Tokens.Shadow.float)

            VStack(spacing: 2) {
                Text(title)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(caption)
                    .font(Tokens.Font.callout)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }
}

private struct DemoScanResultCard: View {
    let image: UIImage?
    let result: ScanResult

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
                    .mealgramShadow(Tokens.Shadow.float)
            }
            Card(elevation: Tokens.Shadow.float) {
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(headlineName)
                            .font(Tokens.Font.headline)
                            .lineLimit(2)
                        Spacer()
                        Text("~\(Int(result.totalCalories.rounded())) kcal")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    Divider().background(Tokens.Palette.separator)
                    macroLine(label: "Protein", grams: result.totalProtein)
                    macroLine(label: "Carbs", grams: result.totalCarbs)
                    macroLine(label: "Fat", grams: result.totalFat)
                    if result.items.count > 1 {
                        Divider().background(Tokens.Palette.separator)
                        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                            ForEach(result.items) { item in
                                HStack {
                                    Text(item.name)
                                        .font(Tokens.Font.body)
                                        .foregroundStyle(Tokens.Palette.ink)
                                    Spacer()
                                    Text("\(Int(item.quantityGrams.rounded())) g")
                                        .font(Tokens.Font.callout)
                                        .foregroundStyle(Tokens.Palette.inkMuted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var headlineName: String {
        if let first = result.items.first {
            return result.items.count > 1 ? "\(first.name) + \(result.items.count - 1)" : first.name
        }
        return "Your meal"
    }

    private func macroLine(label: LocalizedStringKey, grams: Double) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text("\(Int(grams.rounded())) g")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }
}

private struct DemoScanFailureCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        Card(elevation: Tokens.Shadow.card) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(LocalizedStringKey(message))
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise", action: onRetry)
            }
        }
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
