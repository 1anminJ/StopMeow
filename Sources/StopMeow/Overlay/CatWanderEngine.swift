import AppKit

/// Idle 상태의 기본 배회 로직: 화면 안 임의 지점으로 걸어갔다가 멈춰 서거나 앉기를 반복.
/// 기획서 상태머신의 "Idle | 배회, 가끔 앉기"에 대응. (타이핑/커서 반응 등 다른 상태 전이는 아직 없음)
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

    private var lastCursor: CGPoint = NSEvent.mouseLocation
    private var lastCursorMoveAt = Date()

    private var lastHuntCursor: CGPoint = NSEvent.mouseLocation
    private var lastFastMoveAt = Date.distantPast
    private var isHunting = false
    private var huntTick = 0

    private let speed: CGFloat = 60 // px/초
    private let idleDuration: ClosedRange<TimeInterval> = 1.5...4.0
    private let screenMargin: CGFloat = 16
    private let tickInterval: TimeInterval = 1.0 / 30.0
    private let gazeTimeout: TimeInterval = 1.2 // 커서가 이만큼 멈춰 있으면 시선도 정면으로
    private let gazeDeadzone: CGFloat = 40 // px, 이 폭 안에서는 정면 유지
    // ponytail: 30Hz 폴링 기준 임계값이라 대략치. 실제 써보고 너무 자주/드물게 반응하면 조정.
    private let huntSpeedThreshold: CGFloat = 4000 // px/초, 이보다 빠르면 "사냥감 포착"
    private let huntGrace: TimeInterval = 0.35 // 마지막 빠른 움직임 후 이 시간 동안은 계속 사냥 자세

    init(window: NSWindow, state: CatAnimationState) {
        self.window = window
        self.state = state
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 드래그/쓰다듬기 시작: 배회 이동 로직을 멈춘다 (시선 추적은 계속 동작).
    func pause() {
        isPaused = true
    }

    /// 드래그/쓰다듬기 종료: 잠깐 멈춰 있다가(흔들림 재생 시간) 다시 배회를 시작한다.
    func resumeAfterInteraction() {
        isPaused = false
        mode = .idle(until: Date().addingTimeInterval(0.4))
    }

    private func tick() {
        guard let window else { return }
        updateGaze(window: window)

        let wasHunting = isHunting
        if isPaused {
            isHunting = false
        } else {
            updateHunt()
        }
        if wasHunting && !isHunting {
            // 사냥 자세 풀림: 다음 프레임을 즉시 정상 상태로 되돌려 크라우치 포즈가 눌어붙지 않게 함
            if case .walking = mode { state.frame = .walk1 } else { state.frame = .idleStand }
        }

        guard !isPaused, !isHunting else { return }

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

    /// 커서가 순간적으로 빠르게 움직이면 몸을 낮추는 사냥 자세로 전환한다.
    private func updateHunt() {
        let cursor = NSEvent.mouseLocation
        let distance = (cursor.x - lastHuntCursor.x, cursor.y - lastHuntCursor.y)
        let speed = (distance.0 * distance.0 + distance.1 * distance.1).squareRoot() / CGFloat(tickInterval)
        lastHuntCursor = cursor
        if speed > huntSpeedThreshold {
            lastFastMoveAt = Date()
        }
        isHunting = Date().timeIntervalSince(lastFastMoveAt) < huntGrace
        guard isHunting else { return }
        huntTick += 1
        state.frame = (huntTick / 4) % 2 == 0 ? .hunt1 : .hunt2
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
