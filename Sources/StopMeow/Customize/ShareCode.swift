import Foundation

/// 디자인 공유 코드: "STOPMEOW1:" + base64url(raw DEFLATE(JSON)).
/// 웹 갤러리(StopMeow_Page의 scripts/lib.mjs, site/app.js)와 같은 형식이라 서로 주고받을 수 있다.
enum ShareCode {
    static let prefix = "STOPMEOW1:"

    static func encode(_ design: PixelOverrides) -> String? {
        guard let json = try? JSONSerialization.data(withJSONObject: design, options: .sortedKeys),
              let packed = try? (json as NSData).compressed(using: .zlib) as Data
        else { return nil }
        let b64 = packed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + b64
    }

    /// 웹 갤러리(StopMeow_Page)의 업로드 이슈 양식을 이름·코드가 채워진 채로 여는 주소.
    /// 쿼리 이름(cat-name, code)은 .github/ISSUE_TEMPLATE/submit-cat.yml의 필드 id와 같아야 한다.
    static func uploadURL(code: String, catName: String) -> URL? {
        var parts = URLComponents(string: "https://github.com/1anminJ/StopMeow_Page/issues/new")
        parts?.queryItems = [
            URLQueryItem(name: "template", value: "submit-cat.yml"),
            URLQueryItem(name: "title", value: "[고양이 공유] \(catName)"),
            URLQueryItem(name: "cat-name", value: catName),
            URLQueryItem(name: "code", value: code),
        ]
        return parts?.url
    }

    enum DecodeError: LocalizedError {
        case format, content
        var errorDescription: String? {
            switch self {
            case .format: return "멈춰묘 공유 코드가 아니에요. STOPMEOW1: 로 시작하는 코드를 복사해 주세요."
            case .content: return "코드 안의 디자인이 올바르지 않아요."
            }
        }
    }

    static func decode(_ raw: String) throws -> PixelOverrides {
        let code = raw.filter { !$0.isWhitespace }
        // 클립보드 입력이라 길이를 제한해 압축 폭탄을 막는다(정상 코드는 1KB 안팎).
        guard code.hasPrefix(prefix), code.count < 4096 else { throw DecodeError.format }
        var b64 = String(code.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
        guard let packed = Data(base64Encoded: b64),
              let json = try? (packed as NSData).decompressed(using: .zlib) as Data,
              let design = try? JSONDecoder().decode(PixelOverrides.self, from: json)
        else { throw DecodeError.format }

        let key = try! Regex(#"(\d{1,2}_\d{1,2}|part_[A-Z])"#)
        let hex = try! Regex("#[0-9A-Fa-f]{6}")
        guard !design.isEmpty, design.count <= 200,
              design.allSatisfy({ $0.key.wholeMatch(of: key) != nil && $0.value.wholeMatch(of: hex) != nil })
        else { throw DecodeError.content }
        return design
    }
}
