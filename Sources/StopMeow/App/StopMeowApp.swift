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
        SettingsKey.registerDefaults()
        // 타이핑 감지(NSEvent 전역 키 모니터링)에는 손쉬운 사용 권한만 있으면 됨.
        // (입력 모니터링은 CGEventTap 등 더 저수준 후킹에 쓰이는 별개 권한 — 여기선 불필요)
        requestAccessibilityPermissionIfNeeded()
        // OverlayWindowController가 "고양이 표시" 설정에 따라 스스로 보이거나 숨는다.
        overlay = OverlayWindowController()
        menuBar = MenuBarController()
    }

    /// 손쉬운 사용 권한이 없으면 시스템 설정으로 안내하는 대화상자를 띄운다.
    /// scripts/build-app.sh가 고정된 로컬 인증서("StopMeow Dev")로 서명하므로,
    /// 한 번 허용해두면 재빌드해도 권한이 유지된다.
    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
