import AppKit

/// 메뉴바 아이콘 + 표준 NSMenu 드롭다운.
/// 커스텀 팝오버(화살표 튀어나오는 모양) 대신 macOS 기본 메뉴 UI를 그대로 사용 — 위치/여백 문제 자체가 없음.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let catEnabledItem = NSMenuItem()
    private let shortformDetectionItem = NSMenuItem()
    private let stretchItem = NSMenuItem()
    private let waterItem = NSMenuItem()
    private let jumpItem = NSMenuItem()
    private let weakItem = NSMenuItem()
    private let normalItem = NSMenuItem()
    private let strongItem = NSMenuItem()
    private let pomodoroItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let pomodoroEngine = PomodoroEngine()
    private let designWindow = DesignWindowController()
    private var settingsObserver: NSObjectProtocol?

    override init() {
        super.init()
        refreshIcon()
        statusItem.menu = buildMenu()
        refreshCheckmarks()

        pomodoroEngine.onTick = { [weak self] remaining in
            guard let self else { return }
            self.statusItem.button?.title = remaining.map { " \($0)" } ?? ""
            self.pomodoroItem.title = remaining == nil ? Self.pomodoroStartTitle : "뽀모도로 중지"
        }

        // 큰 창에서 커스텀 색/생산성 설정을 바꾸면 메뉴바 아이콘·체크·뽀모도로 문구도 바로 반영.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.refreshIcon()
            self.refreshCheckmarks()
            if !self.pomodoroEngine.isRunning { self.pomodoroItem.title = Self.pomodoroStartTitle }
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    private static var pomodoroStartTitle: String { "뽀모도로 시작 (\(PomodoroEngine.sessionMinutes)분)" }

    private func refreshIcon() {
        statusItem.button?.image = CatMenuBarIcon.render()
        statusItem.button?.imagePosition = .imageLeft
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false // 쉬기 항목을 감지 Off일 때 직접 비활성화하기 위함(나머지는 항상 활성)

        catEnabledItem.title = "고양이 표시"
        catEnabledItem.target = self
        catEnabledItem.action = #selector(toggleCatEnabled)
        menu.addItem(catEnabledItem)

        menu.addItem(.separator())

        shortformDetectionItem.title = "숏폼 감지"
        shortformDetectionItem.target = self
        shortformDetectionItem.action = #selector(toggleShortformDetection)
        menu.addItem(shortformDetectionItem)

        let intensityMenu = NSMenu()
        for (item, level) in [(weakItem, DisturbIntensity.weak), (normalItem, DisturbIntensity.normal), (strongItem, DisturbIntensity.strong)] {
            item.title = level.label
            item.target = self
            item.action = #selector(selectIntensity(_:))
            item.representedObject = level.rawValue
            intensityMenu.addItem(item)
        }
        let intensityHeader = NSMenuItem(title: "방해 강도", action: nil, keyEquivalent: "")
        intensityHeader.submenu = intensityMenu
        menu.addItem(intensityHeader)

        menu.addItem(pauseItem)

        menu.addItem(.separator())

        stretchItem.title = "스트레칭 알림"
        stretchItem.target = self
        stretchItem.action = #selector(toggleStretch)
        menu.addItem(stretchItem)

        waterItem.title = "물 마시기 알림"
        waterItem.target = self
        waterItem.action = #selector(toggleWater)
        menu.addItem(waterItem)

        menu.addItem(.separator())

        jumpItem.title = "스페이스바 점프"
        jumpItem.target = self
        jumpItem.action = #selector(toggleJump)
        menu.addItem(jumpItem)

        menu.addItem(.separator())

        pomodoroItem.title = Self.pomodoroStartTitle
        pomodoroItem.target = self
        pomodoroItem.action = #selector(togglePomodoro)
        menu.addItem(pomodoroItem)

        menu.addItem(.separator())

        let designItem = NSMenuItem(title: "멈춰묘 설정…", action: #selector(openDesignWindow), keyEquivalent: ",")
        designItem.target = self
        menu.addItem(designItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    private func refreshCheckmarks() {
        let defaults = UserDefaults.standard
        catEnabledItem.state = defaults.bool(forKey: SettingsKey.catEnabled) ? .on : .off
        shortformDetectionItem.state = defaults.bool(forKey: SettingsKey.shortformDetectionEnabled) ? .on : .off
        stretchItem.state = defaults.bool(forKey: SettingsKey.stretchReminderEnabled) ? .on : .off
        waterItem.state = defaults.bool(forKey: SettingsKey.waterReminderEnabled) ? .on : .off
        jumpItem.state = defaults.bool(forKey: SettingsKey.jumpEnabled) ? .on : .off

        let intensity = defaults.string(forKey: SettingsKey.disturbIntensity) ?? DisturbIntensity.normal.rawValue
        weakItem.state = intensity == DisturbIntensity.weak.rawValue ? .on : .off
        normalItem.state = intensity == DisturbIntensity.normal.rawValue ? .on : .off
        strongItem.state = intensity == DisturbIntensity.strong.rawValue ? .on : .off

        refreshPauseItem()
    }

    /// 쉬기는 시간이 지나면 저절로 풀리므로(설정 변경 알림 없음) 메뉴를 열 때마다 다시 그린다.
    func menuWillOpen(_ menu: NSMenu) {
        refreshPauseItem()
    }

    private func refreshPauseItem() {
        let submenu = NSMenu()
        if let label = ShortformPause.untilLabel {
            pauseItem.title = "숏폼 방해 쉬는 중 (\(label))"
            submenu.addItem(menuItem("지금 다시 켜기", #selector(resumeShortform)))
        } else {
            pauseItem.title = "숏폼 방해 쉬기"
            for minutes in [30, 60] {
                let item = menuItem(minutes == 60 ? "1시간" : "\(minutes)분", #selector(pauseShortform(_:)))
                item.representedObject = minutes
                submenu.addItem(item)
            }
            submenu.addItem(menuItem("오늘 하루", #selector(pauseShortformForToday)))
        }
        pauseItem.submenu = submenu
        // 감지를 아예 꺼둔 상태면 쉴 것도 없음.
        pauseItem.isEnabled = UserDefaults.standard.bool(forKey: SettingsKey.shortformDetectionEnabled)
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func pauseShortform(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        ShortformPause.pause(minutes: minutes)
    }

    @objc private func pauseShortformForToday() { ShortformPause.pauseForToday() }
    @objc private func resumeShortform() { ShortformPause.resume() }

    private func toggle(_ key: String, item: NSMenuItem) {
        let newValue = !UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(newValue, forKey: key)
        item.state = newValue ? .on : .off
    }

    @objc private func toggleCatEnabled() { toggle(SettingsKey.catEnabled, item: catEnabledItem) }
    @objc private func toggleShortformDetection() { toggle(SettingsKey.shortformDetectionEnabled, item: shortformDetectionItem) }
    @objc private func toggleStretch() { toggle(SettingsKey.stretchReminderEnabled, item: stretchItem) }
    @objc private func toggleWater() { toggle(SettingsKey.waterReminderEnabled, item: waterItem) }
    @objc private func toggleJump() { toggle(SettingsKey.jumpEnabled, item: jumpItem) }
    @objc private func togglePomodoro() { pomodoroEngine.toggle() }
    @objc private func openDesignWindow() { designWindow.show() }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: SettingsKey.disturbIntensity)
        refreshCheckmarks()
    }
}
