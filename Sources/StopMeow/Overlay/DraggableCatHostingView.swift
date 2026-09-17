import AppKit
import SwiftUI

/// 클릭 드래그로 오버레이 윈도우 자체를 옮기는 호스팅 뷰.
/// 쓰다듬기는 여기서 다루지 않음 — 클릭 없이 호버만으로 동작하며 CatWanderEngine이 처리한다.
final class DraggableCatHostingView: NSHostingView<CatView> {
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?

    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin ?? .zero
        onDragStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouseLocation.x
        let dy = current.y - dragStartMouseLocation.y
        window?.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + dx, y: dragStartWindowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}
