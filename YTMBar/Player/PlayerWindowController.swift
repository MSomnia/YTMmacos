import Cocoa
import WebKit

final class PlayerWindowController: NSObject {
    private var window: NSWindow?
    private var webView: WKWebView?

    private let appState: AppState
    private let bridge: JSBridge

    init(appState: AppState, bridge: JSBridge) {
        self.appState = appState
        self.bridge = bridge
    }

    // MARK: - Window Visibility

    func toggleWindow() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        if window == nil { buildWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window Construction

    private func buildWindow() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let ucc = config.userContentController
        ucc.add(bridge, name: "ytmBridge")
        ucc.addUserScript(JSBridge.makeUserScript(selectors: loadSelectors()))

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = self
        wv.uiDelegate = self
        // Full desktop Safari UA — prevents Google from blocking OAuth in embedded WebView
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        webView = wv

        let frame = savedFrame() ?? NSRect(x: 200, y: 200, width: 1024, height: 680)
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "YouTube Music"
        win.minSize = NSSize(width: 800, height: 600)
        win.contentView = wv
        win.delegate = self
        win.level = .floating
        win.isReleasedWhenClosed = false
        window = win

        wv.load(URLRequest(url: URL(string: "https://music.youtube.com")!))
    }

    // MARK: - Playback Commands

    func togglePlayPause() {
        webView?.evaluateJavaScript("""
            (document.querySelector('ytmusic-player-bar #play-pause-button') ||
             document.querySelector('ytmusic-player-bar .play-pause-button'))?.click()
            """, completionHandler: nil)
    }

    func nextTrack() {
        webView?.evaluateJavaScript("""
            (document.querySelector('ytmusic-player-bar .next-button') ||
             document.querySelector('ytmusic-player-bar #next-button'))?.click()
            """, completionHandler: nil)
    }

    func previousTrack() {
        webView?.evaluateJavaScript("""
            (document.querySelector('ytmusic-player-bar .previous-button') ||
             document.querySelector('ytmusic-player-bar #previous-button'))?.click()
            """, completionHandler: nil)
    }

    // MARK: - Frame Persistence

    private func savedFrame() -> NSRect? {
        guard let data = UserDefaults.standard.data(forKey: "playerWindowFrame"),
              let rect = try? JSONDecoder().decode(CGRect.self, from: data)
        else { return nil }
        return rect
    }

    private func persistFrame(_ frame: NSRect) {
        if let data = try? JSONEncoder().encode(frame) {
            UserDefaults.standard.set(data, forKey: "playerWindowFrame")
        }
    }

    // MARK: - Selectors

    private func loadSelectors() -> [String: String] {
        let candidates: [URL?] = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("Selectors.plist"),
            Bundle.main.url(forResource: "Selectors", withExtension: "plist")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let dict = NSDictionary(contentsOf: url) as? [String: String] {
                return dict
            }
        }
        return [:]
    }
}

// MARK: - NSWindowDelegate

extension PlayerWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        if let f = window?.frame { persistFrame(f) }
    }
    func windowDidMove(_ notification: Notification) {
        if let f = window?.frame { persistFrame(f) }
    }
}

// MARK: - WKNavigationDelegate

extension PlayerWindowController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              let host = url.host
        else { decisionHandler(.allow); return }

        if Self.isInternalHost(host) {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    // Domains that must stay inside the WebView (auth + content)
    private static func isInternalHost(_ host: String) -> Bool {
        let internalDomains = [
            "youtube.com",      // music.youtube.com, accounts.youtube.com, www.youtube.com
            "google.com",       // accounts.google.com, www.google.com, signin.google.com
            "googleapis.com",   // Google API endpoints used during auth
            "gstatic.com",      // Google static assets (fonts, images) needed for login UI
            "googlevideo.com",  // YouTube video/audio streaming
            "ggpht.com",        // Google user photos
        ]
        return internalDomains.contains(where: { host == $0 || host.hasSuffix("." + $0) })
    }
}

// MARK: - WKUIDelegate

extension PlayerWindowController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url,
              let host = url.host
        else { return nil }

        if Self.isInternalHost(host) {
            // Auth popup (e.g. accounts.youtube.com/accounts/CheckConnection):
            // load in the same WebView so cookies/session are preserved.
            webView.load(navigationAction.request)
        } else {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}
