import SwiftUI

/// "멈춰묘 디자인" 창 전용 귀여운 비주얼 테마 + 커스텀 컨트롤.
/// 시스템 기본 세그먼트/버튼 느낌 대신, 고양이 스프라이트 팔레트(주황/크림/진갈색)와
/// 통일된 둥근 알약 모양 컨트롤을 쓴다. 색상 선택 자체(색상환)는 시스템 ColorPicker를
/// 그대로 재사용하되(직접 만들면 배보다 배꼽이 큼), 겉모습만 칩처럼 새로 감싼다.
enum CuteTheme {
    static let background = Color(red: 1.0, green: 0.97, blue: 0.92)   // 크림 배경
    static let card = Color(red: 0.98, green: 0.91, blue: 0.81)        // 카드/칩 배경
    static let accent = Color(red: 0.88, green: 0.55, blue: 0.29)      // 고양이 몸통 주황
    static let accentDark = Color(red: 0.62, green: 0.37, blue: 0.18)
    static let textPrimary = Color(red: 0.23, green: 0.14, blue: 0.09) // 고양이 외곽선 갈색
    static let destructive = Color(red: 0.82, green: 0.42, blue: 0.40)
}

/// 진하게 채워진 알약 버튼 (예: "선택한 존 전체 칠하기").
struct PixelButtonStyle: ButtonStyle {
    var background: Color = CuteTheme.accent
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(isEnabled ? background : background.opacity(0.35))
            )
            .foregroundStyle(isEnabled ? foreground : foreground.opacity(0.7))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 옅은 카드색 알약 버튼 (예: 템플릿 버튼).
struct PixelSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(CuteTheme.card)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .foregroundStyle(CuteTheme.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 섹션 제목: 발바닥 아이콘 + 둥근 굵은 글씨.
struct SectionHeader: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.caption2)
                .foregroundStyle(CuteTheme.accent)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(CuteTheme.textPrimary)
        }
    }
}

/// "존" 선택용 커스텀 알약형 세그먼트 (시스템 Picker(.segmented) 대체).
struct ZonePillPicker: View {
    @Binding var selection: BodyZone?

    var body: some View {
        HStack(spacing: 6) {
            pill(title: "전체", isSelected: selection == nil) { selection = nil }
            ForEach(BodyZone.allCases) { zone in
                pill(title: zone.label, isSelected: selection == zone) { selection = zone }
            }
        }
    }

    private func pill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(isSelected ? CuteTheme.accent : CuteTheme.card))
                .foregroundStyle(isSelected ? Color.white : CuteTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

/// 라벨 + 둥근 색상 칩. 탭하면 시스템 색상 선택기가 뜨는 건 ColorPicker 그대로,
/// 겉모습만 카드 느낌 칩으로 새로 그린다.
struct ColorSwatchRow: View {
    let title: String
    @Binding var color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary)
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(CuteTheme.accentDark.opacity(0.35), lineWidth: 1.5)
                )
        }
    }
}

/// 카드 배경 (미리보기/그리드 등을 크림 배경 위에서 도드라져 보이게).
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: CuteTheme.accentDark.opacity(0.12), radius: 6, y: 3)
            )
    }
}

extension View {
    func cardBackground() -> some View { modifier(CardBackground()) }
}
