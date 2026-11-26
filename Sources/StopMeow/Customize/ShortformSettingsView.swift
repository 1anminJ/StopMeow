import SwiftUI

/// 큰 창의 "숏폼 방해" 탭. 감지 On/Off와 방해 강도를 설정한다.
/// 메뉴바 "숏폼 감지"/"방해 강도"와 같은 키라 어느 쪽에서 바꿔도 서로 반영된다.
struct ShortformSettingsView: View {
    @AppStorage(SettingsKey.shortformDetectionEnabled) private var enabled = true
    @AppStorage(SettingsKey.disturbIntensity) private var intensityRaw = DisturbIntensity.normal.rawValue
    // 값 자체는 ShortformPause가 읽지만, 바뀔 때 화면을 다시 그리도록 구독만 해둔다.
    @AppStorage(SettingsKey.shortformPausedUntil) private var pausedUntil: Double = 0

    private var intensity: Binding<DisturbIntensity> {
        Binding(
            get: { DisturbIntensity(rawValue: intensityRaw) ?? .normal },
            set: { intensityRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(text: "숏폼 감지")
                Spacer()
                Toggle("", isOn: $enabled).toggleStyle(.switch).tint(CuteTheme.accent).labelsHidden()
            }
            .padding(16)
            .cardBackground()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(text: "방해 강도")
                PillTabBar(tabs: DisturbIntensity.allCases.map { ($0, $0.label) }, selection: intensity)
                Text(scheduleText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))
            }
            .padding(16)
            .cardBackground()
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)

            pauseCard
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.45)

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: 480, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(CuteTheme.background)
    }

    /// 쉬는 시간이 끝나면 저절로 풀리므로, 창을 띄워둔 채여도 30초마다 상태를 다시 확인한다.
    private var pauseCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(text: "잠깐 쉬기")
                if let label = ShortformPause.untilLabel {
                    HStack {
                        Text("\(label) 숏폼을 봐도 고양이가 참아줘요")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CuteTheme.textPrimary)
                        Spacer()
                        Button("다시 켜기") { ShortformPause.resume() }
                            .buttonStyle(PixelButtonStyle())
                            .frame(width: 100)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button("30분") { ShortformPause.pause(minutes: 30) }
                        Button("1시간") { ShortformPause.pause(minutes: 60) }
                        Button("오늘 하루") { ShortformPause.pauseForToday() }
                    }
                    .buttonStyle(PixelSecondaryButtonStyle())
                    Text("시간이 지나면 자동으로 다시 켜져요.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))
                }
            }
            .id(pausedUntil) // 버튼으로 바뀐 즉시 반영
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// 선택한 강도에서 경고 단계별로 몇 분 보면 고양이가 끼어드는지 안내.
    private var scheduleText: String {
        let m = intensity.wrappedValue.thresholdMultiplier
        let steps = [ShortformDetector.warn1Threshold, ShortformDetector.warn2Threshold, ShortformDetector.warn3Threshold]
            .enumerated()
            .map { "\($0.offset + 1)단계 \(Self.format($0.element * m))" }
        return "숏폼을 계속 보면 " + steps.joined(separator: " → ") + " 뒤에 경고해요."
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return s % 60 == 0 ? "\(s / 60)분" : (s < 60 ? "\(s)초" : "\(s / 60)분 \(s % 60)초")
    }
}
