import AppKit
import SwiftUI

/// 메뉴바 "디자인 열기"로 여는 큰 창. 지금은 디자인 커스텀만 실제로 들어있고,
/// 갤러리/이름 설정/생산성 설정 탭은 로드맵 4단계 이후 이 창에 추가될 예정.
final class DesignWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "멈춰묘 디자인"
        window.minSize = NSSize(width: 800, height: 480)
        // 타이틀바를 크림 배경과 이어지게 해서 커스텀 테마(CuteTheme)가 창 전체를 감싸는 느낌을 준다.
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
        window.center()
        window.contentView = NSHostingView(rootView: PixelZoneEditorView())
        self.init(window: window)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
