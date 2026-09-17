import AppKit
import SwiftUI

/// 숏폼 경고3(5분+): 화면 중앙에 고양이를 크게 띄워 시각적으로 방해한다.
/// 기획서 "고양이가 확대되며 화면을 가림"의 최소 구현 — 카드/버튼 없이 고양이만 확대해서 보여준다.
/// 클릭은 그대로 통과시켜서(ignoresMouseEvents) 실제로 조작을 막지는 않는다.
final class ShortformAlertWindowController: NSWindowController {
    private static let pixelSize: CGFloat = 56 // 평소 크기(8)의 7배 — 확실히 눈에 띄게

    convenience init() {
        let size = NSSize(
            width: CGFloat(CatSprite.width) * Self.pixelSize,
            height: CGFloat(CatSprite.heightRows) * Self.pixelSize
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(
            rootView: PixelSpriteView(rows: CatFrame.idleStand.rows(eyeLook: .center), pixelSize: Self.pixelSize)
        )
        window.center()
        self.init(window: window)
    }

    func show() {
        guard window?.isVisible != true else { return }
        window?.center()
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
