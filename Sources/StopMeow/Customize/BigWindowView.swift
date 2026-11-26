import SwiftUI

/// 메뉴바 "멈춰묘 설정…"로 여는 큰 창의 최상위 뷰. 탭으로 이름/디자인/갤러리/생산성/숏폼을 오간다.
/// 갤러리 탭은 server/ 의 갤러리 API와 통신한다(로드맵 4단계).
enum BigWindowTab: Hashable {
    case name, design, gallery, productivity, shortform
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
                PillTabBar(tabs: [(.name, "이름"), (.design, "디자인"), (.gallery, "갤러리"), (.productivity, "생산성"), (.shortform, "숏폼 방해")], selection: $tab)
                if tab == .design {
                    let dirty = draftDesign != savedDesign
                    Button("코드 붙여넣기") { pasteCode() }
                        .buttonStyle(PixelButtonStyle(background: CuteTheme.card, foreground: CuteTheme.textPrimary))
                        .frame(width: 120)
                    Button(copied ? "복사됨!" : "코드 복사") { copyCode() }
                        .buttonStyle(PixelButtonStyle(background: CuteTheme.card, foreground: CuteTheme.textPrimary))
                        .frame(width: 104)
                        .disabled(draftDesign.isEmpty)
                        .help("이 디자인의 공유 코드를 복사해요. 웹 갤러리 \"내 고양이 올리기\"에 붙여넣으면 돼요")
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
            case .gallery:
                GalleryView { design in
                    PixelOverrideStore.save(design)
                    savedDesign = design
                    draftDesign = design
                }
            case .productivity: ProductivitySettingsView()
            case .shortform: ShortformSettingsView()
            }
        }
        .background(CuteTheme.background)
        .alert("코드를 불러오지 못했어요", isPresented: Binding(get: { pasteError != nil }, set: { if !$0 { pasteError = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(pasteError ?? "")
        }
    }

    @State private var pasteError: String?
    @State private var copied = false

    /// 지금 화면의 디자인(저장 전 초안 포함)을 공유 코드로 클립보드에 복사한다.
    private func copyCode() {
        guard let code = ShareCode.encode(draftDesign) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    /// 클립보드의 공유 코드를 초안으로 불러온다. 저장은 사용자가 "저장"으로 한다.
    private func pasteCode() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        do { draftDesign = try ShareCode.decode(text) } catch { pasteError = error.localizedDescription }
    }
}
