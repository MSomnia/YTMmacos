import Cocoa
import SwiftUI

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var hostingView: NSHostingView<StatusBarView>?

    private let appState: AppState
    private weak var playerWC: PlayerWindowController?

    init(appState: AppState, playerWindowController: PlayerWindowController) {
        self.appState = appState
        self.playerWC = playerWindowController

        statusItem = NSStatusBar.system.statusItem(withLength: 200)
        buildView()
    }

    private func buildView() {
        let view = StatusBarView(
            appState: appState,
            onToggleWindow: { [weak self] in self?.playerWC?.toggleWindow() },
            onTogglePlay:   { [weak self] in self?.playerWC?.togglePlayPause() },
            onPrevious:     { [weak self] in self?.playerWC?.previousTrack() },
            onNext:         { [weak self] in self?.playerWC?.nextTrack() },
            onQuit:         { NSApp.terminate(nil) }
        )

        let height = NSStatusBar.system.thickness
        let hv = NSHostingView(rootView: view)
        hv.frame = NSRect(x: 0, y: 0, width: 200, height: height)

        guard let button = statusItem.button else { return }
        button.frame = NSRect(x: 0, y: 0, width: 200, height: height)
        button.addSubview(hv)
        // Clear default action so SwiftUI buttons receive all left-click events.
        // Right-click is handled by SwiftUI's .contextMenu modifier.
        button.action = nil
        button.target = nil

        hostingView = hv
    }
}
