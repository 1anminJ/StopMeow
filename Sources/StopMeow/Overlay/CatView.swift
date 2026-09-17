import SwiftUI

/// 렌더링에 필요한 현재 프레임/방향/시선만 들고 있는 최소 상태.
/// 위치는 View가 아니라 윈도우(OverlayWindowController)가 직접 옮긴다.
final class CatAnimationState: ObservableObject {
    @Published var frame: CatFrame = .idleStand
    @Published var facingRight: Bool = true
    @Published var eyeLook: EyeLook = .center
    @Published var isDragging: Bool = false
    @Published var isPetting: Bool = false
}

struct CatView: View {
    @ObservedObject var state: CatAnimationState

    var body: some View {
        // 쓰다듬는 동안은 배회 프레임 대신 차분한 앉은 자세를 강제로 보여준다.
        let displayFrame = state.isPetting ? .sit : state.frame

        PixelSpriteView(rows: displayFrame.rows(eyeLook: state.eyeLook))
            .scaleEffect(x: state.facingRight ? 1 : -1, y: 1)
            // ponytail: 드래그 "늘어남"은 스쿼시 변형으로, 쓰다듬기 "골골"은 반복 펄스로 근사.
            // 모션 목록의 전용 픽셀 프레임은 아트 준비되면 교체.
            .scaleEffect(x: state.isDragging ? 0.88 : 1, y: state.isDragging ? 1.18 : 1)
            .scaleEffect(state.isPetting ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: state.isDragging)
            .animation(
                state.isPetting
                    ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: state.isPetting
            )
    }
}
