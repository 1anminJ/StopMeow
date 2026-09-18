import AppKit
import SwiftUI

/// 메뉴바 "디자인 열기"로 여는 큰 창. 지금은 디자인 커스텀만 실제로 들어있고,
/// 갤러리/이름 설정/생산성 설정 탭은 로드맵 4단계 이후 이 창에 추가될 예정.
final class DesignWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "멈춰묘 디자인"
        window.center()
        window.contentView = NSHostingView(rootView: PixelZoneEditorView())
        self.init(window: window)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
