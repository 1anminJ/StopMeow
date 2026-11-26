package com.stopmeow.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/** 실제 PostgreSQL(Testcontainers)에 띄운 서버로 갤러리 API 전체 흐름을 확인한다. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GalleryApiTests {

    @Value("${local.server.port}") int port;
    @Autowired ObjectMapper json;
    @Autowired JdbcClient jdbc;

    private final HttpClient http = HttpClient.newHttpClient();

    record Res(int status, JsonNode body) {}

    private Res send(String method, String path, UUID device, String body) throws Exception {
        var req = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Content-Type", "application/json")
                .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
        if (device != null) req.header("X-Device-Id", device.toString());
        HttpResponse<String> res = http.send(req.build(), HttpResponse.BodyHandlers.ofString());
        return new Res(res.statusCode(), res.body().isEmpty() ? null : json.readTree(res.body()));
    }

    private static String upload(String nickname, String catName, String color) {
        return """
                {"nickname":"%s","catName":"%s","design":{"3_4":"%s","part_O":"#112233"}}
                """.formatted(nickname, catName, color);
    }

    @Test
    void uploadListLikeFlow() throws Exception {
        jdbc.sql("TRUNCATE customs CASCADE").update();
        UUID alice = UUID.randomUUID();
        UUID bob = UUID.randomUUID();

        Res first = send("POST", "/api/customs", alice, upload("앨리스", "치즈", "#FFAA00"));
        assertThat(first.status()).isEqualTo(201);
        long firstId = first.body().get("id").asLong();
        assertThat(first.body().get("design").get("3_4").asString()).isEqualTo("#FFAA00");

        Res second = send("POST", "/api/customs", bob, upload("밥", "까망", "#000000"));
        long secondId = second.body().get("id").asLong();

        // 최신순: 나중에 올린 게 먼저
        Res latest = send("GET", "/api/customs?sort=latest", null, null);
        assertThat(latest.body().get("items").get(0).get("id").asLong()).isEqualTo(secondId);

        // 좋아요 두 번 눌러도 1개만 반영
        assertThat(send("POST", "/api/customs/" + firstId + "/like", bob, null).body().get("likeCount").asInt()).isEqualTo(1);
        assertThat(send("POST", "/api/customs/" + firstId + "/like", bob, null).body().get("likeCount").asInt()).isEqualTo(1);

        // 인기순: 좋아요 받은 게 먼저, 누른 기기 기준 likedByMe
        Res popular = send("GET", "/api/customs?sort=popular", bob, null);
        JsonNode top = popular.body().get("items").get(0);
        assertThat(top.get("id").asLong()).isEqualTo(firstId);
        assertThat(top.get("likedByMe").asBoolean()).isTrue();
        assertThat(send("GET", "/api/customs/" + firstId, alice, null).body().get("likedByMe").asBoolean()).isFalse();

        // 페이지 나눔
        Res page0 = send("GET", "/api/customs?size=1", null, null);
        assertThat(page0.body().get("items").size()).isEqualTo(1);
        assertThat(page0.body().get("hasNext").asBoolean()).isTrue();
    }

    @Test
    void rejectsBadInput() throws Exception {
        UUID device = UUID.randomUUID();
        assertThat(send("POST", "/api/customs", device, upload("닉", "고양이", "red")).status()).isEqualTo(400);
        assertThat(send("POST", "/api/customs", device, upload("시 발", "고양이", "#FFFFFF")).status()).isEqualTo(400);
        assertThat(send("POST", "/api/customs", null, upload("닉", "고양이", "#FFFFFF")).status()).isEqualTo(400);
        assertThat(send("POST", "/api/customs/999999/like", device, null).status()).isEqualTo(404);
        assertThat(send("GET", "/api/customs?sort=random", null, null).status()).isEqualTo(400);
        assertThat(send("GET", "/api/customs?size=999", null, null).status()).isEqualTo(400);
    }

    @Test
    void limitsDailyUploadsPerDevice() throws Exception {
        UUID device = UUID.randomUUID();
        for (int i = 0; i < GalleryController.DAILY_UPLOAD_LIMIT; i++) {
            assertThat(send("POST", "/api/customs", device, upload("닉" + i, "고양이", "#FFFFFF")).status()).isEqualTo(201);
        }
        assertThat(send("POST", "/api/customs", device, upload("닉", "고양이", "#FFFFFF")).status()).isEqualTo(429);
    }
}
