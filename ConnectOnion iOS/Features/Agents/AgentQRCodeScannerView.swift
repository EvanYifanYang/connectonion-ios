import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision
import VisionKit

struct AgentQRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onScan: (AgentQRCodePayload) -> Void

    @State private var cameraState: CameraState = .checking
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isReadingPhoto = false
    @State private var torchEnabled = false
    @State private var notice: ScannerNotice?
    @State private var completedPayload: AgentQRCodePayload?
    @State private var successFeedbackTrigger = 0
    @State private var errorFeedbackTrigger = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer

            if cameraState == .ready, completedPayload == nil {
                scannerChrome
            } else if completedPayload == nil {
                unavailableContent
            }

            if let completedPayload {
                successOverlay(for: completedPayload)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }

            if isReadingPhoto {
                Color.black.opacity(0.38).ignoresSafeArea()
                ProgressView("Reading QR code…")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .foregroundStyle(.white)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier(AccessibilityID.agentQRScanner)
        .task {
            await refreshCameraState()
        }
        .task(id: notice?.id) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                notice = nil
            }
        }
        .task(id: completedPayload) {
            guard let completedPayload else { return }
            try? await Task.sleep(for: reduceMotion ? .milliseconds(250) : .milliseconds(650))
            guard !Task.isCancelled else { return }
            onScan(completedPayload)
            dismiss()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await readQRCode(from: item) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, completedPayload == nil else { return }
            Task { await refreshCameraState() }
        }
        .onDisappear {
            setTorch(enabled: false, reportFailure: false)
        }
        .sensoryFeedback(.success, trigger: successFeedbackTrigger)
        .sensoryFeedback(.error, trigger: errorFeedbackTrigger)
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if cameraState == .ready {
            AgentQRCodeCameraView(
                isScanning: completedPayload == nil,
                onCode: handle(rawPayload:),
                onUnavailable: handleCameraUnavailable
            )
            .ignoresSafeArea()
            .overlay {
                Color.black.opacity(completedPayload == nil ? 0.16 : 0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        } else {
            LinearGradient(
                colors: [.black, Color.onion.opacity(0.25), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var scannerChrome: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 600
            let reticleSide = min(
                isCompact ? 190 : 276,
                max(150, proxy.size.height * (isCompact ? 0.4 : 0.34))
            )

            VStack(spacing: 0) {
                scannerHeader

                Spacer(minLength: isCompact ? 8 : 28)

                ScannerReticle(isAnimated: !reduceMotion)
                    .frame(width: reticleSide, height: reticleSide)
                    .accessibilityHidden(true)

                Text("Align the agent QR code inside the frame")
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, isCompact ? 8 : 11)
                    .background(.black.opacity(0.42), in: .capsule)
                    .padding(.top, isCompact ? 10 : 22)

                Spacer(minLength: isCompact ? 8 : 22)

                if let notice {
                    Label(notice.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, isCompact ? 8 : 12)
                        .frame(maxWidth: 430, alignment: .leading)
                        .background(.red.opacity(0.78), in: .rect(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .padding(.bottom, isCompact ? 8 : 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                scannerControls
                    .padding(.bottom, isCompact ? 8 : 24)
            }
        }
        .safeAreaPadding(.top, 10)
        .safeAreaPadding(.bottom, 4)
    }

    private var scannerHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Scan Agent")
                    .font(.title2.bold())
                Text("Connect securely from a QR code")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Close scanner")
        }
        .padding(.horizontal, 20)
    }

    private var scannerControls: some View {
        HStack(spacing: 14) {
            photoPicker

            if torchAvailable {
                Button {
                    setTorch(enabled: !torchEnabled, reportFailure: true)
                } label: {
                    Label(
                        torchEnabled ? "Light On" : "Light",
                        systemImage: torchEnabled ? "bolt.fill" : "bolt.slash.fill"
                    )
                        .frame(minWidth: 84)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(torchEnabled ? "Turn flashlight off" : "Turn flashlight on")
                .accessibilityIdentifier(AccessibilityID.agentQRScannerTorchButton)
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
                .frame(minWidth: 118)
        }
        .buttonStyle(.glass)
        .disabled(isReadingPhoto || completedPayload != nil)
        .accessibilityIdentifier(AccessibilityID.agentQRScannerPhotoButton)
    }

    private var unavailableContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close scanner")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            VStack(spacing: 18) {
                if cameraState.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: cameraState.icon)
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(Color.onion)
                }

                VStack(spacing: 8) {
                    Text(cameraState.title)
                        .font(.title2.bold())
                    Text(cameraState.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if cameraState == .permissionDenied {
                    Button("Open Settings", systemImage: "gear") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                    }
                    .buttonStyle(.glassProminent)
                } else if cameraState == .unavailable {
                    Button("Try Again", systemImage: "arrow.clockwise") {
                        Task { await refreshCameraState() }
                    }
                    .buttonStyle(.glassProminent)
                }

                if !cameraState.isLoading {
                    HStack {
                        Rectangle()
                            .fill(.white.opacity(0.18))
                            .frame(height: 1)
                        Text("OR")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Rectangle()
                            .fill(.white.opacity(0.18))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    photoPicker

                    if let notice {
                        Label(notice.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.78), in: .rect(cornerRadius: 16))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func successOverlay(for payload: AgentQRCodePayload) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: successFeedbackTrigger)

            Text("Agent Found")
                .font(.title2.bold())

            Text(AgentAddress(rawValue: payload.address)?.shortDisplay ?? payload.address)
                .font(.body.monospaced())
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 28))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Agent found")
    }

    private var torchAvailable: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch == true
    }

    private func refreshCameraState() async {
        guard completedPayload == nil else { return }

        guard DataScannerViewController.isSupported else {
            cameraState = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = DataScannerViewController.isAvailable ? .ready : .unavailable
        case .notDetermined:
            cameraState = .requestingPermission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard !Task.isCancelled else { return }
            cameraState = granted && DataScannerViewController.isAvailable ? .ready : .permissionDenied
        case .denied:
            cameraState = .permissionDenied
        case .restricted:
            cameraState = .restricted
        @unknown default:
            cameraState = .unavailable
        }
    }

    private func handle(rawPayload: String) {
        guard completedPayload == nil else { return }

        guard let payload = AgentQRCodePayload(rawValue: rawPayload) else {
            showError("This QR code doesn’t contain a valid agent link.")
            return
        }

        complete(with: payload)
    }

    private func complete(with payload: AgentQRCodePayload) {
        guard completedPayload == nil else { return }
        setTorch(enabled: false, reportFailure: false)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            notice = nil
            completedPayload = payload
        }
        successFeedbackTrigger += 1
    }

    private func readQRCode(from item: PhotosPickerItem) async {
        guard completedPayload == nil else { return }
        isReadingPhoto = true
        defer {
            isReadingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showError("The selected photo couldn’t be loaded.")
                return
            }

            var request = DetectBarcodesRequest()
            request.symbologies = [.qr]
            let rawPayloads = try await request.perform(on: data).compactMap(\.payloadString)

            if let validPayload = rawPayloads.compactMap(AgentQRCodePayload.init(rawValue:)).first {
                complete(with: validPayload)
            } else if rawPayloads.isEmpty {
                showError("No QR code was found in that photo.")
            } else {
                showError("The photo contains a QR code, but it isn’t a valid agent link.")
            }
        } catch {
            showError("The QR code in that photo couldn’t be read.")
        }
    }

    private func handleCameraUnavailable() {
        setTorch(enabled: false, reportFailure: false)
        cameraState = .unavailable
        showError("The camera became unavailable. You can retry or choose a photo.")
    }

    private func showError(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            notice = ScannerNotice(message: message)
        }
        errorFeedbackTrigger += 1
    }

    private func setTorch(enabled: Bool, reportFailure: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            torchEnabled = false
            return
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if enabled {
                try device.setTorchModeOn(level: min(0.5, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                device.torchMode = .off
            }
            torchEnabled = enabled
        } catch {
            torchEnabled = false
            if reportFailure {
                showError("The flashlight isn’t available right now.")
            }
        }
    }
}

private extension AgentQRCodeScannerView {
    enum CameraState: Equatable {
        case checking
        case requestingPermission
        case ready
        case permissionDenied
        case restricted
        case unsupported
        case unavailable

        var isLoading: Bool {
            self == .checking || self == .requestingPermission
        }

        var icon: String {
            switch self {
            case .permissionDenied:
                "camera.fill"
            case .restricted:
                "lock.fill"
            case .unsupported:
                "iphone.slash"
            case .unavailable:
                "camera.metering.unknown"
            case .checking, .requestingPermission, .ready:
                "qrcode.viewfinder"
            }
        }

        var title: String {
            switch self {
            case .checking:
                "Preparing Camera"
            case .requestingPermission:
                "Camera Access"
            case .permissionDenied:
                "Camera Access Needed"
            case .restricted:
                "Camera Restricted"
            case .unsupported:
                "Live Scanning Unavailable"
            case .unavailable:
                "Camera Unavailable"
            case .ready:
                "Scan Agent"
            }
        }

        var message: String {
            switch self {
            case .checking:
                "Checking whether live scanning is available."
            case .requestingPermission:
                "Allow camera access to scan an agent QR code."
            case .permissionDenied:
                "Enable camera access in Settings, or choose a QR code from Photos."
            case .restricted:
                "Camera use is restricted on this device. You can still choose a QR code from Photos."
            case .unsupported:
                "This device doesn’t support live scanning. Choose a QR code image from Photos instead."
            case .unavailable:
                "The camera is temporarily unavailable. Try again, or choose a QR code from Photos."
            case .ready:
                "Align the QR code inside the frame."
            }
        }
    }

    struct ScannerNotice: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }
}

private struct AgentQRCodeCameraView: UIViewControllerRepresentable {
    var isScanning: Bool
    var onCode: (String) -> Void
    var onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onUnavailable: onUnavailable)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        let coordinator = context.coordinator
        Task { @MainActor [weak scanner, weak coordinator] in
            await Task.yield()
            guard let scanner, let coordinator else { return }
            coordinator.updateScanning(isScanning, on: scanner)
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        context.coordinator.onUnavailable = onUnavailable
        context.coordinator.updateScanning(isScanning, on: scanner)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        var onUnavailable: () -> Void

        init(onCode: @escaping (String) -> Void, onUnavailable: @escaping () -> Void) {
            self.onCode = onCode
            self.onUnavailable = onUnavailable
        }

        func updateScanning(_ shouldScan: Bool, on scanner: DataScannerViewController) {
            if shouldScan, !scanner.isScanning {
                do {
                    try scanner.startScanning()
                } catch {
                    onUnavailable()
                }
            } else if !shouldScan, scanner.isScanning {
                scanner.stopScanning()
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for case .barcode(let barcode) in addedItems {
                guard let payload = barcode.payloadStringValue else { continue }
                onCode(payload)
                break
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onUnavailable()
        }
    }
}

private struct ScannerReticle: View {
    var isAnimated: Bool

    @State private var scanLineAtBottom = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.08))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.26), lineWidth: 1)

            Canvas { context, size in
                let inset: CGFloat = 2
                let arm: CGFloat = 42
                let radius: CGFloat = 25
                var path = Path()

                path.move(to: CGPoint(x: inset, y: arm + radius))
                path.addLine(to: CGPoint(x: inset, y: radius))
                path.addQuadCurve(
                    to: CGPoint(x: radius, y: inset),
                    control: CGPoint(x: inset, y: inset)
                )
                path.addLine(to: CGPoint(x: arm + radius, y: inset))

                path.move(to: CGPoint(x: size.width - arm - radius, y: inset))
                path.addLine(to: CGPoint(x: size.width - radius, y: inset))
                path.addQuadCurve(
                    to: CGPoint(x: size.width - inset, y: radius),
                    control: CGPoint(x: size.width - inset, y: inset)
                )
                path.addLine(to: CGPoint(x: size.width - inset, y: arm + radius))

                path.move(to: CGPoint(x: size.width - inset, y: size.height - arm - radius))
                path.addLine(to: CGPoint(x: size.width - inset, y: size.height - radius))
                path.addQuadCurve(
                    to: CGPoint(x: size.width - radius, y: size.height - inset),
                    control: CGPoint(x: size.width - inset, y: size.height - inset)
                )
                path.addLine(to: CGPoint(x: size.width - arm - radius, y: size.height - inset))

                path.move(to: CGPoint(x: arm + radius, y: size.height - inset))
                path.addLine(to: CGPoint(x: radius, y: size.height - inset))
                path.addQuadCurve(
                    to: CGPoint(x: inset, y: size.height - radius),
                    control: CGPoint(x: inset, y: size.height - inset)
                )
                path.addLine(to: CGPoint(x: inset, y: size.height - arm - radius))

                context.stroke(
                    path,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
            }

            if isAnimated {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.onion, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 224, height: 2)
                    .shadow(color: Color.onion, radius: 5)
                    .offset(y: scanLineAtBottom ? 100 : -100)
            }
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                scanLineAtBottom = true
            }
        }
    }
}
