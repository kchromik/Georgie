import SwiftUI
import AVFoundation

struct CameraViewerView: View {
    @Bindable var instance: WidgetInstance
    @State private var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            switch authorization {
            case .authorized:
                CameraPreviewRepresentable()
            case .notDetermined:
                WidgetPlaceholder(
                    symbol: "camera",
                    title: "Enable Camera",
                    subtitle: "Georgie will ask for camera access in a moment."
                )
                .task { await requestAccess() }
            case .denied, .restricted:
                deniedView
            @unknown default:
                deniedView
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            WidgetPlaceholder(
                symbol: "camera.metering.none",
                title: "No camera access",
                subtitle: "Allow access in System Settings under Privacy & Security."
            )
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
            .padding(.bottom)
        }
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorization = granted ? .authorized : .denied
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.start()
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.stop()
    }
}

final class CameraPreviewNSView: NSView {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.kchromik.Georgie.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer?.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    func start() {
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.beginConfiguration()
            session.sessionPreset = .high

            if let device = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}
