import Foundation

/// 뽀모도로 타이머. 메뉴바에서 시작/중지하고, 완료되면 알림을 브로드캐스트한다
/// (OverlayWindowController가 이 알림을 구독해 축하 점프를 재생 — 서로 직접 참조하지 않음).
final class PomodoroEngine {
    static let didCompleteNotification = Notification.Name("PomodoroEngine.didComplete")

    private(set) var isRunning = false
    private var timer: Timer?
    private var remainingSeconds = 0

    // ponytail: 표준 뽀모도로 25분으로 하드코딩.
    // TODO: 로드맵 2/4단계 큰 창(디자인 커스텀)에서 주기를 설정할 수 있게 될 예정 —
    // 그때 UserDefaults 값으로 바꾸고 여기서 읽어오도록 교체.
    private let sessionDuration = 25 * 60

    /// 남은 시간 문자열("24:59") 또는 nil(중지됨)을 전달.
    var onTick: ((String?) -> Void)?

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        remainingSeconds = sessionDuration
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        onTick?(nil)
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            isRunning = false
            timer?.invalidate()
            timer = nil
            onTick?(nil)
            NotificationCenter.default.post(name: Self.didCompleteNotification, object: nil)
            return
        }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        onTick?(String(format: "%d:%02d", minutes, seconds))
        remainingSeconds -= 1
    }
}
