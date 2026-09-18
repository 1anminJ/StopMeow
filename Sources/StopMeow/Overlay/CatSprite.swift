import AppKit
import SwiftUI

/// 시선 방향(3프레임). 기획서 모션 목록 "시선 따라가기 | 커서 이동 | 3 | O"에 대응.
enum EyeLook: Equatable {
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

/// 커스텀 가능한 존. 기획서 "머리 / 등 / 꼬리 / 다리".
enum BodyZone: String, CaseIterable, Identifiable {
    case head, back, tail, legs
    var id: String { rawValue }

    var label: String {
        switch self {
        case .head: return "머리"
        case .back: return "등"
        case .tail: return "꼬리"
        case .legs: return "다리"
        }
    }
}

/// 픽셀 단위 커스텀 색. 키는 "row_col"(원본 13x8 좌표), 값은 "#RRGGBB".
/// 존(zone)은 에디터에서 "이 픽셀이 어디 소속인지" 구분하는 용도일 뿐 — 실제 칠은 픽셀 단위로 저장되므로
/// 줄무늬·점박이 같은 존 내부 무늬도 표현 가능하다.
typealias PixelOverrides = [String: String]

func pixelKey(row: Int, col: Int) -> String { "\(row)_\(col)" }

/// 뚱냥이 픽셀 스프라이트. 원본은 13x8로 짜여있고, 실제 표시할 땐 32(가로) 기준으로
/// 최근접 이웃 방식으로 확대한다 — 손으로 짠 애니메이션(걷기/사냥/타이핑 등)은 그대로 두고
/// 해상도만 키워서 존 커스텀 무늬가 디테일하게 보이게 함.
// ponytail: 12개 프레임을 32x32로 새로 그리는 대신, 검증된 기존 13x8 데이터를 확대하는 쪽을 선택.
// 애니메이션 회귀 위험이 없고, 존 매핑도 원본 저해상도 좌표 기준이라 훨씬 단순함.
enum CatSprite {
    static let sourceWidth = 13
    static let sourceHeight = 8

    static let width = 32
    static let heightRows = Int((Double(sourceHeight) * Double(width) / Double(sourceWidth)).rounded()) // 20
    static let jumpHeadroomRows = 5 // sourceHeight 기준 2줄에 해당하는 물리적 여유를 유지
    static let pixelSize: CGFloat = 3.25 // 32*3.25=104pt, 기존 작은 오버레이 크기 유지

    /// 머리+몸통+꼬리 (프레임 공통, 눈 줄/다리 줄만 상황별로 다름) — 원본 13x8 해상도.
    private static let template: [String] = [
        "..O.....O....",
        "..OP....PO...",
        ".OBBBBBBBBO..",
        ".OBKBBBKBBO..", // index 3: 눈 (동적으로 교체됨)
        ".OBBBPPBBBO..",
        ".OBBBBBBBBOBO",
        "OBWWWWWWWBOO.",
    ]

    /// template과 같은 좌표계의 존 지도. 'B'(몸통색) 픽셀에만 의미가 있고 나머지는 무시된다
    /// (눈/코/발바닥 등 고정 팔레트는 기획서대로 커스텀 대상이 아님).
    private static let zoneTemplate: [String] = [
        ".............",
        ".............",
        "..HHHHHHHH...",
        "..HHHHHHHH...",
        "..HHHHHHHH...",
        "..CCCCCCCC.T.",
        ".C.......C...",
    ]

    private static func eyeRow(_ look: EyeLook) -> String {
        switch look {
        case .center: return ".OBKBBBKBBO.."
        case .left: return ".OKBBBKBBBO.."
        case .right: return ".OBBKBBBKBO.."
        case .closed: return ".OBBBBBBBBO.." // 눈동자(K) 자리를 몸통색으로 지워 "눈 감음"을 표현
        // (O로 하면 원래 눈동자 K랑 색이 거의 같아서 이 작은 크기에선 티가 안 남 — 눈을 아예 지워야 확실히 보임)
        }
    }

    static func bodyRows(eyeLook: EyeLook) -> [String] {
        var rows = template
        rows[3] = eyeRow(eyeLook)
        return rows
    }

    static let colors: [Character: Color] = [
        "O": Color(red: 0.23, green: 0.14, blue: 0.09), // 외곽선
        "B": Color(red: 0.88, green: 0.55, blue: 0.29), // 몸통(주황, 기본값)
        "W": Color.white,                                // 배/발
        "K": Color(red: 0.13, green: 0.13, blue: 0.13), // 눈
        "P": Color(red: 0.95, green: 0.66, blue: 0.75), // 코/귀 안쪽
    ]

    /// (row, col)의 몸통색(B) 픽셀이 속한 존. 마지막 줄(다리/자세)은 프레임마다 모양이 달라도
    /// 항상 "다리" 존으로 취급한다.
    static func zone(row: Int, col: Int, isLastRow: Bool, char: Character) -> BodyZone? {
        guard char == "B" else { return nil }
        if isLastRow { return .legs }
        guard row < zoneTemplate.count else { return nil }
        let zoneChars = Array(zoneTemplate[row])
        guard col < zoneChars.count else { return nil }
        switch zoneChars[col] {
        case "H": return .head
        case "C": return .back
        case "T": return .tail
        default: return nil
        }
    }

    /// 최근접 이웃 방식 확대. 픽셀 아트 특유의 블록 느낌을 유지한다.
    static func upscale<T>(_ source: [[T]], toWidth: Int, toHeight: Int) -> [[T]] {
        (0..<toHeight).map { y in
            let srcY = min(source.count - 1, y * source.count / toHeight)
            let srcRow = source[srcY]
            return (0..<toWidth).map { x in
                srcRow[min(srcRow.count - 1, x * srcRow.count / toWidth)]
            }
        }
    }
}

/// Idle/배회/사냥/타이핑 애니메이션 프레임 (원본 13x8 좌표계).
/// 기획서 모션 목록의 "Idle 대기"·"배회"·"사냥 자세"·"타이핑 꾹꾹이"·"과열 모드" 항목에 대응.
enum CatFrame: Equatable {
    case idleStand, walk1, walk2, sit, hunt1, hunt2, typing1, typing2, overheat1, overheat2
    case wave1, wave2 // 숏폼 경고1 - 구석에서 손짓

    /// 원본(13x8) 해상도 행 데이터.
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
        case .wave1: return head + [".OW.........."] // 손짓 - 한쪽 발 들고
        case .wave2: return head + ["..........WO."] // 손짓 - 반대쪽 발 들고
        }
    }

    /// 픽셀 단위 커스텀 색을 반영해 표시 해상도(32 기준)로 확대한 최종 컬러 그리드.
    /// 커스텀은 몸통색(B) 픽셀에만 적용된다 — 눈/코/발바닥 등 고정 팔레트는 항상 그대로.
    func displayColors(eyeLook: EyeLook, overrides: PixelOverrides = [:]) -> [[Color]] {
        let sourceRows = rows(eyeLook: eyeLook)
        let sourceColors: [[Color]] = sourceRows.enumerated().map { rowIndex, row in
            row.enumerated().map { colIndex, char -> Color in
                if char == "B",
                   let hex = overrides[pixelKey(row: rowIndex, col: colIndex)],
                   let custom = Color(hex: hex) {
                    return custom
                }
                return CatSprite.colors[char] ?? .clear
            }
        }
        return CatSprite.upscale(sourceColors, toWidth: CatSprite.width, toHeight: CatSprite.heightRows)
    }

    /// 붉은 틴트 + 김 이펙트를 씌울지 여부.
    var isOverheating: Bool {
        self == .overheat1 || self == .overheat2
    }
}

/// 컬러 그리드를 진짜 고정 픽셀 크기의 비트맵(CGImage)으로 굽는다.
// ponytail: 두 번 잘못 짚었던 부분 —
// 1) Canvas로 칸마다 fill하면 pixelSize가 소수(3.25 등)일 때 칸 경계에 안티앨리어싱 이음새가 생김.
// 2) NSImage(size:flipped:drawingHandler:)는 "해상도 독립적" 이미지라, 화면에 그릴 때마다
//    실제로 표시되는(확대된) 크기로 클로저를 다시 실행함 — 결국 이음새 문제가 그대로 재발했고,
//    더 자주 다시 그리다 보니 깜빡임도 심해짐.
// CGContext로 실제 픽셀 버퍼(원본 해상도 그대로)를 직접 채워서 고정 크기 CGImage를 만들면
// 전역 그리기 상태(lockFocus)도, 재호출 문제(drawingHandler)도 없다 — 이후엔 순수 텍스처라
// SwiftUI가 최근접 이웃으로 한 번만 확대해서 그린다.
func pixelGridImage(_ colors: [[Color]]) -> NSImage {
    let rows = colors.count
    let cols = colors.first?.count ?? 0
    let bytesPerPixel = 4
    let bytesPerRow = cols * bytesPerPixel

    // data: nil -> Core Graphics가 버퍼를 직접 소유/관리한다.
    // ponytail 실수 3: 이전엔 로컬 Swift 배열(&pixelData)을 CGContext에 넘겼는데, CGContext는
    // 그 메모리를 복사하지 않고 그대로 참조할 수 있어서 함수가 끝나 배열이 해제된 뒤엔 댕글링
    // 포인터가 됐다 — 가끔(타이밍에 따라) 그 메모리가 재사용되면서 빈 이미지처럼 보여 깜빡였다.
    // CG가 버퍼를 소유하게 하면 CGImage와 수명이 함께 묶여서 이 문제가 없다.
    guard rows > 0, cols > 0,
          let context = CGContext(
            data: nil,
            width: cols,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ),
          let buffer = context.data
    else { return NSImage() }

    let pixels = buffer.assumingMemoryBound(to: UInt8.self)
    for (y, row) in colors.enumerated() {
        for (x, color) in row.enumerated() {
            let rgba = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.clear
            let offset = y * bytesPerRow + x * bytesPerPixel
            pixels[offset] = UInt8((rgba.redComponent * 255).rounded())
            pixels[offset + 1] = UInt8((rgba.greenComponent * 255).rounded())
            pixels[offset + 2] = UInt8((rgba.blueComponent * 255).rounded())
            pixels[offset + 3] = UInt8((rgba.alphaComponent * 255).rounded())
        }
    }

    guard let cgImage = context.makeImage() else { return NSImage() }
    return NSImage(cgImage: cgImage, size: NSSize(width: cols, height: rows))
}

/// 컬러 그리드(표시 해상도)를 그리는 공용 렌더러.
struct PixelSpriteView: View {
    let colors: [[Color]]
    var pixelSize: CGFloat = 8

    private var nativeImage: NSImage {
        pixelGridImage(colors)
    }

    var body: some View {
        Image(nsImage: nativeImage)
            .interpolation(.none)
            .resizable()
            .frame(
                width: CGFloat(colors.first?.count ?? 0) * pixelSize,
                height: CGFloat(colors.count) * pixelSize
            )
    }
}
