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
                Text(displayText)
                    .font(.system(size: 12))
                    .italic(!appState.lyricsAvailable && appState.currentTrack != nil)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 220, alignment: .leading)
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

    private var displayText: String {
        if !appState.currentLyricLine.isEmpty {
            return appState.currentLyricLine
        }
        if let track = appState.currentTrack {
            return "\(track.title) — \(track.artist)"
        }
        return "YouTube Music"
    }
}
