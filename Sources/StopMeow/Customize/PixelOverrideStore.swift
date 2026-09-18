import AppKit
import SwiftUI

/// 픽셀 단위 커스텀 색 저장/불러오기. UserDefaults에 JSON으로 저장.
enum PixelOverrideStore {
    private static let key = "settings.customPixelColors"

    static func load() -> PixelOverrides {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode(PixelOverrides.self, from: data)
        else { return [:] }
        return dict
    }

    static func save(_ overrides: PixelOverrides) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

extension Color {
    /// "#RRGGBB" 형태 문자열로부터 생성. 형식이 잘못되면 nil.
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// "#RRGGBB" 문자열로 변환 (저장/미리보기 용도로 충분한 근사치).
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
