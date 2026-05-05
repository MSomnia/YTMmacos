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
        config.applicationNameForUserAgent = "YTMBar/1.0 Safari/605.1.15"
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let ucc = config.userContentController
        ucc.add(bridge, name: "ytmBridge")
        ucc.addUserScript(JSBridge.makeUserScript(selectors: loadSelectors()))

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = self
        wv.uiDelegate = self
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
        webView?.evaluateJavaScript(
            "document.querySelector('.play-pause-button')?.click()", completionHandler: nil)
    }

    func nextTrack() {
        webView?.evaluateJavaScript(
            "document.querySelector('.next-button')?.click()", completionHandler: nil)
    }

    func previousTrack() {
        webView?.evaluateJavaScript(
            "document.querySelector('.previous-button')?.click()", completionHandler: nil)
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
        guard let host = navigationAction.request.url?.host else {
            decisionHandler(.allow); return
        }
        let allowed = ["music.youtube.com", "accounts.google.com", "www.google.com"]
        if allowed.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            decisionHandler(.allow)
        } else {
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
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
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}
