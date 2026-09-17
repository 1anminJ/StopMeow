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
        // 쓰다듬는 동안은 배회 프레임 대신 차분한 앉은 자세 + 감은 눈을 강제로 보여준다.
        // TODO: 나중에 눈 감은 채로 하트 이펙트 띄우기
        let displayFrame = state.isPetting ? .sit : state.frame
        let displayEyeLook = state.isPetting ? .closed : state.eyeLook
        let overheating = displayFrame.isOverheating

        ZStack(alignment: .top) {
            PixelSpriteView(rows: displayFrame.rows(eyeLook: displayEyeLook))
                // ponytail: "빨개짐"은 픽셀을 새로 그리는 대신 색 틴트로 근사.
                .colorMultiply(overheating ? Color(red: 1, green: 0.55, blue: 0.5) : .white)
            if overheating {
                SteamPuff().offset(y: -10) // "김"
            }
        }
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

/// 과열 상태일 때 머리 위로 피어오르는 김 한 방울.
private struct SteamPuff: View {
    @State private var rise = false

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.7))
            .frame(width: 6, height: 6)
            .offset(y: rise ? -14 : -4)
            .opacity(rise ? 0 : 0.8)
            .animation(.easeOut(duration: 0.6).repeatForever(autoreverses: false), value: rise)
            .onAppear { rise = true }
    }
}
