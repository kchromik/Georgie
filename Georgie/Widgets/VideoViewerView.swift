import SwiftUI
import AVKit

struct VideoViewerView: View {
    @Bindable var instance: WidgetInstance

    var body: some View {
        Group {
            if instance.fileURL != nil {
                VideoPlayerRepresentable(instance: instance)
            } else {
                WidgetPlaceholder(
                    symbol: "film",
                    title: "No video loaded",
                    subtitle: "Drag a video file here or open one from the menu."
                )
            }
        }
    }
}

private struct VideoPlayerRepresentable: NSViewRepresentable {
    @Bindable var instance: WidgetInstance

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.allowsPictureInPicturePlayback = true
        view.videoGravity = .resizeAspect
        load(into: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let version = instance.contentVersion
        if context.coordinator.loadedVersion != version {
            context.coordinator.loadedVersion = version
            load(into: nsView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        nsView.player?.pause()
        nsView.player = nil
        coordinator.player = nil
    }

    private func load(into view: AVPlayerView, coordinator: Coordinator) {
        guard let url = instance.fileURL else { return }
        let player = AVPlayer(url: url)
        view.player = player
        coordinator.player = player
    }

    final class Coordinator {
        var player: AVPlayer?
        var loadedVersion = 0
    }
}
