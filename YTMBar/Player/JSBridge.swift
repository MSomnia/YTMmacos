import WebKit

final class JSBridge: NSObject {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Injection Script

    static func makeUserScript(selectors: [String: String]) -> WKUserScript {
        let source = """
        (function() {
            if (window.__ytmBarInjected) return;
            window.__ytmBarInjected = true;

            function getPayload() {
                // Scope all queries to ytmusic-player-bar to avoid matching
                // search results or page headings.
                var bar = document.querySelector('ytmusic-player-bar');

                var titleEl = bar && (
                    bar.querySelector('.content-info-wrapper .title yt-formatted-string') ||
                    bar.querySelector('.title yt-formatted-string') ||
                    bar.querySelector('.title')
                );
                // Byline contains "Artist • Album" — split to get both fields
                var bylineEl = bar && (
                    bar.querySelector('.content-info-wrapper .byline yt-formatted-string') ||
                    bar.querySelector('.byline yt-formatted-string') ||
                    bar.querySelector('.byline')
                );
                var bylineParts = bylineEl
                    ? bylineEl.textContent.split('•').map(function(s) { return s.trim(); })
                    : [];
                var artist = bylineParts[0] || '';
                var album  = bylineParts[1] || '';

                // ytmusic-player — try playerApi first (most reliable)
                var ytPlayer = document.querySelector('ytmusic-player');
                var api = ytPlayer && ytPlayer.playerApi;

                // Play state
                var isPlaying = false;
                if (api && typeof api.getPlayerState === 'function') {
                    try { isPlaying = api.getPlayerState() === 1; } catch(e) {}
                }
                if (!isPlaying) {
                    var playBtn = bar && (
                        bar.querySelector('#play-pause-button') ||
                        bar.querySelector('.play-pause-button')
                    );
                    if (playBtn) {
                        isPlaying = playBtn.getAttribute('aria-label') === 'Pause'
                                 || playBtn.getAttribute('title') === 'Pause';
                    }
                }

                // Current time
                var currentTime = 0;
                if (api && typeof api.getCurrentTime === 'function') {
                    try { currentTime = api.getCurrentTime() || 0; } catch(e) {}
                }
                if (!currentTime && ytPlayer) {
                    currentTime = ytPlayer.currentTime || 0;
                }

                // Duration
                var duration = 0;
                if (api && typeof api.getDuration === 'function') {
                    try { duration = api.getDuration() || 0; } catch(e) {}
                }
                if (!duration && ytPlayer) {
                    duration = ytPlayer.duration || 0;
                }

                // videoId: URL param first, then player element attribute
                var videoId = new URLSearchParams(window.location.search).get('v') || '';
                if (!videoId && ytPlayer) {
                    videoId = ytPlayer.getAttribute('video-id') || ytPlayer.videoId || '';
                }
                if (!videoId && bar) {
                    // Some YTM builds store it on the player bar
                    videoId = bar.getAttribute('video-id') || '';
                }

                return {
                    title:       titleEl ? titleEl.textContent.trim() : '',
                    artist:      artist,
                    album:       album,
                    isPlaying:   isPlaying,
                    currentTime: currentTime,
                    duration:    duration,
                    videoId:     videoId
                };
            }

            setInterval(function() {
                try {
                    window.webkit.messageHandlers.ytmBridge.postMessage(
                        JSON.stringify(getPayload())
                    );
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
