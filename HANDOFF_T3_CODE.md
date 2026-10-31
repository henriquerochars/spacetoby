# SpaceToby — Context Handoff for T3 Code

> **Date**: 2026-10-30  
> **Status**: Playable MVP with local PostgreSQL email/password authentication, native Godot WebAssembly export, and animated effects. Backend and game validation pass; password recovery still needs a delivery mechanism.

---

## 1. Project Overview & Tech Stack

**SpaceToby** is a fast-paced 2D side-scrolling space arcade game featuring **Toby**, a charismatic anthropomorphic beagle space mercenary who escapes with the Quantum Crystal after pulling off a heist on crime syndicate boss Baron Vex.

- **Game Client**: Godot Engine 4.7.2, GDScript, 1280x720 canvas_items viewport.
- **Backend API**: NestJS 10, TypeScript, Prisma ORM 6.19, PostgreSQL, local email/password authentication and signed app JWTs.
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
│       │   ├── auth/          # Local password auth, JWT guards, and auth controller
│       │   ├── players/       # Player profile, nickname update, statistics
│       │   ├── game-sessions/ # Server-issued session IDs & anti-cheat checks
│       │   ├── leaderboards/  # Global Kills & Distance rankings with deterministic tie-breaking
│       │   ├── common/        # DataRepository (PostgreSQL + snapshot fallback), filters, interceptors
│       │   └── prisma/        # PrismaService
│       ├── prisma/            # schema.prisma and versioned PostgreSQL migrations
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
│   ├── test-game.sh                 # Godot headless asset import & 65-test suite
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
   - Local account authentication using scrypt password hashes and configured app JWT signing.
   - Anti-cheat plausibility validator: Prevents duplicate submissions, enforces session ownership, validates speed ratio (`<= 850 units/s`), kill rate (`<= 6 kills/s`), and score bounds.
   - Dual Leaderboards: Ranking A (Most Kills) and Ranking B (Longest Distance), deduplicating runs per player with deterministic tie-breaking (Score DESC -> AchievedAt ASC -> PlayerId ASC).
   - Dual-mode data persistence: Direct PostgreSQL via Prisma ORM + local JSON snapshot repository fallback when running offline.

4. **Testing & Verification**:
   - **TypeScript & Lint**: `pnpm lint` and `pnpm build` compile with zero errors across all workspaces.
   - **Backend Unit Tests**: 8/8 tests pass (`pnpm test`).
   - **Backend E2E Workflow**: 10-step full player lifecycle test passes (`pnpm test:e2e`).
   - **Godot 4 Headless Test Suite**: All 65 assertions pass in headless mode (`./scripts/test-game.sh`).

---

## 4. Release Status

- **Authentication**: Local email/password accounts are stored in PostgreSQL with scrypt password hashes and signed application JWTs; no external identity provider is used. Password recovery returns HTTP 501 until an email delivery or operator reset mechanism is configured.
- **PostgreSQL**: Docker Compose provides a local PostgreSQL service. Versioned migrations have been applied and a signup/login smoke test confirmed account persistence.
- **Web export**: Godot 4.7.2 templates produce native `index.html`, `index.js`, `index.wasm`, and `index.pck`; the export script rejects fallback builds.
- **Animations**: The player thruster has four animated silhouettes and ship destruction has an eight-frame locally drawn pixel effect.
- **Git and CI**: The repository has an initial commit and public GitHub remote. CI installs Godot 4.7.2 and validates headless gameplay plus native WebAssembly export.
- **Open item**: Configure a real password-recovery delivery/reset mechanism before exposing recovery as available.

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
./scripts/test-game.sh  # Godot 4 headless project import & 65-assertion test suite

# 3. Start Backend API
pnpm dev           # Listens on http://localhost:3000 (Swagger: http://localhost:3000/api/docs)

# 4. Run Game Client
godot --path apps/game   # Run client directly in Godot Engine
```

---

## 6. Toolchain & Configuration Reference

- **PixelLab MCP URL**: `https://api.pixellab.ai/mcp`
- **PixelLab API Key**: stored only in the local `.env` file as `PIXELLAB_API_KEY`; never commit this file.
- **Godot**: version 4.7.2 with matching Web export templates.
- **Node.js**: version 22 or later; CI uses version 22.
- **pnpm**: version 10 or later; CI uses version 10.6.2.
- **Docker**: Docker Engine with Docker Compose v2.
- **API secret**: set a unique `JWT_SECRET` with at least 32 characters in the local `.env` file.
