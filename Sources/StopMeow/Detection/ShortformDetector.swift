import AppKit

/// 지원 브라우저와 "모든 창"의 활성 탭 URL을 가져오는 AppleScript.
// ponytail: 기획서는 Accessibility(AXURL)를 언급하지만 브라우저마다 AX 트리 구조가 달라 훨씬
// 불안정하다. Safari/Chrome/Arc 모두 표준으로 지원하는 "URL of active tab" AppleScript가 훨씬
// 간단하고 안정적이라 이걸로 대체. 최초 사용 시 "자동화" 권한 팝업이 뜬다(손쉬운 사용과 별개 권한,
// 앱별로 한 번씩).
// 창을 여러 개 띄워두면 "front window"가 실제 보고 있는 창과 다를 수 있어(브라우저 내부적으로
// 마지막 포커스 기준) "every window"로 전부 가져와 하나라도 매치되면 시청 중으로 판단한다.
enum SupportedBrowser: String, CaseIterable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case arc = "company.thebrowser.Browser"

    var allWindowURLsScriptSource: String {
        switch self {
        case .safari:
            return "tell application \"Safari\" to return URL of every tab of every window"
        case .chrome:
            return "tell application \"Google Chrome\" to return URL of active tab of every window"
        case .arc:
            return "tell application \"Arc\" to return URL of active tab of every window"
        }
    }
}

/// 브라우저 활성 탭 URL을 주기적으로 확인해 숏폼 시청 여부/누적 시간/경고 단계를 판단한다.
final class ShortformDetector {
    /// 0 = 해당 없음, 1~3 = 경고 단계 (기획서 ShortformWarn1~3).
    private(set) var warnLevel = 0

    var onWarnLevelChange: ((Int) -> Void)?

    private var timer: Timer?
    private var watchedSeconds: TimeInterval = 0
    private var lastMatchAt = Date.distantPast

    private let pollInterval: TimeInterval = 1.5
    private let gracePeriod: TimeInterval = 30 // 짧은 이탈(탭 전환 등)은 무시하고 누적 유지
    private let urlPatterns = ["/shorts/", "/reel", "tiktok.com"] // "/reel"은 인스타 /reel/·/reels/ 둘 다 포함

    // ponytail: 기획서 1~2분/3~5분/5분+ 표의 하한값을 기준 임계값으로 사용.
    private let warn1Threshold: TimeInterval = 60
    private let warn2Threshold: TimeInterval = 180
    private let warn3Threshold: TimeInterval = 300

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard UserDefaults.standard.bool(forKey: SettingsKey.shortformDetectionEnabled) else {
            reset()
            return
        }

        if isWatchingShortform() {
            lastMatchAt = Date()
            watchedSeconds += pollInterval
        } else if Date().timeIntervalSince(lastMatchAt) > gracePeriod {
            reset()
            return
        }
        // 유예 시간 이내의 짧은 이탈이면 watchedSeconds를 그대로 둔 채 넘어감(일시정지 효과).

        updateWarnLevel()
    }

    private func reset() {
        watchedSeconds = 0
        lastMatchAt = .distantPast
        setWarnLevel(0)
    }

    private func updateWarnLevel() {
        let intensity = DisturbIntensity(
            rawValue: UserDefaults.standard.string(forKey: SettingsKey.disturbIntensity) ?? ""
        ) ?? .normal
        let m = intensity.thresholdMultiplier

        let newLevel: Int
        if watchedSeconds >= warn3Threshold * m {
            newLevel = 3
        } else if watchedSeconds >= warn2Threshold * m {
            newLevel = 2
        } else if watchedSeconds >= warn1Threshold * m {
            newLevel = 1
        } else {
            newLevel = 0
        }
        setWarnLevel(newLevel)
    }

    private func setWarnLevel(_ level: Int) {
        guard level != warnLevel else { return }
        warnLevel = level
        onWarnLevelChange?(level)
    }

    private func isWatchingShortform() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              let browser = SupportedBrowser(rawValue: bundleID)
        else { return false }
        let urls = allTabURLs(for: browser)
        return urls.contains { url in urlPatterns.contains { url.contains($0) } }
    }

    /// 열려있는 모든 창(Safari는 모든 탭까지)의 URL을 가져온다. 실패하면 빈 배열.
    private func allTabURLs(for browser: SupportedBrowser) -> [String] {
        guard let script = NSAppleScript(source: browser.allWindowURLsScriptSource) else { return [] }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return [] } // 창이 없거나 권한 미승인 등은 조용히 무시

        if let single = result.stringValue { return [single] }
        guard result.numberOfItems > 0 else { return [] }

        var urls: [String] = []
        for i in 1...result.numberOfItems {
            guard let item = result.atIndex(i) else { continue }
            if let s = item.stringValue {
                urls.append(s)
            } else if item.numberOfItems > 0 {
                // Safari의 "URL of every tab of every window"는 창별 URL 리스트의 리스트로 온다.
                for j in 1...item.numberOfItems {
                    if let s = item.atIndex(j)?.stringValue {
                        urls.append(s)
                    }
                }
            }
        }
        return urls
    }
}
