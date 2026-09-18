import Foundation

/// 스트레칭/물 알림 타이머. 각각 독립적인 주기로 반복 발동.
/// 기획서 상태 "Reminder | 타이머(스트레칭/물) | 커져서 알림"에 대응.
final class ReminderEngine {
    var onFire: ((String) -> Void)?

    private var stretchTimer: Timer?
    private var waterTimer: Timer?

    // ponytail: 기획서에 구체적 주기가 없어 통상적인 값으로 하드코딩.
    // TODO: 로드맵 2/4단계 큰 창(디자인 커스텀)에서 주기·반복 여부를 설정할 수 있게 될 예정 —
    // 그때 UserDefaults 값으로 바꾸고 여기서 읽어오도록 교체.
    private let stretchInterval: TimeInterval = 45 * 60
    private let waterInterval: TimeInterval = 60 * 60

    func start() {
        stretchTimer = Timer.scheduledTimer(withTimeInterval: stretchInterval, repeats: true) { [weak self] _ in
            self?.fireIfEnabled(key: SettingsKey.stretchReminderEnabled, message: "일어나서 스트레칭 한 번 해요 🙆")
        }
        waterTimer = Timer.scheduledTimer(withTimeInterval: waterInterval, repeats: true) { [weak self] _ in
            self?.fireIfEnabled(key: SettingsKey.waterReminderEnabled, message: "물 한 잔 마시고 와요 💧")
        }
    }

    func stop() {
        stretchTimer?.invalidate()
        stretchTimer = nil
        waterTimer?.invalidate()
        waterTimer = nil
    }

    private func fireIfEnabled(key: String, message: String) {
        guard UserDefaults.standard.bool(forKey: key) else { return }
        onFire?(message)
    }
}
