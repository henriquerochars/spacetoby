# SpaceToby — Context Handoff for T3 Code

> **Date**: 2026-10-30  
> **Status**: Playable MVP implemented & tested; ready for hardening, authentic Supabase integration, native Godot web export, and final release polish.

---

## 1. Project Overview & Tech Stack

**SpaceToby** is a fast-paced 2D side-scrolling space arcade game featuring **Toby**, a charismatic anthropomorphic beagle space mercenary who escapes with the Quantum Crystal after pulling off a heist on crime syndicate boss Baron Vex.

- **Game Client**: Godot Engine 4.7.2 (macOS binary at `/opt/homebrew/bin/godot`), GDScript, 1280x720 canvas_items viewport.
- **Backend API**: NestJS 10, TypeScript, Prisma ORM 6.19, PostgreSQL, Supabase Auth (JWT/JWKS).
- **Contracts**: Shared TypeScript DTOs & enums in `packages/api-contracts` (`@spacetoby/api-contracts`).
- **Art & Audio**: 19 original pixel-art assets generated via PixelLab MCP (`https://api.pixellab.ai/mcp`) + procedural 16-bit PCM WAV audio effects and chiptune synth loops.
- **Monorepo**: Managed via `pnpm` workspace (Node 22 / 26).

---

## 2. Directory & Monorepo Structure

```text
tobyspace/
├── apps/
│   ├── game/                  # Godot 4.x Client
│   │   ├── project.godot      # Viewport, inputs (Space, J, Esc, touch), autoloads
│   │   ├── scenes/            # MainMenu, Cutscene, Gameplay, AuthScreen, GameOverScreen, LeaderboardsScreen, ProfileScreen
│   │   ├── scripts/
│   │   │   ├── autoload/      # GameState, DifficultyManager, ApiClient, AudioManager
│   │   │   ├── entities/      # PlayerShip, Projectile, EnemyShip, SpaceObstacle, Spawner
│   │   │   └── ui/            # Controllers for all UI & cutscenes
│   │   ├── assets/            # PixelLab PNG sprites & WAV sound effects
│   │   │   ├── characters/    # Toby (happy, determined, cursing, surprised, gameover), Baron Vex
│   │   │   ├── spaceships/    # Player ship (idle, thrust)
│   │   │   ├── enemies/       # Scout, Fighter, Heavy, Asteroid, Station Pillar
│   │   │   ├── effects/       # Player laser, enemy laser, explosion burst
│   │   │   ├── backgrounds/   # Deep starfield, nebula layer, ringed planet
│   │   │   ├── ui/            # SpaceToby logo, heist cutscene illustration
│   │   │   └── audio/         # 10 WAV sound & music files
│   │   ├── export_presets.cfg # Web export preset configuration
│   │   ├── build/web/         # HTML5 web export + index.pck bundle
│   │   └── tests/             # Headless Godot test runner (TestRunner.tscn / test_runner.gd)
│   │
│   └── api/                   # NestJS REST API
│       ├── src/
│       │   ├── auth/          # JWT/JWKS guards, token verification, auth controller
│       │   ├── players/       # Player profile, nickname update, statistics
│       │   ├── game-sessions/ # Server-issued session IDs & anti-cheat checks
│       │   ├── leaderboards/  # Global Kills & Distance rankings with deterministic tie-breaking
│       │   ├── common/        # DataRepository (PostgreSQL + snapshot fallback), filters, interceptors
│       │   └── prisma/        # PrismaService
│       ├── prisma/            # schema.prisma, migrations (20261029000000_init) + RLS policies
│       └── test/              # Jest unit & E2E integration tests (app.e2e-spec.ts)
│
├── packages/
│   └── api-contracts/         # Shared TypeScript interfaces & DTOs
├── infrastructure/
│   └── docker/                # Dockerfile.api
├── docs/
│   ├── architecture/          # Architecture overview
│   └── assets/                # Asset Manifest detailing PixelLab job IDs
├── scripts/
│   ├── generate_pixellab_assets.py  # PixelLab MCP client & asset pipeline
│   ├── generate_audio_and_bgs.py    # Procedural audio & parallax generator
│   ├── test-game.sh                 # Godot headless asset import & 64-test suite
│   ├── export-web.sh                # Web export builder
│   └── build_web_bundle.py          # Web bundle generator
├── .github/workflows/ci.yml   # GitHub Actions CI workflow
├── docker-compose.yml         # Local Postgres & API service
├── pnpm-workspace.yaml
├── package.json
├── .env.example
├── .env                       # Local environment configuration
└── AGENTS.md                  # Autonomous agent guidelines
```

---

## 3. What Was Completed & Verified

1. **PixelLab MCP Asset Generation**:
   - Discovered 118 tools on `https://api.pixellab.ai/mcp`.
   - Generated and saved all 19 pixel-art assets using `create_image_pixflux` (`ASSET_MANIFEST.md` records all job IDs).
   - Generated 10 retro arcade WAV audio assets (laser, explosion, hit, thrust, gameover, button, voice_blip, menu_bgm, gameplay_bgm, cutscene_bgm) and 2 tileable parallax space backgrounds.

2. **Godot 4 Game Client (`apps/game`)**:
   - **Physics & Gameplay**: Flappy Bird gravity (`1180 px/s²`), upward thrust impulse (`-410 px/s`), hold acceleration (`-720 px/s²`), pitch rotation, forward laser weapon with cooldown (`0.20s`).
   - **Three Enemy Types**:
     - `Scout` (2 HP, fast, sine movement)
     - `Fighter` (4 HP, plasma shooter)
     - `Heavy Ship` (8 HP, armored dreadnought)
   - **Procedural Spawner & Difficulty**: Guarantees reachable safe gap corridors (`<= 185 px` vertical delta) with station pillars and crystal asteroids. DifficultyManager ramps speed (`280` to `680 px/s`), spawn frequencies, and enemy projectile rates.
   - **Opening Heist Cutscene (`Cutscene.tscn`)**: Toby fleeing Baron Vex's syndicate vault with typewriter dialogue, voice blips, animated cockpit expressions, and cursing out Baron Vex over the comms.
   - **Complete UI Screens**: `MainMenu.tscn`, `Cutscene.tscn`, `Gameplay.tscn`, `AuthScreen.tscn`, `GameOverScreen.tscn`, `LeaderboardsScreen.tscn`, `ProfileScreen.tscn`.
   - **Input Support**: Keyboard/Mouse (`Space`, `W`, `J`, `Z`, `Esc`, mouse click) and Mobile multi-touch (left half = thrust, right half = shoot).

3. **Backend API (`apps/api`) & Shared Contracts**:
   - `packages/api-contracts`: DTOs for Auth, Profile, GameSession, and Leaderboards.
   - Supabase JWT/JWKS token verification guard + dev auth bridge.
   - Anti-cheat plausibility validator: Prevents duplicate submissions, enforces session ownership, validates speed ratio (`<= 850 units/s`), kill rate (`<= 6 kills/s`), and score bounds.
   - Dual Leaderboards: Ranking A (Most Kills) and Ranking B (Longest Distance), deduplicating runs per player with deterministic tie-breaking (Score DESC -> AchievedAt ASC -> PlayerId ASC).
   - Dual-mode data persistence: Direct PostgreSQL via Prisma ORM + local JSON snapshot repository fallback when running offline.

4. **Testing & Verification**:
   - **TypeScript & Lint**: `pnpm lint` and `pnpm build` compile with zero errors across all workspaces.
   - **Backend Unit Tests**: 8/8 tests pass (`pnpm test`).
   - **Backend E2E Workflow**: 10-step full player lifecycle test passes (`pnpm test:e2e`).
   - **Godot 4 Headless Test Suite**: All 64 assertions pass in headless mode (`./scripts/test-game.sh`).

---

## 4. Pending Work & Technical Debt for T3 Code

Here are the specific items to address to finalize the production MVP:

### Priority 1: Supabase Authentication Real Verification
- **Current State**: `AuthController` uses a deterministic HMAC/hash generator as a local development bridge.
- **Task**: Connect to an authentic Supabase project instance (local Supabase CLI or cloud Supabase) so user passwords and signup/login go through Supabase Auth (`supabase.auth.signUp` / `supabase.auth.signInWithPassword`), validating access tokens via JWKS keys.

### Priority 2: Real PostgreSQL via Docker
- **Current State**: Docker daemon is now running (Docker version `28.5.1`, Supabase CLI `2.122.0`). Previous tests ran against the embedded in-memory/snapshot repository.
- **Task**:
  - Run `docker compose up -d postgres`.
  - Execute `pnpm db:push` or `pnpm db:migrate`.
  - Validate that Prisma writes directly to PostgreSQL database tables and reads from views `leaderboard_kills_view` and `leaderboard_distance_view`.

### Priority 3: Native Godot Web Export (Wasm / HTML5)
- **Current State**: `apps/game/build/web/index.pck` is exported from Godot 4.7.2, but `index.html` was generated via an HTML5 Canvas fallback bundle because Godot 4.7.2 export templates were missing or had template mismatch.
- **Task**: Install/configure matching Godot 4.7.2 Web export templates in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (or run export using standard Godot 4.3 templates if downgraded) to produce native Godot Wasm `index.html`.

### Priority 4: Multi-frame Animations & Visual Polish
- **Current State**: Single-frame/dual-frame sprites exist for player ship and enemies.
- **Task**: Use PixelLab MCP (`animate_object` / `create_character_state`) to generate multi-frame sprite sheets for enemy engine trails, thruster flame cycles, and destruction explosion stages.

### Priority 5: Git & Documentation
- **Current State**: `docs/architecture` and `docs/assets` are documented; `docs/gameplay/` and `docs/api/` can be filled in with detailed tuning tables and OpenAPI specs.
- **Task**: Run `git init`, create initial commit, and ensure GitHub Actions workflow `.github/workflows/ci.yml` matches Godot 4.7.2 runner.

---

## 5. Development & Verification Commands

```bash
# 1. Install & Build
pnpm install
pnpm db:generate
pnpm build
pnpm lint

# 2. Run Tests
pnpm test          # Backend unit tests
pnpm test:e2e      # Full 10-step E2E integration test
./scripts/test-game.sh  # Godot 4 headless project import & 64-assertion test suite

# 3. Start Backend API
pnpm dev           # Listens on http://localhost:3000 (Swagger: http://localhost:3000/api/docs)

# 4. Run Game Client
godot --path apps/game   # Run client directly in Godot Engine
```

---

## 6. Credentials & Configuration Reference

- **PixelLab MCP URL**: `https://api.pixellab.ai/mcp`
- **PixelLab API Key**: stored only in the local `.env` file as `PIXELLAB_API_KEY`; never commit this file.
- **Godot Binary**: `/opt/homebrew/bin/godot` (Godot Engine v4.7.2.stable.official)
- **Node.js**: `/Users/henriquerochserrano/.nvm/versions/node/v26.5.0/bin/node`
- **pnpm**: `/Users/henriquerochserrano/.nvm/versions/node/v26.5.0/bin/pnpm`
- **Docker**: `/usr/local/bin/docker` (Running, Docker 28.5.1)
