import SwiftUI
@preconcurrency import WebKit

struct WebViewerView: View {
    @Bindable var instance: WidgetInstance
    @State private var model = WebViewModel()
    @State private var addressField = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            WebViewRepresentable(model: model)
        }
        .onAppear {
            model.onAddressChange = { instance.urlString = $0 }
            model.setZoom(instance.webZoom)
            model.setReloadInterval(instance.webReloadInterval)
            if !instance.urlString.isEmpty {
                addressField = instance.urlString
                model.load(instance.urlString)
            } else {
                addressFocused = true
            }
        }
        .onDisappear { model.setReloadInterval(0) }
        .onChange(of: instance.contentVersion) {

            if instance.urlString != model.currentURL {
                addressField = instance.urlString
                model.load(instance.urlString)
            }
        }
        .onChange(of: instance.webZoom) { model.setZoom(instance.webZoom) }
        .onChange(of: instance.webReloadInterval) { model.setReloadInterval(instance.webReloadInterval) }
        .onChange(of: model.currentURL) {
            if !addressFocused { addressField = model.currentURL }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack)
            Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward)
            Button {
                model.isLoading ? model.stop() : model.reload()
            } label: {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }

            TextField("Address or search", text: $addressField)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .focused($addressFocused)
                .onSubmit {
                    model.load(addressField)
                    addressFocused = false
                }

            actionMenu
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.top, 28)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private static let reloadIntervals: [(label: LocalizedStringKey, seconds: Double)] = [
        ("Off", 0),
        ("Every 5s", 5),
        ("Every 15s", 15),
        ("Every 30s", 30),
        ("Every 1 min", 60),
        ("Every 5 min", 300),
    ]

    private var actionMenu: some View {
        Menu {
            Section("Zoom") {
                Button { setZoom(instance.webZoom - 0.1) } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                Button { instance.webZoom = 1.0 } label: { Label("Actual Size (\(Int(instance.webZoom * 100))%)", systemImage: "1.magnifyingglass") }
                Button { setZoom(instance.webZoom + 0.1) } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
            }
            Section("Auto-Reload") {
                Picker("Auto-Reload", selection: $instance.webReloadInterval) {
                    ForEach(Self.reloadIntervals, id: \.seconds) { item in
                        Text(item.label).tag(item.seconds)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        } label: {
            Image(systemName: instance.webReloadInterval > 0 ? "ellipsis.circle.fill" : "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Zoom and auto-reload")
    }

    private func setZoom(_ value: Double) {
        instance.webZoom = min(3.0, max(0.5, (value * 10).rounded() / 10))
    }
}

@MainActor
@Observable
final class WebViewModel: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var currentURL = ""

    @ObservationIgnored var onAddressChange: ((String) -> Void)?
    @ObservationIgnored private var reloadTimer: Timer?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // Native element fullscreen lets WebKit take over the whole screen with
        // its own fullscreen window, which hard-locks the system when triggered
        // from a non-activating floating panel. Disable it and emulate the
        // Fullscreen API inside the web view's viewport instead.
        config.preferences.isElementFullscreenEnabled = false
        config.userContentController.addUserScript(WKUserScript(
            source: Self.fullscreenShim,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
    }

    func load(_ string: String) {
        guard let url = Self.normalizedURL(from: string) else { return }
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }

    func setZoom(_ zoom: Double) {
        webView.pageZoom = zoom
    }

    func setReloadInterval(_ seconds: Double) {
        reloadTimer?.invalidate()
        reloadTimer = nil
        guard seconds > 0 else { return }
        let timer = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.webView.reload() }
        }
        RunLoop.main.add(timer, forMode: .common)
        reloadTimer = timer
    }

    deinit {
        reloadTimer?.invalidate()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        syncState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        syncState()
    }

    private func syncState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        if let url = webView.url?.absoluteString {
            currentURL = url
            onAddressChange?(url)
        }
    }

    // Emulates the Fullscreen API (standard + webkit-prefixed) so sites like
    // YouTube can "go fullscreen" within the web view's bounds without WebKit
    // ever creating a system-level fullscreen window.
    private static let fullscreenShim = """
    (function () {
        'use strict';
        if (window.__georgieFullscreenShim) { return; }
        window.__georgieFullscreenShim = true;

        var CLS = '__georgie-fullscreen';
        var BODY_CLS = '__georgie-fullscreen-active';
        var current = null;

        function ensureStyle() {
            if (document.getElementById('__georgie-fs-style')) { return; }
            var s = document.createElement('style');
            s.id = '__georgie-fs-style';
            s.textContent =
                '.' + CLS + '{position:fixed !important;top:0 !important;left:0 !important;' +
                'right:0 !important;bottom:0 !important;width:100% !important;height:100% !important;' +
                'max-width:none !important;max-height:none !important;margin:0 !important;' +
                'padding:0 !important;border:none !important;border-radius:0 !important;' +
                'transform:none !important;z-index:2147483647 !important;background:#000 !important;}' +
                'body.' + BODY_CLS + '{overflow:hidden !important;}';
            (document.head || document.documentElement).appendChild(s);
        }

        function fire(target) {
            ['fullscreenchange', 'webkitfullscreenchange'].forEach(function (type) {
                try { (target || document).dispatchEvent(new Event(type, { bubbles: true })); } catch (e) {}
            });
            try { window.dispatchEvent(new Event('resize')); } catch (e) {}
        }

        function enter(el) {
            if (!(el instanceof Element)) { return Promise.reject(new TypeError('Not an element')); }
            if (current === el) { return Promise.resolve(); }
            if (current) { current.classList.remove(CLS); }
            ensureStyle();
            current = el;
            el.classList.add(CLS);
            if (document.body) { document.body.classList.add(BODY_CLS); }
            fire(el);
            return Promise.resolve();
        }

        function exit() {
            if (!current) { return Promise.resolve(); }
            var el = current;
            current = null;
            el.classList.remove(CLS);
            if (document.body) { document.body.classList.remove(BODY_CLS); }
            fire(el);
            return Promise.resolve();
        }

        Element.prototype.requestFullscreen = function () { return enter(this); };
        Element.prototype.webkitRequestFullscreen = function () { return enter(this); };
        Element.prototype.webkitRequestFullScreen = function () { return enter(this); };

        Document.prototype.exitFullscreen = function () { return exit(); };
        Document.prototype.webkitExitFullscreen = function () { return exit(); };
        Document.prototype.webkitCancelFullScreen = function () { return exit(); };

        var docProps = {
            fullscreenElement: function () { return current; },
            webkitFullscreenElement: function () { return current; },
            webkitCurrentFullScreenElement: function () { return current; },
            fullscreenEnabled: function () { return true; },
            webkitFullscreenEnabled: function () { return true; },
            fullscreen: function () { return current !== null; },
            webkitIsFullScreen: function () { return current !== null; }
        };
        Object.keys(docProps).forEach(function (name) {
            try {
                Object.defineProperty(Document.prototype, name, {
                    configurable: true,
                    get: docProps[name]
                });
            } catch (e) {}
        });

        if (window.HTMLVideoElement) {
            HTMLVideoElement.prototype.webkitEnterFullscreen = function () { enter(this); };
            HTMLVideoElement.prototype.webkitEnterFullScreen = function () { enter(this); };
            HTMLVideoElement.prototype.webkitExitFullscreen = function () { exit(); };
            HTMLVideoElement.prototype.webkitExitFullScreen = function () { exit(); };
            try {
                Object.defineProperty(HTMLVideoElement.prototype, 'webkitSupportsFullscreen', {
                    configurable: true, get: function () { return true; }
                });
                Object.defineProperty(HTMLVideoElement.prototype, 'webkitDisplayingFullscreen', {
                    configurable: true, get: function () { return this === current; }
                });
            } catch (e) {}
        }

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && current) {
                e.preventDefault();
                e.stopImmediatePropagation();
                exit();
            }
        }, true);
    })();
    """

    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.contains("."), !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }

        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://www.google.com/search?q=\(query)")
    }
}

private struct WebViewRepresentable: NSViewRepresentable {
    let model: WebViewModel

    func makeNSView(context: Context) -> WKWebView { model.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        nsView.pauseAllMediaPlayback(completionHandler: nil)
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
    }
}
