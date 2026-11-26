import SwiftUI

/// 메뉴바 "멈춰묘 설정…"로 여는 큰 창의 최상위 뷰. 탭으로 이름/디자인/생산성/숏폼을 오간다.
/// 갤러리 탭은 서버(로드맵 4단계)가 준비되면 여기에 추가될 예정.
enum BigWindowTab: Hashable {
    case name, design, productivity, shortform
}

struct BigWindowView: View {
    @State private var tab: BigWindowTab = .name
    // 디자인 초안은 탭 전환에도 유지되도록 에디터가 아닌 여기서 들고 있는다.
    // 창을 닫으면 DesignWindowController가 이 뷰를 새로 만들어 저장 안 한 초안을 버린다.
    @State private var savedDesign: PixelOverrides = PixelOverrideStore.load()
    @State private var draftDesign: PixelOverrides = PixelOverrideStore.load()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PillTabBar(tabs: [(.name, "이름"), (.design, "디자인"), (.productivity, "생산성"), (.shortform, "숏폼 방해")], selection: $tab)
                if tab == .design {
                    let dirty = draftDesign != savedDesign
                    Button(dirty ? "저장" : "저장됨") {
                        PixelOverrideStore.save(draftDesign)
                        savedDesign = draftDesign
                    }
                    .buttonStyle(PixelButtonStyle())
                    .frame(width: 96)
                    .disabled(!dirty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(CuteTheme.background)

            switch tab {
            case .name: NameSettingsView()
            case .design: PixelZoneEditorView(overrides: $draftDesign)
            case .productivity: ProductivitySettingsView()
            case .shortform: ShortformSettingsView()
            }
        }
        .background(CuteTheme.background)
    }
}
