package com.stopmeow.server;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * 갤러리 API (기획서 "서버 API 설계"). 인증 없이 X-Device-Id(앱이 최초 실행 때 만든 UUID)로
 * 좋아요 중복과 업로드 횟수만 제한한다.
 * ponytail: 엔드포인트 4개뿐이라 서비스/리포지토리 계층 없이 컨트롤러에서 SQL을 바로 실행.
 */
@RestController
@RequestMapping("/api/customs")
class GalleryController {

    static final int DAILY_UPLOAD_LIMIT = 10;

    // ponytail: 최소 금칙어 목록. 우회(띄어쓰기·자모 분리 등)는 못 막음 — 신고 기능이나 외부 필터가 필요해지면 교체.
    private static final List<String> BANNED_WORDS = List.of("시발", "씨발", "병신", "좆", "fuck", "shit");

    private static final String SELECT_ITEM = """
            SELECT c.id, c.nickname, c.cat_name, c.design::text AS design, c.like_count, c.created_at,
                   EXISTS (SELECT 1 FROM likes l WHERE l.custom_id = c.id AND l.device_id = CAST(:device AS uuid)) AS liked_by_me
            FROM customs c
            """;

    private final JdbcClient jdbc;
    private final ObjectMapper json;

    GalleryController(JdbcClient jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    record UploadRequest(
            @NotBlank @Size(max = 20) String nickname,
            @NotBlank @Size(max = 20) String catName,
            @NotEmpty @Size(max = 200) Map<
                    @Pattern(regexp = "\\d{1,2}_\\d{1,2}|part_[A-Z]") String,
                    @Pattern(regexp = "#[0-9A-Fa-f]{6}") String> design) {}

    record CustomItem(long id, String nickname, String catName, Map<String, String> design,
                      int likeCount, OffsetDateTime createdAt, boolean likedByMe) {}

    record Page(List<CustomItem> items, boolean hasNext) {}

    record LikeResult(int likeCount, boolean likedByMe) {}

    enum Sort { latest, popular }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    CustomItem upload(@RequestHeader("X-Device-Id") UUID device, @Valid @RequestBody UploadRequest req) {
        if (containsBannedWord(req.nickname()) || containsBannedWord(req.catName())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "사용할 수 없는 단어가 들어 있어요");
        }
        int recent = jdbc.sql("SELECT count(*) FROM customs WHERE device_id = :device AND created_at > now() - interval '1 day'")
                .param("device", device)
                .query(Integer.class).single();
        if (recent >= DAILY_UPLOAD_LIMIT) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "업로드는 하루 " + DAILY_UPLOAD_LIMIT + "개까지 가능해요");
        }
        long id = jdbc.sql("""
                        INSERT INTO customs (nickname, cat_name, design, device_id)
                        VALUES (:nickname, :catName, CAST(:design AS jsonb), :device)
                        RETURNING id
                        """)
                .param("nickname", req.nickname().strip())
                .param("catName", req.catName().strip())
                .param("design", json.writeValueAsString(req.design()))
                .param("device", device)
                .query(Long.class).single();
        return find(id, device);
    }

    @GetMapping
    Page list(@RequestHeader(value = "X-Device-Id", required = false) UUID device,
              @RequestParam(defaultValue = "latest") Sort sort,
              @RequestParam(defaultValue = "0") @Min(0) int page,
              @RequestParam(defaultValue = "30") @Min(1) @Max(50) int size) {
        String order = sort == Sort.popular ? "c.like_count DESC, c.id DESC" : "c.id DESC";
        // 한 개 더 가져와서 다음 페이지 존재 여부를 판단한다.
        List<CustomItem> rows = jdbc.sql(SELECT_ITEM + " ORDER BY " + order + " LIMIT :limit OFFSET :offset")
                .param("device", device == null ? null : device.toString())
                .param("limit", size + 1)
                .param("offset", (long) page * size)
                .query(itemMapper()).list();
        boolean hasNext = rows.size() > size;
        return new Page(hasNext ? rows.subList(0, size) : rows, hasNext);
    }

    @GetMapping("/{id}")
    CustomItem detail(@RequestHeader(value = "X-Device-Id", required = false) UUID device, @PathVariable long id) {
        return find(id, device);
    }

    @PostMapping("/{id}/like")
    @Transactional
    LikeResult like(@RequestHeader("X-Device-Id") UUID device, @PathVariable long id) {
        find(id, device); // 404 확인
        int inserted = jdbc.sql("INSERT INTO likes (custom_id, device_id) VALUES (:id, :device) ON CONFLICT DO NOTHING")
                .param("id", id).param("device", device).update();
        // 이미 누른 기기면 insert가 무시되고 카운트도 그대로 — 중복 좋아요 방지.
        int likeCount = jdbc.sql("UPDATE customs SET like_count = like_count + :inc WHERE id = :id RETURNING like_count")
                .param("inc", inserted).param("id", id)
                .query(Integer.class).single();
        return new LikeResult(likeCount, true);
    }

    private CustomItem find(long id, UUID device) {
        return jdbc.sql(SELECT_ITEM + " WHERE c.id = :id")
                .param("device", device == null ? null : device.toString())
                .param("id", id)
                .query(itemMapper()).optional()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }

    private RowMapper<CustomItem> itemMapper() {
        return (rs, n) -> new CustomItem(
                rs.getLong("id"),
                rs.getString("nickname"),
                rs.getString("cat_name"),
                json.readValue(rs.getString("design"), new TypeReference<Map<String, String>>() {}),
                rs.getInt("like_count"),
                rs.getObject("created_at", OffsetDateTime.class),
                rs.getBoolean("liked_by_me"));
    }

    static boolean containsBannedWord(String text) {
        String normalized = text.toLowerCase(Locale.ROOT).replaceAll("\\s", "");
        return BANNED_WORDS.stream().anyMatch(normalized::contains);
    }
}
