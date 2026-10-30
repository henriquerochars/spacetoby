-- =============================================================================
-- SpaceToby — Initial PostgreSQL & Supabase Migration
-- Includes tables, indexes, leaderboard views, and Row Level Security (RLS).
-- =============================================================================

-- Create Enums
CREATE TYPE "RunStatus" AS ENUM ('IN_PROGRESS', 'COMPLETED', 'ABANDONED');
CREATE TYPE "ValidationStatus" AS ENUM ('PENDING', 'VALID', 'REJECTED');

-- Create Players Table
CREATE TABLE "players" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "auth_user_id" TEXT NOT NULL,
    "nickname" VARCHAR(32) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "players_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "players_auth_user_id_key" ON "players"("auth_user_id");
CREATE UNIQUE INDEX "players_nickname_key" ON "players"("nickname");
CREATE INDEX "players_nickname_idx" ON "players"("nickname");

-- Create Game Sessions Table
CREATE TABLE "game_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "player_id" UUID NOT NULL,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finished_at" TIMESTAMP(3),
    "duration_ms" INTEGER NOT NULL DEFAULT 0,
    "distance" INTEGER NOT NULL DEFAULT 0,
    "enemies_killed" INTEGER NOT NULL DEFAULT 0,
    "status" "RunStatus" NOT NULL DEFAULT 'IN_PROGRESS',
    "validation_status" "ValidationStatus" NOT NULL DEFAULT 'PENDING',
    "validation_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "game_sessions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "game_sessions_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "game_sessions_player_id_status_validation_status_idx" ON "game_sessions"("player_id", "status", "validation_status");
CREATE INDEX "game_sessions_kills_leaderboard_idx" ON "game_sessions"("status", "validation_status", "enemies_killed" DESC, "finished_at" ASC);
CREATE INDEX "game_sessions_distance_leaderboard_idx" ON "game_sessions"("status", "validation_status", "distance" DESC, "finished_at" ASC);

-- Create Game Events Table
CREATE TABLE "game_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_id" UUID NOT NULL,
    "type" VARCHAR(48) NOT NULL,
    "timestamp_offset_ms" INTEGER NOT NULL,
    "value" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "game_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "game_events_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "game_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "game_events_session_id_idx" ON "game_events"("session_id");

-- =============================================================================
-- Global Leaderboard Views (Best Valid Run per Player with Deterministic Ties)
-- =============================================================================

CREATE OR REPLACE VIEW "leaderboard_kills_view" AS
WITH best_runs AS (
    SELECT DISTINCT ON (gs.player_id)
        gs.id AS session_id,
        gs.player_id,
        p.nickname,
        gs.enemies_killed AS score,
        COALESCE(gs.finished_at, gs.created_at) AS achieved_at
    FROM "game_sessions" gs
    INNER JOIN "players" p ON p.id = gs.player_id
    WHERE gs.status = 'COMPLETED' AND gs.validation_status = 'VALID'
    ORDER BY gs.player_id, gs.enemies_killed DESC, gs.finished_at ASC, gs.id ASC
)
SELECT
    ROW_NUMBER() OVER (ORDER BY score DESC, achieved_at ASC, player_id ASC)::INT AS rank,
    player_id,
    nickname,
    score,
    session_id,
    achieved_at
FROM best_runs
ORDER BY rank ASC;

CREATE OR REPLACE VIEW "leaderboard_distance_view" AS
WITH best_runs AS (
    SELECT DISTINCT ON (gs.player_id)
        gs.id AS session_id,
        gs.player_id,
        p.nickname,
        gs.distance AS score,
        COALESCE(gs.finished_at, gs.created_at) AS achieved_at
    FROM "game_sessions" gs
    INNER JOIN "players" p ON p.id = gs.player_id
    WHERE gs.status = 'COMPLETED' AND gs.validation_status = 'VALID'
    ORDER BY gs.player_id, gs.distance DESC, gs.finished_at ASC, gs.id ASC
)
SELECT
    ROW_NUMBER() OVER (ORDER BY score DESC, achieved_at ASC, player_id ASC)::INT AS rank,
    player_id,
    nickname,
    score,
    session_id,
    achieved_at
FROM best_runs
ORDER BY rank ASC;

-- =============================================================================
-- Row Level Security (RLS) for Supabase Data API Protection
-- All game score writes MUST go through the NestJS API service role.
-- =============================================================================

ALTER TABLE "players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "game_sessions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "game_events" ENABLE ROW LEVEL SECURITY;

-- Public read access for leaderboards / player nicknames; no direct client writes
CREATE POLICY "Allow public read of player nicknames"
    ON "players" FOR SELECT
    USING (true);

CREATE POLICY "Allow public read of valid completed sessions"
    ON "game_sessions" FOR SELECT
    USING ("status" = 'COMPLETED' AND "validation_status" = 'VALID');
