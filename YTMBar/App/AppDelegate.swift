import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }


    private let appState = AppState()
    private var statusBarController: StatusBarController?
    private var playerWindowController: PlayerWindowController?
    private var lyricsCoordinator: LyricsCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let bridge = JSBridge(appState: appState)
        let playerWC = PlayerWindowController(appState: appState, bridge: bridge)
        playerWindowController = playerWC

        lyricsCoordinator = LyricsCoordinator(appState: appState)
        statusBarController = StatusBarController(appState: appState, playerWindowController: playerWC)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
