import AppKit
import SwiftUI

/// 고양이 렌더링 전용 오버레이 윈도우. 항상 최상위, 배경 투명, 모든 스페이스에 표시.
/// 메뉴바 팝오버의 "고양이 표시" 토글에 따라 보이거나 완전히 멈춘다 (메뉴바 아이콘은 별개로 항상 유지됨).
final class OverlayWindowController: NSWindowController {
    private let animationState = CatAnimationState()
    private var wanderEngine: CatWanderEngine?
    private var settingsObserver: NSObjectProtocol?
    private var isCatEnabled = true

    convenience init() {
        // 높이에 jumpHeadroomRows만큼 여유를 둬서 스페이스바 점프가 위로 튈 때 안 잘리게 함.
        let size = NSSize(
            width: CGFloat(CatSprite.width) * CatSprite.pixelSize,
            height: CGFloat(CatSprite.heightRows + CatSprite.jumpHeadroomRows) * CatSprite.pixelSize
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false // 드래그를 받으려면 클릭을 가로채야 함

        self.init(window: window)

        let engine = CatWanderEngine(window: window, state: animationState)
        let hostingView = DraggableCatHostingView(rootView: CatView(state: animationState))
        hostingView.onDragStart = { [weak self] in
            self?.animationState.isDragging = true
            engine.startExternalDrag()
        }
        hostingView.onDragEnd = { [weak self] in
            self?.animationState.isDragging = false
            engine.endExternalDrag()
        }

        hostingView.frame = NSRect(origin: .zero, size: size)
        window.contentView = hostingView
        wanderEngine = engine

        applyCatEnabledSetting(initial: true)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCatEnabledSetting(initial: false)
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    /// "고양이 표시" 토글 반영. UserDefaults 변경 알림은 다른 설정에도 뜨므로,
    /// 값이 실제로 바뀌었을 때만 창/엔진을 건드린다.
    private func applyCatEnabledSetting(initial: Bool) {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.catEnabled)
        guard initial || enabled != isCatEnabled else { return }
        isCatEnabled = enabled
        if enabled {
            window?.orderFront(nil)
            wanderEngine?.start()
        } else {
            window?.orderOut(nil)
            wanderEngine?.stop()
        }
    }
}
