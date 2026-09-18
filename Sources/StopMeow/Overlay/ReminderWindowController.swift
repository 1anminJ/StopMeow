import AppKit
import SwiftUI

/// 스트레칭/물/뽀모도로 완료 알림 공용 창 — 확대된 고양이 + 짧은 문구,
/// 일정 시간 후 자동으로 사라진다. ShortformAlertWindowController와 같은 톤(카드/버튼 없음)으로 통일.
final class ReminderWindowController: NSWindowController {
    fileprivate static let pixelSize: CGFloat = 8.125 // 32*8.125=260pt, 기존 배너 크기 유지
    fileprivate static let width = CGFloat(CatSprite.width) * pixelSize
    fileprivate static let height = CGFloat(CatSprite.heightRows) * pixelSize + 48 // 문구 들어갈 자리

    private var dismissTimer: Timer?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.center()
        self.init(window: window)
    }

    func show(message: String, frame: CatFrame = .idleStand, duration: TimeInterval = 6) {
        let hostingView = NSHostingView(
            rootView: ReminderBannerView(message: message, frame: frame, pixelSize: Self.pixelSize)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: Self.width, height: Self.height)
        window?.contentView = hostingView
        window?.center()
        window?.orderFront(nil)

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.window?.orderOut(nil)
        }
    }
}

private struct ReminderBannerView: View {
    let message: String
    let frame: CatFrame
    let pixelSize: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            PixelSpriteView(colors: frame.displayColors(eyeLook: .center, overrides: PixelOverrideStore.load()), pixelSize: pixelSize)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: ReminderWindowController.width, height: ReminderWindowController.height)
    }
}
