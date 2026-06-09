import SwiftUI
import AVFoundation

struct CameraViewerView: View {
    @Bindable var instance: WidgetInstance
    @State private var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var hovering = false

    var body: some View {
        Group {
            switch authorization {
            case .authorized:
                cameraView
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

    private var cameraView: some View {
        CameraPreviewRepresentable(deviceID: instance.cameraDeviceID)
            .overlay(alignment: .bottomLeading) {
                sourcePicker
                    .padding(8)
                    .opacity(hovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: hovering)
            }
            .onHover { hovering = $0 }
    }

    private var sourcePicker: some View {
        Menu {
            let sources = CameraSource.available()
            if sources.isEmpty {
                Text("No cameras found")
            } else {
                ForEach(sources) { source in
                    Button {
                        instance.cameraDeviceID = source.id
                    } label: {
                        if source.id == selectedID {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "camera.rotate")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 30, height: 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Switch camera source")
    }

    private var selectedID: String? {
        instance.cameraDeviceID ?? AVCaptureDevice.default(for: .video)?.uniqueID
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

struct CameraSource: Identifiable {
    let id: String
    let name: String

    static func available() -> [CameraSource] {
        discoverySession.devices.map { CameraSource(id: $0.uniqueID, name: $0.localizedName) }
    }

    static func device(for id: String?) -> AVCaptureDevice? {
        guard let id else { return nil }
        return discoverySession.devices.first { $0.uniqueID == id }
    }

    private static var discoverySession: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    let deviceID: String?

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.start(deviceID: deviceID)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.update(deviceID: deviceID)
    }

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.stop()
    }
}

final class CameraPreviewNSView: NSView {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.kchromik.Georgie.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDeviceID: String?

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

    func start(deviceID: String?) {
        currentDeviceID = deviceID
        sessionQueue.async { [weak self, session] in
            guard let self else { return }
            guard !session.isRunning else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            self.applyDevice(deviceID)
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func update(deviceID: String?) {
        guard deviceID != currentDeviceID else { return }
        currentDeviceID = deviceID
        sessionQueue.async { [weak self, session] in
            guard let self else { return }
            session.beginConfiguration()
            for input in session.inputs {
                session.removeInput(input)
            }
            self.applyDevice(deviceID)
            session.commitConfiguration()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func applyDevice(_ deviceID: String?) {
        guard let device = CameraSource.device(for: deviceID) ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }
}
