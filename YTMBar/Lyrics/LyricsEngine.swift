import Foundation
import Combine

actor LyricsEngine {
    nonisolated let currentLinePublisher = CurrentValueSubject<String, Never>("")
    nonisolated let availablePublisher   = CurrentValueSubject<Bool, Never>(false)

    private var lines: [LyricLine] = []
    private var currentVideoId: String?
    private var cache: [String: [LyricLine]] = [:]
    private let captionsFetcher = YouTubeCaptionsFetcher()

    // MARK: - Public Interface

    func trackChanged(videoId: String, title: String, artist: String) async {
        guard videoId != currentVideoId else { return }
        currentVideoId = videoId
        lines = []
        currentLinePublisher.send("")
        availablePublisher.send(false)
        await fetchLyrics(videoId: videoId, title: title, artist: artist)
    }

    func updateCurrentLine(elapsedTime: TimeInterval) {
        guard !lines.isEmpty else { return }
        let idx = binarySearch(timestamp: elapsedTime)
        let line = idx >= 0 ? lines[idx].text : ""
        if line != currentLinePublisher.value {
            currentLinePublisher.send(line)
        }
    }

    // MARK: - Private

    private func fetchLyrics(videoId: String, title: String, artist: String) async {
        if let cached = cache[videoId] {
            lines = cached
            availablePublisher.send(true)
            return
        }

        // Retry once after 3 s on failure
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            if let fetched = await captionsFetcher.fetch(videoId: videoId) {
                cache[videoId] = fetched
                lines = fetched
                availablePublisher.send(true)
                return
            }
        }

        availablePublisher.send(false)
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
