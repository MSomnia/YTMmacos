import SwiftUI
import AppKit

struct StatusBarView: View {
    @ObservedObject var appState: AppState

    let onToggleWindow: () -> Void
    let onTogglePlay: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 16)

            Button(action: onToggleWindow) {
                MarqueeText(
                    text: displayText,
                    containerWidth: 120,
                    italic: showingFallback,
                    speed: 30,
                    pauseAt: 1
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            controlButton(systemName: "backward.fill", action: onPrevious)
            controlButton(
                systemName: appState.isPlaying ? "pause.fill" : "play.fill",
                action: onTogglePlay
            )
            controlButton(systemName: "forward.fill", action: onNext)
        }
        .padding(.horizontal, 6)
        .frame(height: NSStatusBar.system.thickness)
        .contextMenu {
            Button("Open YouTube Music", action: onToggleWindow)
            Divider()
            Button("Quit YTMBar", action: onQuit)
        }
    }

    @ViewBuilder
    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }

    // True when showing track info instead of lyrics (triggers italic)
    private var showingFallback: Bool {
        appState.currentLyricLine.isEmpty && appState.currentTrack != nil
    }

    private var displayText: String {
        // Priority 1: current lyric line
        if !appState.currentLyricLine.isEmpty {
            return appState.currentLyricLine
        }
        // Priority 2: track info fallback
        if let track = appState.currentTrack {
            var text = "\(track.title) — \(track.artist)"
            if !track.album.isEmpty {
                text += " · \(track.album)"
            }
            return text
        }
        return "YouTube Music"
    }
}
