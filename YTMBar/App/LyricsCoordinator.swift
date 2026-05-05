import Foundation
import Combine

@MainActor
final class LyricsCoordinator {
    private let engine = LyricsEngine()
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        setupObservers()
        startTimer()
    }

    private func setupObservers() {
        appState.$currentTrack
            .removeDuplicates()
            .sink { [weak self] track in
                guard let self, let track, !track.videoId.isEmpty else { return }
                Task { [weak self] in
                    await self?.engine.trackChanged(
                        videoId: track.videoId,
                        title: track.title,
                        artist: track.artist
                    )
                }
            }
            .store(in: &cancellables)

        engine.currentLinePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] line in
                self?.appState.currentLyricLine = line
            }
            .store(in: &cancellables)

        engine.availablePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] available in
                self?.appState.lyricsAvailable = available
            }
            .store(in: &cancellables)
    }

    private func startTimer() {
        Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let elapsed = self.appState.elapsedTime
                Task { [weak self] in
                    await self?.engine.updateCurrentLine(elapsedTime: elapsed)
                }
            }
            .store(in: &cancellables)
    }
}
