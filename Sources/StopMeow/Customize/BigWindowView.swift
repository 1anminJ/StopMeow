import SwiftUI

/// 메뉴바 "멈춰묘 설정…"로 여는 큰 창의 최상위 뷰. 탭으로 이름/디자인/생산성/숏폼을 오간다.
/// 갤러리 탭은 서버(로드맵 4단계)가 준비되면 여기에 추가될 예정.
enum BigWindowTab: Hashable {
    case design, name, productivity, shortform
}

struct BigWindowView: View {
    @State private var tab: BigWindowTab = .name

    var body: some View {
        VStack(spacing: 0) {
            PillTabBar(tabs: [(.name, "이름"), (.design, "디자인"), (.productivity, "생산성"), (.shortform, "숏폼 방해")], selection: $tab)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(CuteTheme.background)

            switch tab {
            case .design: PixelZoneEditorView()
            case .name: NameSettingsView()
            case .productivity: ProductivitySettingsView()
            case .shortform: ShortformSettingsView()
            }
        }
        .background(CuteTheme.background)
    }
}
