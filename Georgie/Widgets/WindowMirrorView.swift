import SwiftUI
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreGraphics
import OSLog

struct WindowMirrorView: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager

    @State private var service = WindowMirrorService()
    @State private var pickerWindows: [MirrorWindow] = []
    @State private var permissionDenied = false
    @State private var hovering = false

    var body: some View {
        Group {
            if instance.mirrorWindowID != nil {
                mirrorContent
            } else {
                picker
            }
        }
        .onDisappear { service.stop() }
    }

    private var mirrorContent: some View {
        MirrorLayerView(layer: service.displayLayer)
            .overlay {
                switch service.state {
                case .denied: permissionOverlay
                case .failed: failedOverlay
                default:      EmptyView()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                switchButton
                    .padding(8)
                    .opacity(hovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: hovering)
            }
            .onHover { hovering = $0 }
            .onAppear(perform: resumeIfNeeded)
    }

    private var switchButton: some View {
        Button {
            service.stop()
            instance.mirrorWindowID = nil
            instance.mirrorWindowTitle = nil
            instance.mirrorAppName = nil
        } label: {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 30, height: 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Mirror a different window")
    }

    private var failedOverlay: some View {
        VStack(spacing: 10) {
            WidgetPlaceholder(
                symbol: "macwindow.badge.plus",
                title: "Window unavailable",
                subtitle: "The mirrored window was closed or moved off-screen."
            )
            Button("Choose Another Window") {
                instance.mirrorWindowID = nil
            }
            .controlSize(.small)
            .padding(.bottom)
        }
    }

    private var permissionOverlay: some View {
        VStack(spacing: 10) {
            WidgetPlaceholder(
                symbol: "rectangle.dashed.badge.record",
                title: "Screen Recording needed",
                subtitle: "Allow Georgie to record the screen in System Settings, then reopen this window."
            )
            Button("Open System Settings") { Self.openScreenRecordingSettings() }
                .controlSize(.small)
                .padding(.bottom)
        }
    }

    private var picker: some View {
        VStack(spacing: 14) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Mirror a Window")
                .font(.headline)

            if permissionDenied {
                Text("Screen Recording permission is required to mirror other apps' windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Open System Settings") { Self.openScreenRecordingSettings() }
                    .controlSize(.small)
            } else {
                windowMenu
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task { await refreshPicker() }
    }

    private var windowMenu: some View {
        Menu {
            if pickerWindows.isEmpty {
                Text("No windows found")
            } else {
                ForEach(groupedByApp, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.value) { window in
                            Button(window.title) { select(window) }
                        }
                    }
                }
            }
            Divider()
            Button("Refresh") { Task { await refreshPicker() } }
        } label: {
            Label("Choose Window…", systemImage: "rectangle.on.rectangle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var groupedByApp: [(key: String, value: [MirrorWindow])] {
        Dictionary(grouping: pickerWindows, by: \.appName)
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    private func select(_ window: MirrorWindow) {
        instance.mirrorWindowID = window.id
        instance.mirrorAppName = window.appName
        instance.mirrorWindowTitle = window.title
        instance.title = window.title
        service.start(window: window.scWindow)
    }

    private func resumeIfNeeded() {
        guard let id = instance.mirrorWindowID, service.state == .idle else { return }
        Task {
            let windows = await WindowMirrorService.loadWindows()
            if let match = windows.first(where: { $0.id == id }) {
                service.start(window: match.scWindow)
            } else {
                service.markFailed()
            }
        }
    }

    private func refreshPicker() async {
        guard CGPreflightScreenCaptureAccess() else {
            permissionDenied = true
            _ = CGRequestScreenCaptureAccess()
            return
        }
        permissionDenied = false
        pickerWindows = await WindowMirrorService.loadWindows()
    }

    private static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct MirrorWindow: Identifiable {
    let id: CGWindowID
    let appName: String
    let title: String
    let scWindow: SCWindow
}

@Observable
final class WindowMirrorService: NSObject, SCStreamOutput, SCStreamDelegate {
    enum State { case idle, capturing, denied, failed }

    private(set) var state: State = .idle
    @ObservationIgnored let displayLayer = AVSampleBufferDisplayLayer()

    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private let outputQueue = DispatchQueue(label: "com.kchromik.Georgie.mirror")
    @ObservationIgnored private let log = Logger(subsystem: "com.kchromik.Georgie", category: "mirror")

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
    }

    static func loadWindows() async -> [MirrorWindow] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        else { return [] }
        let ownBundle = Bundle.main.bundleIdentifier
        return content.windows
            .filter { window in
                window.isOnScreen
                && window.frame.width > 80 && window.frame.height > 80
                && (window.title?.isEmpty == false)
                && window.owningApplication?.bundleIdentifier != ownBundle
            }
            .map {
                MirrorWindow(
                    id: $0.windowID,
                    appName: $0.owningApplication?.applicationName ?? "App",
                    title: $0.title ?? "Window",
                    scWindow: $0
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func start(window: SCWindow) {
        Task { await beginCapture(window: window) }
    }

    func stop() {
        Task { await stopCapture(resetState: true) }
    }

    func markFailed() {
        setState(.failed)
    }

    private func beginCapture(window: SCWindow) async {
        await stopCapture(resetState: false)

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        config.width = max(2, Int(window.frame.width * scale))
        config.height = max(2, Int(window.frame.height * scale))
        config.showsCursor = false
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
            try await stream.startCapture()
            self.stream = stream
            setState(.capturing)
        } catch {
            log.error("Window mirror failed to start: \(error.localizedDescription)")
            setState(isPermissionError(error) ? .denied : .failed)
        }
    }

    private func stopCapture(resetState: Bool) async {
        guard let stream else {
            if resetState { setState(.idle) }
            return
        }
        self.stream = nil
        try? await stream.stopCapture()
        displayLayer.sampleBufferRenderer.flush()
        if resetState { setState(.idle) }
    }

    private func setState(_ newState: State) {
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { self.state = newState }
        }
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SCStreamError.errorDomain
            && nsError.code == SCStreamError.Code.userDeclined.rawValue
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(sampleBuffer), isComplete(sampleBuffer) else { return }
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.requiresFlushToResumeDecoding { renderer.flush() }
        renderer.enqueue(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("Window mirror stopped: \(error.localizedDescription)")
        self.stream = nil
        setState(.failed)
    }

    private func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let rawStatus = info[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus)
        else { return false }
        return status == .complete
    }
}

private struct MirrorLayerView: NSViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> MirrorHostView {
        let view = MirrorHostView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.hostedLayer = layer
        layer.videoGravity = .resizeAspect
        view.layer?.addSublayer(layer)
        return view
    }

    func updateNSView(_ nsView: MirrorHostView, context: Context) {}
}

final class MirrorHostView: NSView {
    var hostedLayer: CALayer? {
        didSet { hostedLayer?.frame = bounds }
    }

    override func layout() {
        super.layout()
        hostedLayer?.frame = bounds
    }
}
