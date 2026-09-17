import SwiftUI

/// 시선 방향(3프레임). 기획서 모션 목록 "시선 따라가기 | 커서 이동 | 3 | O"에 대응.
enum EyeLook {
    case left, center, right, closed // closed: 쓰다듬는 동안

    /// 스프라이트가 좌우 반전되어 있을 때 실제로 그려야 할 눈 위치.
    var flipped: EyeLook {
        switch self {
        case .left: return .right
        case .right: return .left
        case .center, .closed: return self
        }
    }
}

/// 뚱냥이 픽셀 스프라이트 플레이스홀더 데이터.
// ponytail: 손으로 짠 13x8 픽셀 아트. 로드맵 2단계(픽셀 존 커스텀 에디터)가 나오면
// 저장된 zone 데이터로 교체.
enum CatSprite {
    static let width = 13

    /// 머리+몸통+꼬리 (프레임 공통, 눈 줄/다리 줄만 상황별로 다름)
    private static let template: [String] = [
        "..O.....O....",
        "..OP....PO...",
        ".OBBBBBBBBO..",
        ".OBKBBBKBBO..", // index 3: 눈 (동적으로 교체됨)
        ".OBBBPPBBBO..",
        ".OBBBBBBBBOBO",
        "OBWWWWWWWBOO.",
    ]

    private static func eyeRow(_ look: EyeLook) -> String {
        switch look {
        case .center: return ".OBKBBBKBBO.."
        case .left: return ".OKBBBKBBBO.."
        case .right: return ".OBBKBBBKBO.."
        case .closed: return ".OBOBBBOBBO.." // 눈 대신 감은 눈꺼풀 선(O)
        }
    }

    static func bodyRows(eyeLook: EyeLook) -> [String] {
        var rows = template
        rows[3] = eyeRow(eyeLook)
        return rows
    }

    static let colors: [Character: Color] = [
        "O": Color(red: 0.23, green: 0.14, blue: 0.09), // 외곽선
        "B": Color(red: 0.88, green: 0.55, blue: 0.29), // 몸통(주황)
        "W": Color.white,                                // 배/발
        "K": Color(red: 0.13, green: 0.13, blue: 0.13), // 눈
        "P": Color(red: 0.95, green: 0.66, blue: 0.75), // 코/귀 안쪽
    ]
}

/// Idle/배회/사냥/타이핑 애니메이션 프레임.
/// 기획서 모션 목록의 "Idle 대기"·"배회"·"사냥 자세"·"타이핑 꾹꾹이"·"과열 모드" 항목에 대응.
enum CatFrame: Equatable {
    case idleStand, walk1, walk2, sit, hunt1, hunt2, typing1, typing2, overheat1, overheat2

    func rows(eyeLook: EyeLook) -> [String] {
        let head = CatSprite.bodyRows(eyeLook: eyeLook)
        switch self {
        case .idleStand: return head + ["..OW....WO..."]
        case .walk1: return head + [".OW......WO.."]
        case .walk2: return head + ["...OW..WO...."]
        case .sit: return head + ["....BBBB....."]
        case .hunt1: return head + ["OW.........WO"] // 자세 낮추고 다리를 넓게
        case .hunt2: return head + [".OW.......WO."] // 살짝 당겨 꼬리 씰룩
        case .typing1: return head + ["....WW.WW...."] // 꾹꾹이 - 앞발 모으고
        case .typing2: return head + ["...WW...WW..."] // 꾹꾹이 - 앞발 벌리고
        case .overheat1: return head + ["....BBBB....."] // 과열 - 몸 웅크림 (색은 CatView에서 붉게 틴트)
        case .overheat2: return head + ["...BBBB......"] // 과열 - 살짝 떨림
        }
    }

    /// 붉은 틴트 + 김 이펙트를 씌울지 여부.
    var isOverheating: Bool {
        self == .overheat1 || self == .overheat2
    }
}

/// 픽셀 행 데이터를 격자로 그리는 공용 렌더러.
struct PixelSpriteView: View {
    let rows: [String]
    var pixelSize: CGFloat = 8

    var body: some View {
        Canvas { context, _ in
            for (y, row) in rows.enumerated() {
                for (x, char) in row.enumerated() {
                    guard let color = CatSprite.colors[char] else { continue }
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize,
                        y: CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(rows.map(\.count).max() ?? 0) * pixelSize,
            height: CGFloat(rows.count) * pixelSize
        )
    }
}
