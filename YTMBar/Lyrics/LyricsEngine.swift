import Foundation
import Combine

actor LyricsEngine {
    nonisolated let currentLinePublisher = CurrentValueSubject<String, Never>("")
    nonisolated let availablePublisher   = CurrentValueSubject<Bool, Never>(false)

    private var lines: [LyricLine] = []
    private var currentKey: String?
    private var cache: [String: [LyricLine]] = [:]
    private let captionsFetcher = YouTubeCaptionsFetcher()
    private let lrclibFetcher   = LRCLIBFetcher()

    // MARK: - Public Interface

    func trackChanged(videoId: String, title: String, artist: String) async {
        // Use videoId when available; fall back to "title|artist" so tracks
        // without a URL videoId still get a stable, unique cache key.
        let key = videoId.isEmpty ? "\(title)|\(artist)" : videoId
        guard key != currentKey else { return }

        currentKey = key
        lines = []
        currentLinePublisher.send("")
        availablePublisher.send(false)

        await fetchLyrics(key: key, videoId: videoId, title: title, artist: artist)
    }

    func updateCurrentLine(elapsedTime: TimeInterval) {
        guard !lines.isEmpty else { return }
        // If we have lyrics but elapsedTime hasn't advanced yet (< first timestamp),
        // show the very first line as a preview rather than nothing.
        let idx = binarySearch(timestamp: elapsedTime)
        let line = idx >= 0 ? lines[idx].text : lines[0].text
        if line != currentLinePublisher.value {
            currentLinePublisher.send(line)
        }
    }

    // MARK: - Private

    private func fetchLyrics(key: String, videoId: String, title: String, artist: String) async {
        if let cached = cache[key] {
            lines = cached
            availablePublisher.send(true)
            return
        }

        // 1. YouTube timedtext (requires valid videoId + YTM session cookies via URLSession —
        //    often returns 403; LRCLIB is the reliable path)
        if !videoId.isEmpty, let fetched = await captionsFetcher.fetch(videoId: videoId) {
            store(fetched, for: key); return
        }

        // 2. LRCLIB — no auth, excellent coverage for popular tracks
        if let fetched = await lrclibFetcher.fetch(title: title, artist: artist) {
            store(fetched, for: key); return
        }

        // 3. One retry after 3 s in case of transient network failure
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if let fetched = await lrclibFetcher.fetch(title: title, artist: artist) {
            store(fetched, for: key); return
        }

        availablePublisher.send(false)
    }

    private func store(_ fetched: [LyricLine], for key: String) {
        cache[key] = fetched
        lines = fetched
        availablePublisher.send(true)
    }

    private func binarySearch(timestamp: TimeInterval) -> Int {
        var lo = 0, hi = lines.count - 1, result = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].timestamp <= timestamp {
                result = mid; lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return result
    }
}
