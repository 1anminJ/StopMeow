import AppKit

/// 메뉴바 아이콘을 기본 이모지 대신 실제(커스텀 반영된) 픽셀 고양이로 그려낸다.
/// 실제 픽셀 굽기는 CatSprite.swift의 pixelGridImage(_:) 공용 함수를 그대로 재사용 —
/// 여기서 따로 lockFocus/drawingHandler를 새로 짜다가 두 번이나 이음새/깜빡임 버그를 냈던 전례가 있음.
enum CatMenuBarIcon {
    static func render() -> NSImage {
        let colors = CatFrame.idleStand.displayColors(eyeLook: .center, overrides: PixelOverrideStore.load())
        return pixelGridImage(colors)
    }
}
