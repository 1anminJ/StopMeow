import SwiftUI

/// 픽셀 존 커스텀 에디터. 기준 포즈(가만히 서있는 정면) 위에서 몸통색(B) 픽셀만 칠한다.
/// 저장은 즉시 반영되어 실제 배회 중인 고양이에도 바로 나타난다(다음 렌더 프레임에 다시 읽어옴).
/// 로드맵 2단계.
struct PixelZoneEditorView: View {
    @State private var overrides: PixelOverrides = PixelOverrideStore.load()
    @State private var paintColor: Color = Color(red: 0.88, green: 0.55, blue: 0.29)
    @State private var selectedZone: BodyZone?

    // 세 경우 모두 같은 종류의 버그: 기준(idleStand, 정면 시선) 프레임엔 없지만 다른 상태에서만
    // 나타나는 몸통색(B) 칸이 있어서, 그 좌표를 에디터가 노출한 적이 없어 칠할 수 없었다.
    //
    // 1) 마지막 줄(다리): 서있는 자세는 O/W로만 그려 B 칸이 없다. 앉은 자세/과열 자세는 다리를
    //    몸통색 뭉치(B)로 그리는데 그 좌표가 노출되지 않아, 쓰다듬을 때(앉은 자세) 다리만
    //    기본 주황색으로 보였다 — sit·overheat1·overheat2의 다리 모양을 전부 합쳐서 노출한다
    //    (overheat2는 떨림 표현으로 한 칸 왼쪽으로 밀려 있어, sit만으론 그 한 칸이 빠졌었음).
    // 2) 눈 줄(row 3): 시선 방향(왼쪽/오른쪽/감음)마다 눈동자(K)가 다른 칸에 있어서, 정면
    //    기준으로는 몸통(B)인 칸이 옆을 볼 때 눈(K)이 되기도 하고, 반대로 정면엔 눈이라 칠할 수
    //    없었던 칸이 눈을 감으면 몸통(B)이 되기도 한다 — 옆을 보거나 쓰다듬을 때(눈 감음) 그
    //    칸들이 기본 주황색으로 보이는 원인. "눈 감음" 상태는 그 줄의 눈 자리를 전부 몸통색으로
    //    지워서 표현하므로(= 가능한 모든 눈 위치의 합집합), 그 상태를 기준으로 노출하면 모든
    //    시선 방향에서 나올 수 있는 B 칸을 빠짐없이 칠할 수 있다.
    // (미리보기/실제 배회 애니메이션은 여전히 idleStand 기준으로 따로 그려지므로 영향 없음.)
    private let referenceRows: [String] = {
        var rows = CatFrame.idleStand.rows(eyeLook: .center)
        rows[3] = CatFrame.idleStand.rows(eyeLook: .closed)[3]

        var legRow = Array(CatFrame.sit.rows(eyeLook: .center).last!)
        for frame in [CatFrame.overheat1, .overheat2] {
            let frameLegRow = Array(frame.rows(eyeLook: .center).last!)
            for i in legRow.indices where frameLegRow[i] == "B" {
                legRow[i] = "B"
            }
        }
        rows[rows.count - 1] = String(legRow)
        return rows
    }()

    /// 오른쪽 컨트롤 패널 고정 너비. 미리보기 이미지도 이 너비를 넘지 않게 pixelSize를 역산한다.
    private static let controlPanelWidth: CGFloat = 260
    private static let previewPixelSize: CGFloat = 6

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(text: "기준 포즈에서 칠하기")
                pixelGrid
                    .padding(10)
                    .cardBackground()
                Text("몸통은 칸을 눌러 픽셀 단위로 칠하고, 눈·코·발바닥·외곽선은 오른쪽에서 색을 골라요")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))
                Spacer(minLength: 0)
            }
            // 카드 배경의 padding(10) x2만큼 그리드 자체보다 넓어지므로 이를 포함해서 폭을 잡는다.
            // alignment: .leading을 명시해야 혹시라도 내용이 더 넓어졌을 때 왼쪽(텍스트) 대신
            // 오른쪽이 잘린다 — 기본값(center)이면 초과분이 양쪽에서 똑같이 잘려서 텍스트 앞글자가 잘렸었음.
            .frame(width: CGFloat(referenceRows.first?.count ?? 0) * Self.cellSize + 20, alignment: .leading)
            .clipped()

            // 부위별 색상 등 항목이 늘어나도 창 높이에 관계없이 항상 다 보이도록 스크롤 처리.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "미리보기")
                    PixelSpriteView(
                        colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: overrides),
                        pixelSize: Self.previewPixelSize
                    )
                    .padding(10)
                    .cardBackground()

                    ColorSwatchRow(title: "칠할 색", color: $paintColor)

                    ZonePillPicker(selection: $selectedZone)

                    Button("선택한 존 전체 칠하기") { fillSelectedZone() }
                        .buttonStyle(PixelButtonStyle())

                    Divider()

                    SectionHeader(text: "부위별 색상")
                    ColorSwatchRow(title: "몸통 기본색", color: partColor("B"))
                    Text("픽셀 단위로 직접 칠하지 않은 몸통 칸은 이 색을 따라가요")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CuteTheme.textPrimary.opacity(0.5))
                    ColorSwatchRow(title: "외곽선", color: partColor("O"))
                    ColorSwatchRow(title: "눈", color: partColor("K"))
                    ColorSwatchRow(title: "코 / 귀 안쪽", color: partColor("P"))
                    ColorSwatchRow(title: "배 / 발", color: partColor("W"))

                    Divider()

                    SectionHeader(text: "템플릿")
                    HStack(spacing: 8) {
                        Button("줄무늬") { applyStripes() }
                            .buttonStyle(PixelSecondaryButtonStyle())
                        Button("점박이") { applySpots() }
                            .buttonStyle(PixelSecondaryButtonStyle())
                    }

                    Divider()

                    Button("기본값으로 초기화") { resetToDefault() }
                        .buttonStyle(PixelButtonStyle(background: CuteTheme.destructive))
                }
                .frame(width: Self.controlPanelWidth, alignment: .leading)
            }
            .frame(width: Self.controlPanelWidth, alignment: .leading)
            .clipped()
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 480)
        .background(CuteTheme.background)
    }

    // ponytail: 칸 사이 여백/테두리를 없애서 실제 렌더링(Canvas, 이음새 없음)과 같은 느낌으로 —
    // 대신 클릭하기 편하게 칸 크기를 24 -> 32로 키움.
    private static let cellSize: CGFloat = 32

    private var pixelGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<referenceRows.count, id: \.self) { row in
                let rowChars = Array(referenceRows[row])
                HStack(spacing: 0) {
                    ForEach(0..<rowChars.count, id: \.self) { col in
                        pixelCell(row: row, col: col, char: rowChars[col])
                    }
                }
            }
        }
    }

    /// 눈/코/발바닥/외곽선처럼 문자 단위로 저장되는 부위 색 바인딩.
    private func partColor(_ char: Character) -> Binding<Color> {
        Binding(
            get: { overrides[CatSprite.partKey(char)].flatMap { Color(hex: $0) } ?? (CatSprite.colors[char] ?? .black) },
            set: { newColor in
                overrides[CatSprite.partKey(char)] = newColor.hexString
                persist()
            }
        )
    }

    private func pixelCell(row: Int, col: Int, char: Character) -> some View {
        let paintable = char == "B"
        let key = pixelKey(row: row, col: col)
        let currentColor: Color = {
            if paintable, let hex = overrides[key], let custom = Color(hex: hex) { return custom }
            if char != ".", let hex = overrides[CatSprite.partKey(char)], let custom = Color(hex: hex) { return custom }
            return CatSprite.colors[char] ?? .clear
        }()

        return Rectangle()
            .fill(currentColor)
            .frame(width: Self.cellSize, height: Self.cellSize)
            .contentShape(Rectangle())
            .onTapGesture {
                guard paintable else { return }
                overrides[key] = paintColor.hexString
                persist()
            }
    }

    /// selectedZone이 nil이면 "전체"를 뜻한다 — 존 상관없이 칠할 수 있는 몸통 칸을 다 칠한다.
    private func fillSelectedZone() {
        forEachPaintablePixel { row, col, isLastRow in
            if let zone = selectedZone,
               CatSprite.zone(row: row, col: col, isLastRow: isLastRow, char: "B") != zone {
                return
            }
            overrides[pixelKey(row: row, col: col)] = paintColor.hexString
        }
        persist()
    }

    /// 몸통 무늬 + 부위별 색상(눈/코/발바닥/외곽선)을 전부 기본값으로 되돌린다.
    private func resetToDefault() {
        overrides = [:]
        persist()
    }

    /// 짝수 행만 선택한 색으로 칠해 두 톤짜리 줄무늬를 만든다. 항상 빈 캔버스에서 시작.
    private func applyStripes() {
        overrides = [:]
        let hex = paintColor.hexString
        forEachPaintablePixel { row, col, _ in
            if row % 2 == 0 { overrides[pixelKey(row: row, col: col)] = hex }
        }
        persist()
    }

    /// 약 35%의 칸을 무작위로 칠해 점박이 무늬를 만든다. 항상 빈 캔버스에서 시작.
    private func applySpots() {
        overrides = [:]
        let hex = paintColor.hexString
        forEachPaintablePixel { row, col, _ in
            if Double.random(in: 0...1) < 0.35 { overrides[pixelKey(row: row, col: col)] = hex }
        }
        persist()
    }

    private func forEachPaintablePixel(_ body: (_ row: Int, _ col: Int, _ isLastRow: Bool) -> Void) {
        let lastRow = referenceRows.count - 1
        for (row, rowString) in referenceRows.enumerated() {
            for (col, char) in rowString.enumerated() where char == "B" {
                body(row, col, row == lastRow)
            }
        }
    }

    private func persist() {
        PixelOverrideStore.save(overrides)
    }
}
