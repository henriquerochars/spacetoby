# SpaceToby — System, Gameplay & API Architecture

## 1. Architecture Overview

SpaceToby separates concerns cleanly across three layers in a `pnpm` + Godot 4 monorepo:

1. **Game Client (`apps/game`)**: Godot 4.x 2D side-scrolling arcade game with four global Autoload singletons (`GameState`, `DifficultyManager`, `ApiClient`, `AudioManager`), modular entity classes (`PlayerShip`, `Projectile`, `EnemyShip`, `SpaceObstacle`, `Spawner`), and 7 full UI/Gameplay scenes (`MainMenu`, `Cutscene`, `Gameplay`, `AuthScreen`, `GameOverScreen`, `LeaderboardsScreen`, `ProfileScreen`).
2. **REST API (`apps/api`)**: NestJS + TypeScript service exposing versioned endpoints (`/api/v1/*`) with Swagger docs (`/api/docs`), rate limiting (`@nestjs/throttler`), DTO validation (`class-validator`), local email/password authentication with signed application JWTs, server-issued session tracking, anti-cheat plausibility checks, and global leaderboard calculation.
3. **Database (`apps/api/prisma`)**: PostgreSQL schema managed by Prisma ORM (`Player`, `GameSession`, `GameEvent`, and local account credentials) with composite leaderboard indexes and SQL views (`leaderboard_kills_view`, `leaderboard_distance_view`).

Accounts are stored in the application's PostgreSQL database. The API hashes passwords and issues its own signed JWTs, and the game authenticates directly against this service. Password recovery is currently unavailable: the recovery endpoint returns HTTP 501 until a delivery and reset mechanism is configured, sends no email, and directs players to contact the service operator for an account reset.

---

## 2. Gameplay & Difficulty Scaling (`DifficultyManager`)

- **Movement**: Gravity (`1180 px/s²`) continuously pulls Toby's ship downward. Pressing `SPACE` / `W` / Left Click / Left Touch applies an immediate upward impulse (`-410 px/s`) plus sustained hold thrust (`-720 px/s²`).
- **Combat**: Pressing `J` / `Z` / Right Click / Right Touch fires forward cyan lasers (`920 px/s`, `0.20s` cooldown).
- **Enemies**:
  - `Scout`: 2 HP, fast (`1.32x` scroll speed), sine-wave trajectory.
  - `Fighter`: 4 HP, medium weave (`1.05x` scroll speed), fires orange plasma orbs toward the player.
  - `Heavy Ship`: 8 HP, armored warship (`0.72x` scroll speed), heavy plasma fire.
- **Procedural Obstacles**: `Spawner` alternates between Flappy Bird-style top/bottom space-station pillar gates and cosmic asteroids while constraining the vertical delta (`<= 185 px`) between consecutive safe corridors so impossible layouts never spawn.

---

## 3. Anti-Cheat & Leaderboard Rules

- **Ranking A (`/api/v1/leaderboards/kills`)**: Highest `enemiesKilled` in a single valid run.
- **Ranking B (`/api/v1/leaderboards/distance`)**: Highest `distance` traveled in a single valid run.
- **Deduplication & Ties**: Each player appears at most once per leaderboard (their best valid run for that metric). Ties are broken deterministically by:
  1. Score (`DESC`)
  2. Achievement timestamp (`ASC` — first pilot to reach the score ranks higher)
  3. Player UUID (`ASC`)
- **Plausibility Checks (`GameSessionsService.validatePlausibility`)**:
  - Prevents duplicate submissions (`ConflictException` if session is not `IN_PROGRESS`).
  - Enforces session ownership (`ForbiddenException` if `session.playerId !== player.id`).
  - Validates score bounds, maximum speed ratio (`distance / durationSec <= 850`), maximum kill rate (`enemiesKilled / durationSec <= 6`), and kills-to-distance ratio.
