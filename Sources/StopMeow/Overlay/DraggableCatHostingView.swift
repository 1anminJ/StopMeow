import AppKit
import SwiftUI

/// 클릭 드래그로 오버레이 윈도우 자체를 옮기는 호스팅 뷰.
/// 머리든 몸이든 아무 데나 클릭하면 일단 쓰다듬기(제자리, 눈 감음)로 시작하고,
/// 일정 거리 이상 움직이면 그 순간부터 드래그(창이 따라옴)로 전환된다.
final class DraggableCatHostingView: NSHostingView<CatView> {
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onPetStart: (() -> Void)?
    var onPetEnd: (() -> Void)?

    private enum Interaction { case petting, dragging }
    private var interaction: Interaction = .petting

    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero

    // ponytail: 감으로 잡은 임계값. 너무 예민/둔감하면 조정.
    private let dragThreshold: CGFloat = 14 // px, 이 이상 움직이면 쓰다듬기 -> 드래그

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin ?? .zero
        interaction = .petting
        onPetStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouseLocation.x
        let dy = current.y - dragStartMouseLocation.y

        if interaction == .petting && (dx * dx + dy * dy).squareRoot() > dragThreshold {
            onPetEnd?()
            interaction = .dragging
            onDragStart?()
        }

        guard interaction == .dragging else { return }
        window?.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + dx, y: dragStartWindowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .dragging: onDragEnd?()
        case .petting: onPetEnd?()
        }
    }
}
