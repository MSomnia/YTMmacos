import WebKit

final class JSBridge: NSObject {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Injection Script

    static func makeUserScript(selectors: [String: String]) -> WKUserScript {
        let title    = selectors["title"]    ?? "yt-formatted-string.title"
        let artist   = selectors["artist"]   ?? "yt-formatted-string.byline"
        let playPause = selectors["playPause"] ?? ".play-pause-button"
        let player   = selectors["player"]   ?? "ytmusic-player"

        let source = """
        (function() {
            if (window.__ytmBarInjected) return;
            window.__ytmBarInjected = true;

            setInterval(function() {
                try {
                    var titleEl   = document.querySelector('\(title)');
                    var artistEl  = document.querySelector('\(artist)');
                    var playBtn   = document.querySelector('\(playPause)');
                    var playerEl  = document.querySelector('\(player)');

                    var urlParams = new URLSearchParams(window.location.search);
                    var videoId   = urlParams.get('v') || '';

                    var payload = {
                        title:       titleEl  ? titleEl.textContent.trim()  : '',
                        artist:      artistEl ? artistEl.textContent.trim() : '',
                        isPlaying:   playBtn  ? playBtn.getAttribute('aria-label') === 'Pause' : false,
                        currentTime: playerEl ? (playerEl.currentTime  || 0) : 0,
                        duration:    playerEl ? (playerEl.duration     || 0) : 0,
                        videoId:     videoId
                    };

                    window.webkit.messageHandlers.ytmBridge.postMessage(JSON.stringify(payload));
                } catch(e) {}
            }, 500);
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}

// MARK: - WKScriptMessageHandler

extension JSBridge: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "ytmBridge",
              let body = message.body as? String,
              let data = body.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        Task { @MainActor [weak self] in
            self?.appState?.update(from: payload)
        }
    }
}
