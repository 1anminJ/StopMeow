import SwiftUI

/// 렌더링에 필요한 현재 프레임/방향/시선만 들고 있는 최소 상태.
/// 위치는 View가 아니라 윈도우(OverlayWindowController)가 직접 옮긴다.
final class CatAnimationState: ObservableObject {
    @Published var frame: CatFrame = .idleStand
    @Published var facingRight: Bool = true
    @Published var eyeLook: EyeLook = .center
    @Published var isDragging: Bool = false
}

struct CatView: View {
    @ObservedObject var state: CatAnimationState

    var body: some View {
        PixelSpriteView(rows: state.frame.rows(eyeLook: state.eyeLook))
            .scaleEffect(x: state.facingRight ? 1 : -1, y: 1)
            // ponytail: 드래그 중 "늘어남" 모션은 스쿼시 변형으로 근사.
            // 모션 목록의 전용 드래그/흔들기 픽셀 프레임은 아트 준비되면 교체.
            .scaleEffect(x: state.isDragging ? 0.88 : 1, y: state.isDragging ? 1.18 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: state.isDragging)
    }
}
