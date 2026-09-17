/// 기획서 상태머신 표의 상태 목록 + 실제 구현된 사냥/쓰다듬기 상태.
/// `CatWanderEngine.currentState`가 내부 플래그들로부터 매 틱 계산해서 채운다.
enum CatState: Equatable {
    case idle, follow, drag, pet, hunt, typing, overheat
    case shortformWarn1, shortformWarn2, shortformWarn3
    case reminder, pomodoro, celebrate

    /// 재생 중 다른 상태로 강제 전환 가능한지 여부.
    var isInterruptible: Bool {
        switch self {
        case .celebrate, .shortformWarn3: return false
        default: return true
        }
    }
}
