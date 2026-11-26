import AppKit
import SwiftUI

/// 스트레칭/물 마시기 알림: 숏폼 경고3(화면 중앙에 고양이가 확 커져서 나타남)와 같은 톤으로
/// 강하게 방해한다. OverlayWindowController가 이 창을 띄우기 전에 작은 배회 고양이를 먼저
/// 숨기고, 여기서 클릭하면(onDismiss) 다시 작은 고양이를 돌려놓는다.
/// 숏폼 경고3와 달리 "조작을 막는" 용도가 아니라 "확인 후 닫는" 용도라 클릭을 그대로 받는다
/// (ignoresMouseEvents를 켜지 않음) — 아무 반응이 없어도 방치되지 않게 자동 닫힘 타이머를 둔다.
final class ReminderBigAlertWindowController: NSWindowController {
    private static let pixelSize: CGFloat = 22.75 // ShortformAlertWindowController와 동일한 "큰 고양이" 크기
    private static let messageHeight: CGFloat = 64

    private var autoDismissTimer: Timer?
    private var onDismiss: (() -> Void)?

    convenience init() {
        let size = NSSize(
            width: CGFloat(CatSprite.width) * Self.pixelSize,
            height: CGFloat(CatSprite.heightRows) * Self.pixelSize + Self.messageHeight
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.init(window: window)
    }

    func show(message: String, duration: TimeInterval = 12, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        let hostingView = NSHostingView(
            rootView: ReminderBigAlertView(message: message, pixelSize: Self.pixelSize) { [weak self] in
                self?.dismiss()
            }
        )
        hostingView.frame = NSRect(origin: .zero, size: window?.frame.size ?? .zero)
        window?.contentView = hostingView
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        window?.orderOut(nil)
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }
}

private struct ReminderBigAlertView: View {
    let message: String
    let pixelSize: CGFloat
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            PixelSpriteView(
                colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: PixelOverrideStore.load()),
                pixelSize: pixelSize
            )
            Text(message)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
