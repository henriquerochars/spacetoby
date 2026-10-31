# AGENTS.md — Autonomous Agent Coordination & Engineering Guide for SpaceToby

This repository is structured and optimized for autonomous AI coding agents operating inside **Google Antigravity**.

---

## 1. Repository Structure & Monorepo Architecture

```text
spacetoby/
├── apps/
│   ├── game/                  # Godot Engine 4.x Game Client (GDScript)
│   │   ├── project.godot      # Viewport 1280x720, Input Map, Autoload Singletons
│   │   ├── scenes/            # MainMenu, Cutscene, Gameplay, AuthScreen, GameOverScreen, LeaderboardsScreen, ProfileScreen
│   │   ├── scripts/
│   │   │   ├── autoload/      # GameState, DifficultyManager, ApiClient, AudioManager
│   │   │   ├── entities/      # PlayerShip, Projectile, EnemyShip, SpaceObstacle, Spawner
│   │   │   └── ui/            # Controllers for all screens & opening cutscene
│   │   ├── assets/            # PixelLab MCP generated pixel art & synthesized WAV audio
│   │   ├── resources/         # Shared Godot resources
│   │   └── tests/             # Headless Godot automated test suite (TestRunner.tscn / test_runner.gd)
│   │
│   └── api/                   # NestJS + TypeScript + Prisma + PostgreSQL Backend API
│       ├── src/
│       │   ├── auth/          # Local email/password accounts & signed app JWTs
│       │   ├── players/       # Player profiles, nickname validation, personal stats
│       │   ├── game-sessions/ # Server-issued session IDs & anti-cheat plausibility checks
│       │   ├── leaderboards/  # Global Kills & Distance leaderboards with pagination & tie-breaking
│       │   ├── common/        # Interceptors, exception filters, data repository, health check
│       │   └── prisma/        # PrismaService & module
│       ├── prisma/            # schema.prisma & version-controlled SQL migrations + RLS policies
│       └── test/              # Supertest E2E integration tests
│
├── packages/
│   └── api-contracts/         # Shared TypeScript DTO contracts & enums (@spacetoby/api-contracts)
│
├── infrastructure/
│   └── docker/                # Dockerfile.api & container configuration
│
├── docs/
│   ├── architecture/          # System & database architecture docs
│   ├── gameplay/              # Gameplay mechanics & difficulty tuning docs
│   ├── api/                   # REST API & anti-cheat specification
│   └── assets/                # PixelLab MCP Asset Manifest
│
├── scripts/                   # Automation scripts (PixelLab MCP client, test-game.sh, export-web.sh)
├── .github/workflows/ci.yml   # GitHub Actions CI pipeline
├── docker-compose.yml         # Local PostgreSQL & API orchestration
├── pnpm-workspace.yaml
└── package.json
```

---

## 2. Scoped Agent Responsibilities

### Game Agent (`apps/game/`)
- Owns Godot 4.x scenes, GDScript entities, input handling (Desktop keyboard/mouse + Mobile multi-touch), `DifficultyManager`, opening heist cutscene (`Cutscene.tscn`), and headless tests (`apps/game/tests/test_runner.gd`).
- **Rule**: Never hardcode backend secrets in GDScript. Always communicate with the backend through `ApiClient` (`res://scripts/autoload/api_client.gd`) and keep gameplay playable offline when the API is unreachable.

### Backend Agent (`apps/api/`, `packages/api-contracts/`)
- Owns NestJS controllers, services, guards, Prisma schema/migrations, local password authentication and app JWT verification, session anti-cheat validation, and global leaderboard ranking queries.
- **Rule**: Never allow the client to write directly to leaderboard records. Every score submission must reference a server-issued `GameSession` in `IN_PROGRESS` state owned by the authenticated player.

### Art Agent (`apps/game/assets/`, `scripts/generate_pixellab_assets.py`, `docs/assets/`)
- Owns PixelLab MCP integration (`https://api.pixellab.ai/mcp`), character portraits, spaceship sprites, enemies, projectiles, backgrounds, UI logos, and `docs/assets/ASSET_MANIFEST.md`.
- **Rule**: Read `PIXELLAB_API_KEY` exclusively from `.env` / environment variables. Maintain cohesive pixel scaling (`texture_filter=0` nearest-neighbor) and cosmic palette (deep navy, dark purple, neon cyan, electric blue, warm orange/yellow).

### QA Agent (`apps/api/test/`, `apps/game/tests/`, `.github/workflows/`)
- Owns unit tests, E2E workflow tests, Godot headless import/scene/gameplay verification, and browser export checks.
- **Rule**: Never claim gameplay or backend features work without running `pnpm test`, `pnpm test:e2e`, and `./scripts/test-game.sh`.

---

## 3. Development & Verification Commands

```bash
# Install all workspace dependencies
pnpm install

# Generate Prisma client
pnpm db:generate

# Build shared contracts and NestJS API
pnpm build

# Run TypeScript typechecking / linting across workspaces
pnpm lint

# Run Backend Unit Tests (JWT, Player Sync, Anti-Cheat, Leaderboard Ranking)
pnpm test

# Run End-to-End Integration Tests (Full 10-step player & leaderboard lifecycle)
pnpm test:e2e

# Run Godot 4 Headless Import & 65-assertion Automated Game Test Suite
pnpm test:game

# Export Playable Browser Build (apps/game/build/web/index.html)
pnpm game:export:web
```

---

## 4. Definition of Done & PR Review Rules

1. All TypeScript packages (`@spacetoby/api-contracts`, `@spacetoby/api`) compile with zero errors (`pnpm build && pnpm lint`).
2. All backend unit tests and 10-step E2E tests pass (`pnpm test && pnpm test:e2e`).
3. Godot 4 headless import and all 64 automated game assertions pass (`./scripts/test-game.sh`).
4. Web export (`apps/game/build/web/index.html` and `index.pck`) builds cleanly (`./scripts/export-web.sh`).
5. No secrets or API keys (`.env`) are committed to version control.
