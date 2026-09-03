import SwiftUI
import WebKit

/// Hosts the bundled HTML game in a WKWebView and installs the JS bridge.
struct GameView: UIViewRepresentable {
    func makeCoordinator() -> GameBridge { GameBridge() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let content = WKUserContentController()
        content.add(context.coordinator, name: GameBridge.channel)
        config.userContentController = content

        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.043, green: 0.208, blue: 0.314, alpha: 1) // --deepsea
        web.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = web

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            web.loadHTMLString("<h1 style='font-family:-apple-system;color:#fff;background:#0B3550;padding:40px'>web/index.html is missing from the bundle — run ios/sync-web.sh</h1>", baseURL: nil)
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: GameBridge) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: GameBridge.channel)
    }
}
