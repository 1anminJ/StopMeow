import SwiftUI

/// 픽셀 존 커스텀 에디터. 기준 포즈(가만히 서있는 정면) 위에서 몸통색(B) 픽셀만 칠한다.
/// 저장은 즉시 반영되어 실제 배회 중인 고양이에도 바로 나타난다(다음 렌더 프레임에 다시 읽어옴).
/// 로드맵 2단계.
struct PixelZoneEditorView: View {
    @State private var overrides: PixelOverrides = PixelOverrideStore.load()
    @State private var paintColor: Color = Color(red: 0.88, green: 0.55, blue: 0.29)
    @State private var selectedZone: BodyZone?

    private let referenceRows = CatFrame.idleStand.rows(eyeLook: .center)

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("기준 포즈에서 칠하기").font(.headline)
                pixelGrid
                Text("색칠된 칸만 칠할 수 있어요 (눈·코·발바닥 등은 고정 색상)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("미리보기").font(.headline)
                PixelSpriteView(
                    colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: overrides),
                    pixelSize: 10
                )
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Divider()

                ColorPicker("칠할 색", selection: $paintColor, supportsOpacity: false)

                Picker("존", selection: $selectedZone) {
                    Text("전체").tag(BodyZone?.none)
                    ForEach(BodyZone.allCases) { zone in
                        Text(zone.label).tag(BodyZone?.some(zone))
                    }
                }
                .pickerStyle(.segmented)

                Button("선택한 존 전체 칠하기") { fillSelectedZone() }
                    .disabled(selectedZone == nil)

                Divider()

                Text("템플릿").font(.subheadline.weight(.medium))
                HStack {
                    Button("빈 캔버스") { clearAll() }
                    Button("줄무늬") { applyStripes() }
                    Button("점박이") { applySpots() }
                }

                Spacer()
            }
            .frame(width: 220)
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 420)
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

    private func pixelCell(row: Int, col: Int, char: Character) -> some View {
        let paintable = char == "B"
        let key = pixelKey(row: row, col: col)
        let currentColor: Color = paintable
            ? (overrides[key].flatMap { Color(hex: $0) } ?? (CatSprite.colors[char] ?? .clear))
            : (CatSprite.colors[char] ?? .clear)

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

    private func fillSelectedZone() {
        guard let zone = selectedZone else { return }
        forEachPaintablePixel { row, col, isLastRow in
            if CatSprite.zone(row: row, col: col, isLastRow: isLastRow, char: "B") == zone {
                overrides[pixelKey(row: row, col: col)] = paintColor.hexString
            }
        }
        persist()
    }

    private func clearAll() {
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
