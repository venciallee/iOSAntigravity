import SwiftUI
import AntigravityData
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
import AVFoundation
import CoreImage
#endif

/// Native camera + photo library + clipboard QR code scanner for pairing directly with
/// Antigravity Desktop's official Remote Control QR (`https://antigravity.google.com/r/<id>`).
public struct RemoteControlQRScannerSheet: View {
    public var onScannedQR: (String) -> Void
    public var onDismiss: () -> Void

    @State private var manualLinkDraft: String = ""
    @State private var scannerErrorMessage: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isCameraAvailable: Bool = true

    public init(
        onScannedQR: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onScannedQR = onScannedQR
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Sheet Top Bar
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Scan Remote Control QR")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.white)

                Spacer()

                Button {
                    pasteFromClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text("Paste")
                            .font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-paste-qr-link")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // Camera Viewfinder Card
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)

                #if canImport(UIKit) && canImport(AVFoundation)
                if isCameraAvailable {
                    QRCameraPreviewRepresentable(
                        onCodeDetected: { rawValue in
                            handleScannedCandidate(rawValue)
                        },
                        onCameraUnavailable: { reason in
                            isCameraAvailable = false
                            scannerErrorMessage = reason
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    cameraFallbackPlaceholder
                }
                #else
                cameraFallbackPlaceholder
                #endif

                // Periwinkle Reticle Frame
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        AntigravityTheme.accentPeriwinkle.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.5, dash: [26, 14])
                    )
                    .frame(width: 228, height: 228)
                    .allowsHitTesting(false)
            }
            .frame(height: isCameraAvailable ? 380 : 280)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)

            Text("Open Antigravity on Mac/PC → click **Remote Control** and point your camera at the QR code.")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(UEChromePalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let scannerErrorMessage, !scannerErrorMessage.isEmpty {
                Text(scannerErrorMessage)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AntigravityTheme.statusWaiting)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            #if canImport(PhotosUI)
            // Pick QR Screenshot from Photos
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Choose QR from Photos")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(UEChromePalette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AntigravityTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await decodeQRFromPhotoItem(newItem)
                }
            }
            #endif

            // Only show manual link input when physical camera is unavailable (e.g. iOS Simulator)
            if !isCameraAvailable {
                HStack(spacing: 8) {
                    TextField("https://antigravity.google.com/r/...", text: $manualLinkDraft)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(UEChromePalette.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .frame(minHeight: 46)
                        .background(AntigravityTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        handleScannedCandidate(manualLinkDraft)
                    } label: {
                        Text("Connect")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AntigravityTheme.accentPeriwinkle)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(manualLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 8)
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    private var cameraFallbackPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
            Text("Camera Unavailable in Simulator")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Choose a QR screenshot from Photos or paste the `https://antigravity.google.com/r/...` link below.")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(UEChromePalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pasted.isEmpty {
            manualLinkDraft = pasted
            handleScannedCandidate(pasted)
        } else {
            scannerErrorMessage = "Clipboard is empty."
        }
        #endif
    }

    private func handleScannedCandidate(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if RemoteHostInstance.parseRemoteControlTarget(trimmed) != nil || trimmed.lowercased().hasPrefix("antigravity://") {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            onScannedQR(trimmed)
        } else {
            scannerErrorMessage = "Unrecognized QR code: expected an Antigravity Remote Control link (`https://antigravity.google.com/r/...`)."
        }
    }

    #if canImport(PhotosUI)
    private func decodeQRFromPhotoItem(_ item: PhotosPickerItem) async {
        guard let imageData = try? await item.loadTransferable(type: Data.self) else {
            scannerErrorMessage = "Could not load selected image."
            return
        }
        #if canImport(UIKit) && canImport(CoreImage)
        guard let ciImage = CIImage(data: imageData),
              let detector = CIDetector(
                  ofType: CIDetectorTypeQRCode,
                  context: nil,
                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else {
            scannerErrorMessage = "Could not initialize QR detector."
            return
        }
        let features = detector.features(in: ciImage).compactMap { $0 as? CIQRCodeFeature }
        if let payload = features.compactMap(\.messageString).first(where: { !$0.isEmpty }) {
            handleScannedCandidate(payload)
        } else {
            scannerErrorMessage = "No QR code found in the selected image."
        }
        #endif
    }
    #endif
}

#if canImport(UIKit) && canImport(AVFoundation)
private struct QRCameraPreviewRepresentable: UIViewControllerRepresentable {
    let onCodeDetected: (String) -> Void
    let onCameraUnavailable: (String) -> Void

    func makeUIViewController(context: Context) -> QRCameraScannerViewController {
        let vc = QRCameraScannerViewController()
        vc.onCodeDetected = onCodeDetected
        vc.onCameraUnavailable = onCameraUnavailable
        return vc
    }

    func updateUIViewController(_ uiViewController: QRCameraScannerViewController, context: Context) {}
}

private final class QRCameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeDetected: ((String) -> Void)?
    var onCameraUnavailable: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        checkPermissionAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        nonisolated(unsafe) let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func checkPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            Task { @MainActor [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    self?.configureSession()
                } else {
                    self?.onCameraUnavailable?("Camera permission denied. Enable Camera in iOS Settings or scan a screenshot.")
                }
            }
        default:
            onCameraUnavailable?("Camera access is disabled in iOS Settings.")
        }
    }

    private func configureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            onCameraUnavailable?("No physical camera available on this device.")
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            onCameraUnavailable?("Unable to attach QR metadata scanner.")
            return
        }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.previewLayer = layer

        nonisolated(unsafe) let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func handleDetectedString(_ stringValue: String) {
        guard !didEmitCode else { return }
        didEmitCode = true
        nonisolated(unsafe) let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
        onCodeDetected?(stringValue)
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              readable.type == .qr,
              let stringValue = readable.stringValue,
              !stringValue.isEmpty else {
            return
        }
        Task { @MainActor [weak self] in
            self?.handleDetectedString(stringValue)
        }
    }
}
#endif
