import Foundation

/// 뽀모도로 타이머. 메뉴바에서 시작/중지하고, 완료되면 알림을 브로드캐스트한다
/// (OverlayWindowController가 이 알림을 구독해 축하 점프를 재생 — 서로 직접 참조하지 않음).
final class PomodoroEngine {
    static let didCompleteNotification = Notification.Name("PomodoroEngine.didComplete")

    private(set) var isRunning = false
    private var timer: Timer?
    private var remainingSeconds = 0

    /// 큰 창 "생산성" 탭에서 설정한 한 세션 길이(분). 진행 중인 세션엔 영향 없고 다음 시작부터 적용.
    static var sessionMinutes: Int { UserDefaults.standard.integer(forKey: SettingsKey.pomodoroMinutes) }

    /// 남은 시간 문자열("24:59") 또는 nil(중지됨)을 전달.
    var onTick: ((String?) -> Void)?

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        remainingSeconds = Self.sessionMinutes * 60
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
