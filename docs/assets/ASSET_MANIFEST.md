# SpaceToby — Asset Manifest (`docs/assets/ASSET_MANIFEST.md`)

All visual assets in `apps/game/assets/` were generated via the **PixelLab MCP** (`https://api.pixellab.ai/mcp`) using `scripts/generate_pixellab_assets.py` (with `PIXELLAB_API_KEY` loaded from `.env`), paired with procedural parallax layers and 16-bit PCM WAV audio tracks generated via `scripts/generate_audio_and_bgs.py`.

Godot 4 default texture filter is configured to **Nearest-Neighbor (`default_texture_filter=0`)** in `apps/game/project.godot` to preserve crisp pixel art edges.

---

## 1. Characters & Cutscene Portraits (`res://assets/characters/`)

| Filename | Resolution | Generation Source | Purpose |
|---|---|---|---|
| `toby_portrait_happy.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `ae429c6d-2d8e-41c4-a6ff-4bbfcc350a87`) | Toby confident smirk portrait (Main Menu, HUD, Profile, Game Icon) |
| `toby_portrait_determined.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `8bb88010-7e45-459d-800b-37252c4088b7`) | Toby determined combat expression (Cutscene, HUD thrust/shoot reaction, Auth screen) |
| `toby_portrait_cursing.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `524ba609-560e-4e39-a09a-1a2f9263fd94`) | Toby laughing & cursing out Baron Vex with stolen Quantum Crystal in opening cutscene |
| `toby_portrait_surprised.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `48d47bc9-daaa-48d2-a3bd-98f6640d25bb`) | Toby shocked expression with flying beagle ears |
| `toby_portrait_gameover.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `4c1f6276-cb68-4752-ae7b-9f8a931cdc49`) | Toby singed/dizzy expression on Game Over screen |
| `baron_vex_portrait.png` | `128x128` | PixelLab MCP (`create_image_pixflux`, job `06d09ce4-ced2-4c80-81af-95f7eb4dcf22`) | Crime syndicate boss Baron Vex screaming over hologram in opening heist cutscene |

---

## 2. Player Spaceship (`res://assets/spaceships/`)

| Filename | Resolution | Generation Source | Purpose |
|---|---|---|---|
| `player_ship_idle.png` | `96x64` | PixelLab MCP (`create_image_pixflux`, job `67cd9478-567f-4dbe-988e-59a4055160b6`) | Toby's electric-blue & neon-cyan mercenary starfighter with visible beagle cockpit (glide/idle state) |
| `player_ship_thrust.png` | `96x64` | PixelLab MCP (`create_image_pixflux`, job `301fc320-a005-437d-82c5-b38d165471e5`) | Toby's starfighter with roaring orange/yellow plasma thrusters (upward thrust state) |

---

## 3. Enemy Spaceships & Obstacles (`res://assets/enemies/`)

| Filename | Resolution | Generation Source | Purpose |
|---|---|---|---|
| `enemy_scout.png` | `64x48` | PixelLab MCP (`create_image_pixflux`, job `7aae5eb1-c85f-45f3-812e-e3dcf6a323bb`) | Fast crimson/purple Scout interceptor (2 HP) |
| `enemy_fighter.png` | `80x64` | PixelLab MCP (`create_image_pixflux`, job `cc636e71-1ed5-4c1b-bf09-910bb77b20b2`) | Medium assault Fighter with forward plasma cannons (4 HP) |
| `enemy_heavy.png` | `128x96` | PixelLab MCP (`create_image_pixflux`, job `0f14ee3f-cc36-43a9-ab29-1591a95b3371`) | Heavy armored dreadnought warship (8 HP) |
| `obstacle_asteroid_large.png` | `96x96` | PixelLab MCP (`create_image_pixflux`, job `6f1fe368-2386-41b4-8b21-131db393fade`) | Rotating cosmic asteroid with glowing crystal veins |
| `obstacle_station_pillar.png` | `64x192` | PixelLab MCP (`create_image_pixflux`, job `a034528a-2792-486d-ad33-3beb2f4b1ce0`) | Space station vertical barrier girder for Flappy Bird-style gates |

---

## 4. Projectiles, VFX, Environment & UI (`res://assets/effects/`, `backgrounds/`, `ui/`)

| Filename | Resolution | Generation Source | Purpose |
|---|---|---|---|
| `effects/laser_player.png` | `64x32` | PixelLab MCP (`create_image_pixflux`, job `5e3e13b1-8692-43fd-979f-0c2b1884829c`) | Player forward neon-cyan laser bolt |
| `effects/laser_enemy.png` | `32x32` | PixelLab MCP (`create_image_pixflux`, job `5df29ed2-800f-44b1-9c93-c759719224c8`) | Enemy orange/red plasma projectile |
| `effects/explosion_burst.png` | `96x96` | PixelLab MCP (`create_image_pixflux`, job `f0c9400b-8596-412b-9663-acf91c03ddd3`) | Enemy & ship destruction fireball burst |
| `backgrounds/bg_planet.png` | `160x160` | PixelLab MCP (`create_image_pixflux`, job `e7237217-4661-49b5-81aa-bc1e41316bec`) | Ringed purple/cyan gas giant planet |
| `backgrounds/starfield_deep.png` | `640x360` | Procedural Pixel Generator (`generate_audio_and_bgs.py`) | Seamless deep-navy & cosmic-purple starfield parallax base |
| `backgrounds/nebula_layer.png` | `640x360` | Procedural Pixel Generator (`generate_audio_and_bgs.py`) | Translucent neon-cyan & purple cosmic nebula parallax layer |
| `ui/spacetoby_logo.png` | `320x96` | PixelLab MCP (`create_image_pixflux`, job `eb46ff43-d6fe-43d8-99c4-6ad57bdc885e`) | SpaceToby arcade title logo |
| `ui/cutscene_heist_escape.png` | `320x180` | PixelLab MCP (`create_image_pixflux`, job `9adaab40-98a7-4d52-b16e-5fb51fb74460`) | Opening heist cutscene keyframe illustration |

---

## 5. Audio Assets (`res://assets/audio/`)

| Filename | Format | Purpose |
|---|---|---|
| `menu_bgm.wav` | 22.05kHz 16-bit Mono PCM WAV | Space synth arpeggio loop for Main Menu & Leaderboards |
| `cutscene_bgm.wav` | 22.05kHz 16-bit Mono PCM WAV | Tense heist alarm groove for Opening Cutscene |
| `gameplay_bgm.wav` | 22.05kHz 16-bit Mono PCM WAV | Fast-paced arcade chase loop for active runs |
| `laser.wav` | 22.05kHz 16-bit Mono PCM WAV | Player laser firing SFX |
| `thrust.wav` | 22.05kHz 16-bit Mono PCM WAV | Upward booster thrust SFX |
| `explosion.wav` | 22.05kHz 16-bit Mono PCM WAV | Enemy & ship destruction SFX |
| `hit.wav` | 22.05kHz 16-bit Mono PCM WAV | Laser impact on multi-HP enemy armor |
| `gameover.wav` | 22.05kHz 16-bit Mono PCM WAV | Descending arcade Game Over jingle |
| `button.wav` | 22.05kHz 16-bit Mono PCM WAV | UI button click & menu navigation SFX |
| `voice_blip.wav` | 22.05kHz 16-bit Mono PCM WAV | Typewriter dialogue voice blip in Cutscene |
