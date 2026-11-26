import SwiftUI

/// 큰 창의 "생산성" 탭. 스트레칭/물 알림 주기·반복, 뽀모도로 길이를 설정한다.
/// 메뉴바·엔진과 같은 UserDefaults 키를 쓰므로 바꾸는 즉시 반영된다.
struct ProductivitySettingsView: View {
    @AppStorage(SettingsKey.stretchReminderEnabled) private var stretchEnabled = true
    @AppStorage(SettingsKey.stretchIntervalMinutes) private var stretchMinutes = 45
    @AppStorage(SettingsKey.stretchRepeats) private var stretchRepeats = true
    @AppStorage(SettingsKey.waterReminderEnabled) private var waterEnabled = true
    @AppStorage(SettingsKey.waterIntervalMinutes) private var waterMinutes = 60
    @AppStorage(SettingsKey.waterRepeats) private var waterRepeats = true
    @AppStorage(SettingsKey.pomodoroMinutes) private var pomodoroMinutes = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            reminderCard(title: "스트레칭 알림", enabled: $stretchEnabled, minutes: $stretchMinutes, repeats: $stretchRepeats)
            reminderCard(title: "물 마시기 알림", enabled: $waterEnabled, minutes: $waterMinutes, repeats: $waterRepeats)

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(text: "뽀모도로")
                row("한 세션 길이") { MinuteStepper(minutes: $pomodoroMinutes, range: 5...90) }
                Text("다음에 시작하는 세션부터 적용돼요.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))
            }
            .padding(16)
            .cardBackground()

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: 480, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(CuteTheme.background)
    }

    private func reminderCard(title: String, enabled: Binding<Bool>, minutes: Binding<Int>, repeats: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(text: title)
                Spacer()
                Toggle("", isOn: enabled).toggleStyle(.switch).tint(CuteTheme.accent).labelsHidden()
            }
            Group {
                row("알림 간격") { MinuteStepper(minutes: minutes, range: 5...180) }
                row("계속 반복") {
                    Toggle("", isOn: repeats).toggleStyle(.switch).tint(CuteTheme.accent).labelsHidden()
                }
            }
            .disabled(!enabled.wrappedValue)
            .opacity(enabled.wrappedValue ? 1 : 0.45)
        }
        .padding(16)
        .cardBackground()
    }

    private func row<Trailing: View>(_ label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary)
            Spacer()
            trailing()
        }
    }
}

/// "−  45분  +" 알약 모양 스테퍼 (5분 단위).
private struct MinuteStepper: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 4) {
            button("minus", delta: -5)
            Text("\(minutes)분")
                .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(CuteTheme.textPrimary)
                .frame(minWidth: 56)
            button("plus", delta: 5)
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
    }

    private func button(_ symbol: String, delta: Int) -> some View {
        let next = minutes + delta
        return Button {
            minutes = min(max(next, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(CuteTheme.accent))
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(!range.contains(next))
        .opacity(range.contains(next) ? 1 : 0.35)
    }
}
