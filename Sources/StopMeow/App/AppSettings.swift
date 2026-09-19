import Foundation

/// 팝오버 설정값의 UserDefaults 키. AppKit(엔진)과 SwiftUI(팝오버) 양쪽에서 같은 키를 참조한다.
enum SettingsKey {
    static let catEnabled = "settings.catEnabled"
    static let jumpEnabled = "settings.jumpEnabled"
    static let disturbIntensity = "settings.disturbIntensity"
    static let shortformDetectionEnabled = "settings.shortformDetectionEnabled"
    static let stretchReminderEnabled = "settings.stretchReminderEnabled"
    static let waterReminderEnabled = "settings.waterReminderEnabled"

    /// 앱 시작 시 한 번 등록. 값이 아예 없을 때(최초 실행)의 기본값을 정한다.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            catEnabled: true,
            jumpEnabled: true,
            disturbIntensity: DisturbIntensity.normal.rawValue,
            shortformDetectionEnabled: true,
            stretchReminderEnabled: true,
            waterReminderEnabled: true,
        ])
    }
}

/// 숏폼 방해 강도 — 경고 단계가 올라가는 임계값(초)에 실제로 연결됨 (약할수록 오래 봐줌).
enum DisturbIntensity: String, CaseIterable, Identifiable {
    case weak, normal, strong
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weak: return "약"
        case .normal: return "보통"
        case .strong: return "강"
        }
    }

    /// 경고 단계 임계값(초)에 곱하는 배수. 약하면 더 오래 봐주고, 강하면 더 빨리 반응.
    var thresholdMultiplier: Double {
        switch self {
        case .weak: return 1.5
        case .normal: return 1.0
        case .strong: return 0.6
        }
    }
}
