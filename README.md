# SpaceToby 🐶🚀

**SpaceToby** is a fast-paced 2D side-scrolling space arcade game built with **Godot Engine 4.x** and a **NestJS + TypeScript + Prisma + PostgreSQL + Supabase Auth** backend.

Pilot a futuristic mercenary starfighter as **Toby**, a charismatic anthropomorphic beagle escaping across a dangerous asteroid sector after stealing the Quantum Crystal from the crime boss Baron Vex!

---

## ✨ Features Implemented

- **Opening Heist Cutscene (`scenes/Cutscene.tscn`)**: Cinematic pixel-art prologue where Toby flees Baron Vex's syndicate vault, curses out Vex over the holographic comms, and blasts into the asteroid belt.
- **Flappy Bird-Inspired Space Combat (`scenes/Gameplay.tscn`)**:
  - Smooth gravity, upward thrust impulse, hold-boost, and pitch rotation.
  - Forward-firing neon-cyan laser weapon with cooldown, impact SFX, and off-screen cleanup.
  - **Three Enemy Archetypes**: **Scout** (2 HP, fast interceptor), **Fighter** (4 HP, plasma shooter), and **Heavy Ship** (8 HP, armored dreadnought).
  - **Procedural Obstacles & Safe Corridors**: Space station pillar gates and rotating crystal asteroids with guaranteed passable gaps.
  - **Dynamic `DifficultyManager`**: Scales scroll speed, spawn rates, enemy weights, and fire rates smoothly over distance.
  - **Desktop & Mobile Multitouch Controls**: Simultaneous movement (left screen / Spacebar) and laser shooting (right screen / J).
- **PixelLab MCP Original Art (`apps/game/assets/`)**:
  - All character portraits (Toby happy, determined, cursing, surprised, game-over, plus Baron Vex), player spaceship frames with visible cockpit, enemies, projectiles, explosions, planet, cutscene art, and logo generated via the **PixelLab MCP** (`https://api.pixellab.ai/mcp`).
- **Online Authentication, Anti-Cheat Sessions & Dual Global Leaderboards (`apps/api/`)**:
  - **Ranking A (`GET /api/v1/leaderboards/kills`)**: Most Enemies Destroyed in a single run.
  - **Ranking B (`GET /api/v1/leaderboards/distance`)**: Longest Distance traveled in a single run.
  - Server-issued `GameSession` tracking with anti-cheat plausibility checks (duplicate submission lock, ownership verification, speed & kill-rate bounds).
  - Full offline fallback so the game is 100% playable even without a running backend.

---

## 📁 Monorepo Structure

```text
spacetoby/
├── apps/
│   ├── game/                  # Godot 4.x Game Client (GDScript + PixelLab Assets + Web Build)
│   └── api/                   # NestJS + Prisma + PostgreSQL + Supabase Auth REST API
├── packages/
│   └── api-contracts/         # Shared TypeScript DTOs & Enums (@spacetoby/api-contracts)
├── infrastructure/
│   └── docker/                # Dockerfile for API service
├── docs/                      # Architecture, Gameplay, API, and PixelLab Asset Manifest
├── scripts/                   # PixelLab MCP generator, Audio generator, Headless tests, Web export
├── .github/workflows/ci.yml   # GitHub Actions CI workflow
├── docker-compose.yml         # Local PostgreSQL & API orchestration
├── pnpm-workspace.yaml
├── package.json
├── .env.example
└── AGENTS.md
```

---

## 🚀 Quick Start & Commands

### 1. Environment Configuration

```bash
cp .env.example .env
```

All required variables (`DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_JWT_SECRET`, `PIXELLAB_API_KEY`, anti-cheat bounds) are documented in [`.env.example`](file:///Users/henriquerochserrano/tobyspace/.env.example).

### 2. Install Dependencies & Build Backend

```bash
pnpm install
pnpm db:generate
pnpm build
```

### 3. Start Local Infrastructure & Backend API

**With Docker Compose (PostgreSQL + API):**
```bash
pnpm infra:up
pnpm db:migrate
```

**Or run the NestJS API directly in development mode (automatically uses PostgreSQL when available or the embedded store fallback):**
```bash
pnpm dev
```
- **API Base URL**: `http://localhost:3000`
- **Health Check**: `http://localhost:3000/health`
- **Swagger OpenAPI Docs**: `http://localhost:3000/api/docs`

### 4. Open & Play the Game

**In Godot Engine 4.x:**
```bash
# Run the game directly
pnpm game:run

# Or open inside the Godot 4 Editor
pnpm game:open
```

**In Any Web Browser (Exported Web Build):**
```bash
pnpm game:export:web
npx serve apps/game/build/web
```

---

## 🧪 Running Automated Tests

```bash
# 1. Run Backend Unit Tests (JWT Auth, Player Sync, Session Anti-Cheat, Leaderboard Ranking)
pnpm test

# 2. Run Backend End-to-End Integration Tests (Full 10-step player & leaderboard workflow)
pnpm test:e2e

# 3. Run Godot 4 Headless Project Import & 64-Assertion Automated Game Test Suite
pnpm test:game

# 4. Run Lint / Typecheck across all packages
pnpm lint
```

---

## 🎮 Controls

| Action | Desktop (Keyboard / Mouse) | Mobile / Touchscreen |
|---|---|---|
| **Upward Thrust** | `SPACE` / `W` / `UP` / Left Click (left half) | Tap / Hold **Left Side** of screen |
| **Shoot Lasers** | `J` / `Z` / `K` / Right Click (or Left Click right half) | Tap / Hold **Right Side** of screen |
| **Pause Game** | `ESC` / `P` | Tap **II PAUSE** button (top-right) |
| **Advance Cutscene** | `SPACE` / Left Click | Tap screen |
