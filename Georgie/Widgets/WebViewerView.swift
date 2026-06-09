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
            if !instance.urlString.isEmpty {
                addressField = instance.urlString
                model.load(instance.urlString)
            } else {
                addressFocused = true
            }
        }
        .onChange(of: instance.contentVersion) {

            if instance.urlString != model.currentURL {
                addressField = instance.urlString
                model.load(instance.urlString)
            }
        }
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
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.top, 28)
        .padding(.bottom, 6)
        .background(.bar)
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

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
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
}
