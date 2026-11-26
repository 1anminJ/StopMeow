import AppKit
import SwiftUI

/// 고양이 렌더링 전용 오버레이 윈도우. 항상 최상위, 배경 투명, 모든 스페이스에 표시.
/// 메뉴바 팝오버의 "고양이 표시" 토글에 따라 보이거나 완전히 멈춘다 (메뉴바 아이콘은 별개로 항상 유지됨).
final class OverlayWindowController: NSWindowController {
    private let animationState = CatAnimationState()
    private var wanderEngine: CatWanderEngine?
    private var settingsObserver: NSObjectProtocol?
    private var isCatEnabled = true
    private let shortformAlert = ShortformAlertWindowController()
    private let reminderWindow = ReminderWindowController()
    private let reminderBigAlert = ReminderBigAlertWindowController()
    private var pomodoroObserver: NSObjectProtocol?

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

        engine.onShortformWarn3Changed = { [weak self] isWarn3 in
            guard let self, self.isCatEnabled else { return }
            if isWarn3 {
                // 작은 고양이는 잠깐 사라지고 그 자리에 큰 고양이가 짠 나타나는 느낌으로.
                self.window?.orderOut(nil)
                self.shortformAlert.show()
            } else {
                self.shortformAlert.hide()
                self.window?.orderFront(nil)
            }
        }

        // 스트레칭/물 마시기: 숏폼 경고3처럼 작은 고양이를 숨기고 큰 고양이+문구를 띄운다.
        // 클릭하면(또는 일정 시간 후 자동으로) 큰 고양이가 사라지고 작은 고양이가 돌아온다.
        engine.onReminderFired = { [weak self] message in
            guard let self, self.isCatEnabled else { return }
            self.window?.orderOut(nil)
            self.reminderBigAlert.show(message: message) { [weak self] in
                guard let self, self.isCatEnabled else { return }
                self.window?.orderFront(nil)
            }
        }

        applyCatEnabledSetting(initial: true)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCatEnabledSetting(initial: false)
        }

        // 뽀모도로 완료(메뉴바가 관리) -> 축하 점프 + 배너. 서로 직접 참조하지 않고 알림으로만 연결.
        pomodoroObserver = NotificationCenter.default.addObserver(
            forName: PomodoroEngine.didCompleteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isCatEnabled else { return }
            self.animationState.jumpTrigger += 1 // 축하 점프는 스페이스바 토글과 무관하게 항상 재생
            self.reminderWindow.show(message: "뽀모도로 완료! 수고했어요 🎉")
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let pomodoroObserver {
            NotificationCenter.default.removeObserver(pomodoroObserver)
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
