import Foundation

/// 팝오버 설정값의 UserDefaults 키. AppKit(엔진)과 SwiftUI(팝오버) 양쪽에서 같은 키를 참조한다.
enum SettingsKey {
    static let catEnabled = "settings.catEnabled"
    static let jumpEnabled = "settings.jumpEnabled"
    static let disturbIntensity = "settings.disturbIntensity"
    static let stretchReminderEnabled = "settings.stretchReminderEnabled"
    static let waterReminderEnabled = "settings.waterReminderEnabled"

    /// 앱 시작 시 한 번 등록. 값이 아예 없을 때(최초 실행)의 기본값을 정한다.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            catEnabled: true,
            jumpEnabled: true,
            disturbIntensity: DisturbIntensity.normal.rawValue,
            stretchReminderEnabled: true,
            waterReminderEnabled: true,
        ])
    }
}

/// 숏폼 방해 강도. 로드맵 3단계(숏폼 감지)에서 실제 로직에 연결 예정 — 지금은 값만 저장.
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
}
