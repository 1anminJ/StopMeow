import AppKit
import ApplicationServices

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
        requestAccessibilityPermissionIfNeeded() // 타이핑 감지(전역 키 모니터링)에 필요
        overlay = OverlayWindowController()
        overlay?.showWindow(nil)
        menuBar = MenuBarController()
    }

    /// 손쉬운 사용 권한이 없으면 시스템 설정으로 안내하는 대화상자를 띄운다.
    /// ad-hoc 서명이라 다시 빌드하면 재승인이 필요할 수 있음 — 그럴 땐 앱을 재시작.
    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
