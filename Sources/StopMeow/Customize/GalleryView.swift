import SwiftUI

/// 큰 창의 "갤러리" 탭 (로드맵 4단계). 다른 사람이 올린 고양이를 최신순/인기순으로 보고,
/// 좋아요를 누르거나 내 고양이에 적용하고, 내 고양이(저장된 디자인)를 올린다.
/// 서버가 꺼져 있어도 이 탭만 에러를 보여줄 뿐 나머지 앱은 그대로 동작한다(PRD 오프라인 항목).
struct GalleryView: View {
    /// 적용을 누르면 BigWindowView가 저장·초안을 함께 갱신한다(디자인 탭과 상태가 어긋나지 않게).
    let onApply: (PixelOverrides) -> Void

    @State private var sort: GallerySort = .latest
    @State private var items: [GalleryItem] = []
    @State private var nextPage = 0
    @State private var hasNext = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showUpload = false
    @State private var pendingApply: GalleryItem?
    @State private var appliedID: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PillTabBar(tabs: [(GallerySort.latest, "최신순"), (.popular, "인기순")], selection: $sort)
                Button("내 고양이 올리기") { showUpload = true }
                    .buttonStyle(PixelButtonStyle())
                    .frame(width: 150)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CuteTheme.background)
        .task(id: sort) { await reload() }
        .sheet(isPresented: $showUpload) {
            GalleryUploadSheet {
                // 방금 올린 게 바로 보이도록 최신순으로 새로 불러온다.
                if sort == .latest { Task { await reload() } } else { sort = .latest }
            }
        }
        .confirmationDialog(
            "내 고양이를 \"\(pendingApply?.catName ?? "")\" 디자인으로 바꿀까요?",
            isPresented: Binding(get: { pendingApply != nil }, set: { if !$0 { pendingApply = nil } })
        ) {
            Button("적용하기") {
                if let item = pendingApply {
                    onApply(item.design)
                    appliedID = item.id
                }
                pendingApply = nil
            }
            Button("취소", role: .cancel) { pendingApply = nil }
        } message: {
            Text("지금 저장된 디자인은 덮어써져요.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage, items.isEmpty {
            messageView(errorMessage, retry: true)
        } else if items.isEmpty && isLoading {
            ProgressView().frame(maxHeight: .infinity)
        } else if items.isEmpty {
            messageView("아직 올라온 고양이가 없어요. 첫 번째로 올려보세요!", retry: false)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .padding(.horizontal, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CuteTheme.destructive)
                }
                if hasNext {
                    Button(isLoading ? "불러오는 중…" : "더 보기") { Task { await loadMore() } }
                        .buttonStyle(PixelSecondaryButtonStyle())
                        .frame(width: 140)
                        .disabled(isLoading)
                }
                Spacer(minLength: 20)
            }
        }
    }

    private func messageView(_ text: String, retry: Bool) -> some View {
        VStack(spacing: 12) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
            if retry {
                Button("다시 시도") { Task { await reload() } }
                    .buttonStyle(PixelSecondaryButtonStyle())
                    .frame(width: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func card(_ item: GalleryItem) -> some View {
        VStack(spacing: 8) {
            PixelSpriteView(
                colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: item.design),
                pixelSize: 4
            )
            Text(item.catName)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary)
                .lineLimit(1)
            Text("by \(item.nickname)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))
                .lineLimit(1)
            HStack(spacing: 8) {
                Button {
                    Task { await like(item) }
                } label: {
                    Label("\(item.likeCount)", systemImage: item.likedByMe ? "heart.fill" : "heart")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(CuteTheme.destructive)
                }
                .buttonStyle(.plain)
                .disabled(item.likedByMe)

                Button(appliedID == item.id ? "적용됨" : "적용") { pendingApply = item }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(appliedID == item.id)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .cardBackground()
    }

    private func reload() async {
        nextPage = 0
        await fetch(replacing: true)
    }

    private func loadMore() async {
        await fetch(replacing: false)
    }

    private func fetch(replacing: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await GalleryClient.list(sort: sort, page: nextPage)
            items = replacing ? page.items : items + page.items
            hasNext = page.hasNext
            nextPage += 1
            errorMessage = nil
        } catch {
            if replacing { items = [] }
            errorMessage = error.localizedDescription
        }
    }

    private func like(_ item: GalleryItem) async {
        do {
            let result = try await GalleryClient.like(id: item.id)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].likeCount = result.likeCount
                items[index].likedByMe = result.likedByMe
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// "내 고양이 올리기" 시트. 저장된 디자인(초안 아님)과 이름 탭의 이름을 올린다.
private struct GalleryUploadSheet: View {
    let onUploaded: () -> Void
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.galleryNickname) private var nickname = ""
    @State private var catName = UserDefaults.standard.string(forKey: SettingsKey.catName) ?? "멈춰묘"
    @State private var isUploading = false
    @State private var errorMessage: String?
    private let design = PixelOverrideStore.load()

    private var canUpload: Bool {
        !design.isEmpty && !trimmed(nickname).isEmpty && !trimmed(catName).isEmpty && !isUploading
    }

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(text: "내 고양이 올리기")

            PixelSpriteView(
                colors: CatFrame.idleStand.displayColors(eyeLook: .center, overrides: design),
                pixelSize: 6
            )
            .padding(10)
            .cardBackground()

            field("고양이 이름", text: $catName)
            field("내 닉네임", text: $nickname)

            Text(design.isEmpty
                 ? "기본 고양이는 올릴 수 없어요. 디자인 탭에서 꾸미고 저장해 주세요."
                 : "디자인 탭에서 저장한 모습이 올라가요.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CuteTheme.textPrimary.opacity(0.6))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CuteTheme.destructive)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Button("취소") { dismiss() }
                    .buttonStyle(PixelSecondaryButtonStyle())
                Button(isUploading ? "올리는 중…" : "올리기") { Task { await upload() } }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(!canUpload)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(CuteTheme.background)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().stroke(CuteTheme.accentDark.opacity(0.35), lineWidth: 1.5))
            .onChange(of: text.wrappedValue) { _, newValue in
                if newValue.count > 20 { text.wrappedValue = String(newValue.prefix(20)) } // 서버 제한과 동일
            }
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func upload() async {
        isUploading = true
        defer { isUploading = false }
        do {
            _ = try await GalleryClient.upload(nickname: trimmed(nickname), catName: trimmed(catName), design: design)
            onUploaded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
