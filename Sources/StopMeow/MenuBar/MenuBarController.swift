import AppKit

/// 메뉴바 아이콘 + 표준 NSMenu 드롭다운.
/// 커스텀 팝오버(화살표 튀어나오는 모양) 대신 macOS 기본 메뉴 UI를 그대로 사용 — 위치/여백 문제 자체가 없음.
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let catEnabledItem = NSMenuItem()
    private let stretchItem = NSMenuItem()
    private let waterItem = NSMenuItem()
    private let jumpItem = NSMenuItem()
    private let weakItem = NSMenuItem()
    private let normalItem = NSMenuItem()
    private let strongItem = NSMenuItem()

    override init() {
        super.init()
        statusItem.button?.title = "🐱"
        statusItem.menu = buildMenu()
        refreshCheckmarks()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        catEnabledItem.title = "고양이 표시"
        catEnabledItem.target = self
        catEnabledItem.action = #selector(toggleCatEnabled)
        menu.addItem(catEnabledItem)

        menu.addItem(.separator())

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

        let quitItem = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    private func refreshCheckmarks() {
        let defaults = UserDefaults.standard
        catEnabledItem.state = defaults.bool(forKey: SettingsKey.catEnabled) ? .on : .off
        stretchItem.state = defaults.bool(forKey: SettingsKey.stretchReminderEnabled) ? .on : .off
        waterItem.state = defaults.bool(forKey: SettingsKey.waterReminderEnabled) ? .on : .off
        jumpItem.state = defaults.bool(forKey: SettingsKey.jumpEnabled) ? .on : .off

        let intensity = defaults.string(forKey: SettingsKey.disturbIntensity) ?? DisturbIntensity.normal.rawValue
        weakItem.state = intensity == DisturbIntensity.weak.rawValue ? .on : .off
        normalItem.state = intensity == DisturbIntensity.normal.rawValue ? .on : .off
        strongItem.state = intensity == DisturbIntensity.strong.rawValue ? .on : .off
    }

    private func toggle(_ key: String, item: NSMenuItem) {
        let newValue = !UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(newValue, forKey: key)
        item.state = newValue ? .on : .off
    }

    @objc private func toggleCatEnabled() { toggle(SettingsKey.catEnabled, item: catEnabledItem) }
    @objc private func toggleStretch() { toggle(SettingsKey.stretchReminderEnabled, item: stretchItem) }
    @objc private func toggleWater() { toggle(SettingsKey.waterReminderEnabled, item: waterItem) }
    @objc private func toggleJump() { toggle(SettingsKey.jumpEnabled, item: jumpItem) }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: SettingsKey.disturbIntensity)
        refreshCheckmarks()
    }
}
