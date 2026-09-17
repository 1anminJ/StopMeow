import AppKit
import SwiftUI

/// 클릭 드래그로 오버레이 윈도우 자체를 옮기는 호스팅 뷰.
/// 몸통을 드래그하면 창이 따라오고(Drag), 머리를 클릭+드래그하면 제자리에서 쓰다듬기(골골) 반응만 한다.
final class DraggableCatHostingView: NSHostingView<CatView> {
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onPetStart: (() -> Void)?
    var onPetEnd: (() -> Void)?

    private enum Interaction { case none, dragging, petting }
    private var interaction: Interaction = .none

    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero

    /// 스프라이트 상단 60%(귀~코 부근)를 머리 존으로 취급.
    private let headZoneRatio: CGFloat = 0.6

    private func isInHeadZone(_ point: NSPoint) -> Bool {
        let headHeight = bounds.height * headZoneRatio
        return isFlipped ? point.y <= headHeight : point.y >= bounds.height - headHeight
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if isInHeadZone(local) {
            interaction = .petting
            onPetStart?()
        } else {
            interaction = .dragging
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = window?.frame.origin ?? .zero
            onDragStart?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard interaction == .dragging else { return } // 쓰다듬는 동안은 창을 옮기지 않음
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouseLocation.x
        let dy = current.y - dragStartMouseLocation.y
        window?.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + dx, y: dragStartWindowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .dragging: onDragEnd?()
        case .petting: onPetEnd?()
        case .none: break
        }
        interaction = .none
    }
}
