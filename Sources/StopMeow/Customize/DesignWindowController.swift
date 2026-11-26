import AppKit
import SwiftUI

/// 메뉴바 "멈춰묘 설정…"로 여는 큰 창. 디자인/이름/생산성/숏폼 탭이 들어있고,
/// 갤러리 탭은 로드맵 4단계 이후 이 창에 추가될 예정.
final class DesignWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "멈춰묘 설정"
        window.minSize = NSSize(width: 800, height: 530)
        // 타이틀바를 크림 배경과 이어지게 해서 커스텀 테마(CuteTheme)가 창 전체를 감싸는 느낌을 준다.
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
        window.center()
        window.contentView = NSHostingView(rootView: BigWindowView())
        self.init(window: window)
        window.delegate = self
    }

    /// 창을 닫으면 내용 뷰를 새로 만들어, 저장 안 한 디자인 초안을 버리고 원래 고양이로 되돌린다.
    func windowWillClose(_ notification: Notification) {
        window?.contentView = NSHostingView(rootView: BigWindowView())
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
