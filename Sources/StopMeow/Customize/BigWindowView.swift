import SwiftUI

/// 메뉴바 "디자인 열기"로 여는 큰 창의 최상위 뷰. 탭으로 디자인/이름을 오간다.
/// 갤러리 탭은 서버(로드맵 4단계)가 준비되면 여기에 추가될 예정.
enum BigWindowTab: Hashable {
    case design, name
}

struct BigWindowView: View {
    @State private var tab: BigWindowTab = .design

    var body: some View {
        VStack(spacing: 0) {
            PillTabBar(tabs: [(.design, "디자인"), (.name, "이름")], selection: $tab)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(CuteTheme.background)

            switch tab {
            case .design: PixelZoneEditorView()
            case .name: NameSettingsView()
            }
        }
        .background(CuteTheme.background)
    }
}
