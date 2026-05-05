import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentLyricLine = ""
    @Published var lyricsAvailable = false

    func update(from payload: [String: Any]) {
        let title   = (payload["title"]  as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artist  = (payload["artist"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let album   = (payload["album"]  as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let videoId = payload["videoId"] as? String ?? ""

        let newTrack = title.isEmpty ? nil : Track(title: title, artist: artist, album: album, videoId: videoId)
        if newTrack != currentTrack {
            currentTrack = newTrack
            currentLyricLine = ""
            lyricsAvailable = false
        }

        isPlaying = payload["isPlaying"] as? Bool ?? false
        elapsedTime = payload["currentTime"] as? TimeInterval ?? 0
        duration = payload["duration"] as? TimeInterval ?? 0
    }
}
