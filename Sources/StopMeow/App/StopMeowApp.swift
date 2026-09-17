import AppKit

@main
enum StopMeowApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 메뉴바 상주, Dock 아이콘 없음
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var overlay: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayWindowController()
        overlay?.showWindow(nil)
        menuBar = MenuBarController()
    }
}
