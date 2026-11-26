import SwiftUI

/// 큰 창의 "이름" 탭. 고양이 이름을 지어주고 바로 저장한다.
/// 이름을 실제로 불러주는 인터랙션(리마인더 문구 등)은 PRD상 Post-MVP 확장 항목이라 아직 없고,
/// 지금은 설정값 저장까지만 담당한다.
struct NameSettingsView: View {
    @State private var name: String = UserDefaults.standard.string(forKey: SettingsKey.catName) ?? "멈춰묘"

    var body: some View {
        VStack(spacing: 20) {
            SectionHeader(text: "이름 지어주기")

            PixelSpriteView(
                colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: PixelOverrideStore.load()),
                pixelSize: 10
            )
            .padding(10)
            .cardBackground()

            Text(name.isEmpty ? "이름을 입력해주세요" : name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CuteTheme.textPrimary)

            TextField("고양이 이름", text: $name)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: 220)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(CuteTheme.accentDark.opacity(0.35), lineWidth: 1.5))
                .multilineTextAlignment(.center)
                .onChange(of: name) { _, newValue in
                    persist(newValue)
                }

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CuteTheme.background)
    }

    private func persist(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.catName)
    }
}
