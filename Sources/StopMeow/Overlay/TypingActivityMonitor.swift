import AppKit
import ApplicationServices

/// 전역 키 입력 빈도를 추적해 Typing/Overheat 여부를 판단한다.
/// 손쉬운 사용 권한이 없으면 이벤트가 전혀 오지 않아 조용히 비활성화된다 —
/// PRD의 "미승인 시 우아한 폴백" 원칙과 동일하게 취급.
final class TypingActivityMonitor {
    enum Activity: Equatable { case idle, typing, overheat }

    private static let spaceKeyCode: UInt16 = 49

    /// 타이핑 중 스페이스바를 누른 순간 호출됨 (점프 트리거용).
    var onSpacePressed: (() -> Void)?

    private var monitor: Any?
    private var recentKeyTimestamps: [Date] = []
    private var lastKeyAt = Date.distantPast

    private let idleTimeout: TimeInterval = 1.0 // 이만큼 키 입력이 없으면 Idle로 판단
    private let rateWindow: TimeInterval = 1.0 // 최근 1초간 키 수로 타수 계산
    // ponytail: 실사용 피드백으로 6 -> 10(너무 안 걸림) -> 8로 재조정.
    private let overheatKeysPerSecond: Double = 8

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.recordKeystroke()
            if event.keyCode == Self.spaceKeyCode {
                self?.onSpacePressed?()
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func recordKeystroke() {
        let now = Date()
        lastKeyAt = now
        recentKeyTimestamps.append(now)
        recentKeyTimestamps.removeAll { now.timeIntervalSince($0) > rateWindow }
    }

    /// 타이머 틱에서 폴링해 현재 활동 상태를 얻는다.
    func currentActivity() -> Activity {
        guard Date().timeIntervalSince(lastKeyAt) < idleTimeout else { return .idle }
        let rate = Double(recentKeyTimestamps.count) / rateWindow
        return rate >= overheatKeysPerSecond ? .overheat : .typing
    }
}
