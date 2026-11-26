import Foundation

/// 갤러리 서버(server/) 통신. 인증 없이 기기 UUID(X-Device-Id)로 좋아요 중복·업로드 횟수만 제한된다.
struct GalleryItem: Codable, Identifiable, Equatable {
    let id: Int
    let nickname: String
    let catName: String
    let design: PixelOverrides
    var likeCount: Int
    var likedByMe: Bool
}

enum GallerySort: String, Hashable {
    case latest, popular
}

struct GalleryError: LocalizedError {
    let errorDescription: String?
}

enum GalleryClient {
    // ponytail: 로컬 개발 서버 고정. 배포하면 defaults write com.stopmeow.app settings.galleryServerURL <주소>로 교체하거나 기본값을 바꿈.
    static var baseURL: URL {
        URL(string: UserDefaults.standard.string(forKey: SettingsKey.galleryServerURL) ?? "") ?? URL(string: "http://localhost:8080")!
    }

    /// 최초 호출 때 만든 UUID를 계속 재사용. 서버엔 좋아요/업로드 제한 용도로만 쓰인다(PRD 프라이버시 항목).
    static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: SettingsKey.deviceID) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: SettingsKey.deviceID)
        return id
    }

    struct Page: Decodable {
        let items: [GalleryItem]
        let hasNext: Bool
    }

    struct LikeResult: Decodable {
        let likeCount: Int
        let likedByMe: Bool
    }

    private struct ServerError: Decodable {
        let message: String?
    }

    private struct UploadBody: Encodable {
        let nickname: String
        let catName: String
        let design: PixelOverrides
    }

    static func list(sort: GallerySort, page: Int) async throws -> Page {
        try await send("GET", "api/customs?sort=\(sort.rawValue)&page=\(page)&size=30")
    }

    static func upload(nickname: String, catName: String, design: PixelOverrides) async throws -> GalleryItem {
        try await send("POST", "api/customs", body: JSONEncoder().encode(UploadBody(nickname: nickname, catName: catName, design: design)))
    }

    static func like(id: Int) async throws -> LikeResult {
        try await send("POST", "api/customs/\(id)/like")
    }

    private static func send<T: Decodable>(_ method: String, _ path: String, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GalleryError(errorDescription: "갤러리 서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            // 서버가 사유를 보냈으면(금칙어, 업로드 횟수 초과 등) 그대로 보여준다.
            let message = (try? JSONDecoder().decode(ServerError.self, from: data))?.message
            let useful = message.flatMap { $0.isEmpty || $0.hasPrefix("Validation failed") ? nil : $0 }
            throw GalleryError(errorDescription: useful ?? (status == 400 ? "입력한 내용을 확인해 주세요." : "잠시 후 다시 시도해 주세요. (\(status))"))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
