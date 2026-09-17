import AppKit

/// Idle 상태의 기본 배회 로직 + 커서/키보드/숏폼 반응 오버라이드.
/// 쓰다듬기는 클릭 없이 커서가 고양이 위에 머무는 것만으로 발동(호버).
/// 우선순위: 드래그·쓰다듬기(일시정지) > 숏폼 경고 > 타이핑/과열 > 사냥 자세 > 평소 배회.
final class CatWanderEngine {
    private weak var window: NSWindow?
    private let state: CatAnimationState

    private enum Mode {
        case idle(until: Date)
        case walking(to: CGPoint)
    }

    private var mode: Mode = .idle(until: .distantPast) // 시작하자마자 첫 목적지를 고르게 함
    private var timer: Timer?
    private var walkTick = 0
    private var isPaused = false // 드래그/쓰다듬기 중에는 배회 이동을 멈춤
    private var isExternallyDragging = false // 실제 드래그 중엔 호버 쓰다듬기 판정을 끔

    private var lastCursor: CGPoint = NSEvent.mouseLocation
    private var lastCursorMoveAt = Date()

    private var lastHuntCursor: CGPoint = NSEvent.mouseLocation
    private var lastFastMoveAt = Date.distantPast
    private var isHunting = false
    private var huntTick = 0

    private let typingMonitor = TypingActivityMonitor()
    private var typingActivity: TypingActivityMonitor.Activity = .idle
    private var typingTick = 0

    private let shortformDetector = ShortformDetector()
    private var shortformWarnLevel = 0 {
        didSet {
            guard shortformWarnLevel != oldValue else { return }
            if shortformWarnLevel != 1 { cornerTarget = nil }
            shortformTick = 0
            onShortformWarn3Changed?(shortformWarnLevel == 3)
        }
    }
    private var cornerTarget: CGPoint?
    private var crossScreenGoingRight = true
    private var shortformTick = 0
    /// 경고3 진입/해제 시 호출 (OverlayWindowController가 큰 팝업을 띄우고 내리는 데 사용).
    var onShortformWarn3Changed: ((Bool) -> Void)?

    private let speed: CGFloat = 60 // px/초
    private let idleDuration: ClosedRange<TimeInterval> = 1.5...4.0
    private let screenMargin: CGFloat = 16
    private let tickInterval: TimeInterval = 1.0 / 30.0
    private let gazeTimeout: TimeInterval = 1.2 // 커서가 이만큼 멈춰 있으면 시선도 정면으로
    private let gazeDeadzone: CGFloat = 40 // px, 이 폭 안에서는 정면 유지
    // ponytail: 30Hz 폴링 기준 임계값이라 대략치. 실제 써보고 너무 자주/드물게 반응하면 조정.
    private let huntSpeedThreshold: CGFloat = 1200 // px/초 (수평 속도), 이보다 빠르면 "사냥감 포착"
    private let huntNearbyMarginY: CGFloat = 220 // 고양이 위/아래 이 거리 안에서만 반응
    private let huntNearbyMarginX: CGFloat = 260 // 고양이 좌우 이 거리 안에서만 반응
    private let huntGrace: TimeInterval = 0.35 // 마지막 빠른 움직임 후 이 시간 동안은 계속 사냥 자세

    init(window: NSWindow, state: CatAnimationState) {
        self.window = window
        self.state = state
    }

    func start() {
        typingMonitor.onSpacePressed = { [weak self] in
            guard UserDefaults.standard.bool(forKey: SettingsKey.jumpEnabled) else { return }
            self?.state.jumpTrigger += 1
        }
        typingMonitor.start()

        shortformDetector.onWarnLevelChange = { [weak self] level in
            self?.shortformWarnLevel = level
        }
        shortformDetector.start()

        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        typingMonitor.stop()
        shortformDetector.stop()
    }

    /// 기획서 상태머신 표에 대응하는 현재 상태. 내부 플래그들로부터 매 호출 시 계산.
    var currentState: CatState {
        switch shortformWarnLevel {
        case 3: return .shortformWarn3
        case 2: return .shortformWarn2
        case 1: return .shortformWarn1
        default: break
        }
        if isExternallyDragging { return .drag }
        if state.isPetting { return .pet }
        if typingActivity == .overheat { return .overheat }
        if typingActivity == .typing { return .typing }
        if isHunting { return .hunt }
        if state.eyeLook != .center { return .follow }
        return .idle
    }

    /// 실제 드래그(클릭+이동) 시작: 배회를 멈추고, 드래그 중엔 호버 쓰다듬기 판정도 끈다.
    func startExternalDrag() {
        isExternallyDragging = true
        state.isPetting = false
        isPaused = true
    }

    /// 드래그 종료: 잠깐 멈춰 있다가(흔들림 재생 시간) 다시 배회를 시작한다.
    func endExternalDrag() {
        isExternallyDragging = false
        resumeAfterInteraction()
    }

    /// 배회 이동 로직을 멈춘다 (시선 추적은 계속 동작).
    private func pause() {
        isPaused = true
    }

    /// 잠깐 멈춰 있다가(흔들림 재생 시간) 다시 배회를 시작한다.
    private func resumeAfterInteraction() {
        isPaused = false
        mode = .idle(until: Date().addingTimeInterval(0.4))
    }

    private func tick() {
        guard let window else { return }
        updateGaze(window: window)
        updatePetting(window: window)

        let wasOverridden = isHunting || typingActivity != .idle || shortformWarnLevel > 0

        if isPaused {
            // 드래그/쓰다듬기가 최우선 — 숏폼 경고 단계 자체는 유지하되 동작만 멈춘다.
            isHunting = false
            typingActivity = .idle
        } else if shortformWarnLevel > 0 {
            isHunting = false
            typingActivity = .idle
            updateShortformBehavior(window: window)
        } else {
            updateTyping()
            if typingActivity == .idle {
                updateHunt(window: window) // 타이핑 중엔 사냥 자세보다 타이핑 반응이 우선
            } else {
                isHunting = false
            }
        }

        let stillOverridden = isHunting || typingActivity != .idle || shortformWarnLevel > 0
        if wasOverridden && !stillOverridden {
            // 사냥/타이핑/숏폼 풀림: 다음 프레임을 즉시 정상 상태로 되돌려 포즈가 눌어붙지 않게 함
            if case .walking = mode { state.frame = .walk1 } else { state.frame = .idleStand }
        }

        guard !isPaused, !stillOverridden else { return }

        switch mode {
        case .idle(let until):
            if Date() >= until {
                pickNewTarget()
            }
        case .walking(let target):
            walkTick += 1
            state.frame = (walkTick / 5) % 2 == 0 ? .walk1 : .walk2

            let current = window.frame.origin
            let dx = target.x - current.x
            let dy = target.y - current.y
            let distance = (dx * dx + dy * dy).squareRoot()
            let step = speed * CGFloat(tickInterval)

            if distance <= step {
                window.setFrameOrigin(target)
                arrive()
            } else {
                let ratio = step / distance
                window.setFrameOrigin(CGPoint(x: current.x + dx * ratio, y: current.y + dy * ratio))
                if abs(dx) > 1 { state.facingRight = dx > 0 }
            }
        }
    }

    /// 클릭 없이 커서가 고양이 위에 올라와 있기만 해도 쓰다듬기로 취급한다.
    private func updatePetting(window: NSWindow) {
        guard !isExternallyDragging else { return } // 실제 드래그 중엔 무시(항상 커서 위에 있으니까)
        let hovering = window.frame.contains(NSEvent.mouseLocation)
        guard hovering != state.isPetting else { return }
        state.isPetting = hovering
        if hovering {
            pause()
        } else {
            resumeAfterInteraction()
        }
    }

    /// 커서가 최근에 움직였으면 그쪽으로 눈을 돌리고, 한동안 멈춰 있었으면 정면을 본다.
    private func updateGaze(window: NSWindow) {
        let cursor = NSEvent.mouseLocation
        if abs(cursor.x - lastCursor.x) > 1 || abs(cursor.y - lastCursor.y) > 1 {
            lastCursor = cursor
            lastCursorMoveAt = Date()
        }
        guard Date().timeIntervalSince(lastCursorMoveAt) < gazeTimeout else {
            state.eyeLook = .center
            return
        }
        let dx = cursor.x - window.frame.midX
        let rawLook: EyeLook = dx > gazeDeadzone ? .right : (dx < -gazeDeadzone ? .left : .center)
        state.eyeLook = state.facingRight ? rawLook : rawLook.flipped
    }

    /// 고양이 위/아래 근처에서 커서가 좌우로 빠르게 움직이면 몸을 낮추는 사냥 자세로 전환한다.
    private func updateHunt(window: NSWindow) {
        let cursor = NSEvent.mouseLocation
        let dx = cursor.x - lastHuntCursor.x
        let dy = cursor.y - lastHuntCursor.y
        lastHuntCursor = cursor

        let hSpeed = abs(dx) / CGFloat(tickInterval)
        let vSpeed = abs(dy) / CGFloat(tickInterval)

        let frame = window.frame
        let isAboveOrBelow =
            (cursor.y > frame.maxY && cursor.y < frame.maxY + huntNearbyMarginY) ||
            (cursor.y < frame.minY && cursor.y > frame.minY - huntNearbyMarginY)
        let isNearHorizontally = abs(cursor.x - frame.midX) < huntNearbyMarginX

        if isAboveOrBelow && isNearHorizontally && hSpeed > huntSpeedThreshold && hSpeed > vSpeed {
            lastFastMoveAt = Date()
        }
        isHunting = Date().timeIntervalSince(lastFastMoveAt) < huntGrace
        guard isHunting else { return }
        huntTick += 1
        state.frame = (huntTick / 4) % 2 == 0 ? .hunt1 : .hunt2
    }

    /// 숏폼 경고 단계별 동작. 1=구석에서 손짓, 2=화면을 가로지르며 방해, 3=큰 팝업(별도 창)이 담당.
    private func updateShortformBehavior(window: NSWindow) {
        switch shortformWarnLevel {
        case 1: moveToCornerAndWave(window: window)
        case 2: crossScreenDisrupt(window: window)
        default: break // 3단계는 ShortformAlertWindowController가 화면 중앙에서 처리
        }
    }

    private func moveToCornerAndWave(window: NSWindow) {
        if cornerTarget == nil {
            cornerTarget = nearestCorner(window: window)
        }
        guard let target = cornerTarget else { return }

        let current = window.frame.origin
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = (dx * dx + dy * dy).squareRoot()

        shortformTick += 1
        if distance > 2 {
            let step = speed * CGFloat(tickInterval)
            if distance <= step {
                window.setFrameOrigin(target)
            } else {
                let ratio = step / distance
                window.setFrameOrigin(CGPoint(x: current.x + dx * ratio, y: current.y + dy * ratio))
                state.facingRight = dx >= 0
            }
            state.frame = (shortformTick / 5) % 2 == 0 ? .walk1 : .walk2
        } else {
            state.frame = (shortformTick / 6) % 2 == 0 ? .wave1 : .wave2
        }
    }

    private func nearestCorner(window: NSWindow) -> CGPoint {
        guard let screen = window.screen ?? NSScreen.main else { return window.frame.origin }
        let bounds = screen.visibleFrame
        let current = window.frame.origin
        let nearLeft = current.x - bounds.minX < bounds.maxX - (current.x + window.frame.width)
        let nearBottom = current.y - bounds.minY < bounds.maxY - (current.y + window.frame.height)
        let x = nearLeft ? bounds.minX + screenMargin : bounds.maxX - screenMargin - window.frame.width
        let y = nearBottom ? bounds.minY + screenMargin : bounds.maxY - screenMargin - window.frame.height
        return CGPoint(x: x, y: y)
    }

    /// 평소보다 훨씬 빠르게 화면을 좌우로 가로지르며 시야를 방해한다.
    private func crossScreenDisrupt(window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame
        let leftX = bounds.minX + screenMargin
        let rightX = bounds.maxX - screenMargin - window.frame.width
        let targetX = crossScreenGoingRight ? rightX : leftX

        let current = window.frame.origin
        let dx = targetX - current.x
        let disruptSpeed = speed * 2.5
        let step = disruptSpeed * CGFloat(tickInterval)

        shortformTick += 1
        if abs(dx) <= step {
            window.setFrameOrigin(CGPoint(x: targetX, y: current.y))
            crossScreenGoingRight.toggle()
        } else {
            let ratio = step / abs(dx)
            window.setFrameOrigin(CGPoint(x: current.x + dx * ratio, y: current.y))
            state.facingRight = dx >= 0
        }
        state.frame = (shortformTick / 3) % 2 == 0 ? .walk1 : .walk2
    }

    /// 최근 타이핑 빈도에 따라 꾹꾹이/과열 프레임을 재생한다.
    private func updateTyping() {
        typingActivity = typingMonitor.currentActivity()
        guard typingActivity != .idle else { return }
        typingTick += 1
        switch typingActivity {
        case .idle: break
        case .typing:
            state.frame = (typingTick / 4) % 2 == 0 ? .typing1 : .typing2
        case .overheat:
            state.frame = (typingTick / 3) % 2 == 0 ? .overheat1 : .overheat2
        }
    }

    private func arrive() {
        // ponytail: "가끔 앉기"는 도착 시 확률 판정으로 근사. 식빵 자세/그루밍 등 세분화는
        // 별도 무입력 타이머가 생기는 다음 단계에서.
        state.frame = Double.random(in: 0...1) < 0.35 ? .sit : .idleStand
        mode = .idle(until: Date().addingTimeInterval(.random(in: idleDuration)))
    }

    private func pickNewTarget() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame
        let maxX = max(bounds.minX + screenMargin, bounds.maxX - screenMargin - window.frame.width)
        let maxY = max(bounds.minY + screenMargin, bounds.maxY - screenMargin - window.frame.height)
        let target = CGPoint(
            x: CGFloat.random(in: (bounds.minX + screenMargin)...maxX),
            y: CGFloat.random(in: (bounds.minY + screenMargin)...maxY)
        )
        mode = .walking(to: target)
    }
}
