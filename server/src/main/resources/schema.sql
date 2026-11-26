-- 앱 시작 시마다 실행(spring.sql.init.mode=always). IF NOT EXISTS라 기존 데이터는 그대로 둔다.
-- ponytail: 마이그레이션 도구 없이 단일 스키마 파일. 컬럼 변경이 생기면 Flyway 도입.
CREATE TABLE IF NOT EXISTS customs (
    id          BIGSERIAL PRIMARY KEY,
    nickname    VARCHAR(20)  NOT NULL,
    cat_name    VARCHAR(20)  NOT NULL,
    design      JSONB        NOT NULL, -- 앱의 PixelOverrides 그대로: {"3_4": "#AABBCC", "part_O": "#112233", ...}
    like_count  INT          NOT NULL DEFAULT 0,
    device_id   UUID         NOT NULL, -- 업로드 제한 용도로만 사용, 응답엔 내보내지 않음
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customs_popular_idx ON customs (like_count DESC, id DESC);
CREATE INDEX IF NOT EXISTS customs_device_created_idx ON customs (device_id, created_at);

CREATE TABLE IF NOT EXISTS likes (
    id          BIGSERIAL PRIMARY KEY,
    custom_id   BIGINT       NOT NULL REFERENCES customs (id) ON DELETE CASCADE,
    device_id   UUID         NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (custom_id, device_id)
);
