import Foundation

/// 스트레칭/물 알림 타이머. 각각 독립적인 주기로 발동.
/// 기획서 상태 "Reminder | 타이머(스트레칭/물) | 커져서 알림"에 대응.
/// 주기·반복 여부는 큰 창 "생산성" 탭에서 바꾸며, 바뀌면 그 시점부터 타이머를 새로 건다.
final class ReminderEngine {
    var onFire: ((String) -> Void)?

    private var stretchTimer: Timer?
    private var waterTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var appliedConfig: [Int] = []

    func start() {
        restartTimers()
        // UserDefaults 알림은 아무 키나 바뀌어도(픽셀 색칠 등) 오므로, 알림 설정이 실제로 달라졌을 때만 재시작.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, Self.currentConfig() != self.appliedConfig else { return }
            self.restartTimers()
        }
    }

    func stop() {
        stretchTimer?.invalidate()
        stretchTimer = nil
        waterTimer?.invalidate()
        waterTimer = nil
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
    }

    private static func currentConfig() -> [Int] {
        let d = UserDefaults.standard
        return [
            d.integer(forKey: SettingsKey.stretchIntervalMinutes),
            d.bool(forKey: SettingsKey.stretchRepeats) ? 1 : 0,
            d.integer(forKey: SettingsKey.waterIntervalMinutes),
            d.bool(forKey: SettingsKey.waterRepeats) ? 1 : 0,
        ]
    }

    private func restartTimers() {
        stretchTimer?.invalidate()
        waterTimer?.invalidate()
        appliedConfig = Self.currentConfig()
        let d = UserDefaults.standard

        stretchTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(max(1, appliedConfig[0]) * 60),
            repeats: d.bool(forKey: SettingsKey.stretchRepeats)
        ) { [weak self] _ in
            self?.fireIfEnabled(key: SettingsKey.stretchReminderEnabled, message: "일어나서 스트레칭 한 번 해요 🙆")
        }
        waterTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(max(1, appliedConfig[2]) * 60),
            repeats: d.bool(forKey: SettingsKey.waterRepeats)
        ) { [weak self] _ in
            self?.fireIfEnabled(key: SettingsKey.waterReminderEnabled, message: "물 한 잔 마시고 와요 💧")
        }
    }

    private func fireIfEnabled(key: String, message: String) {
        guard UserDefaults.standard.bool(forKey: key) else { return }
        onFire?(message)
    }
}
