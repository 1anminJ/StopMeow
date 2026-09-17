/// 기획서 상태머신 표의 상태 목록. 전이 로직은 미구현.
enum CatState {
    case idle, follow, drag, typing, overheat
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
