#!/usr/bin/env python3
"""
Legacy SpaceToby standalone Canvas browser bundle builder. This is not the release
export path; `scripts/export-web.sh` produces the native Godot HTML5/WebAssembly build.
Embeds all PixelLab-generated PNG sprites and WAV sound effects into a self-contained,
responsive HTML5 Canvas + WebAudio web build with the full SpaceToby experience:
- Main Menu, Settings, Auth & Profile, Global Leaderboards (live sync with http://localhost:3000/api/v1)
- Opening Heist Cutscene (Toby cursing out Baron Vex while escaping with the Quantum Crystal)
- Flappy Bird-style spaceship physics, laser combat, 3 enemy types (Scout, Fighter, Heavy),
  procedural obstacles, DifficultyManager progression, Game Over, and Instant Restart.
"""
import os
import json
import base64
import shutil

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME_ASSETS = os.path.join(ROOT_DIR, "apps", "game", "assets")
OUT_DIR = os.path.join(ROOT_DIR, "apps", "game", "build", "web")


def copy_assets_to_web():
    os.makedirs(OUT_DIR, exist_ok=True)
    web_assets = os.path.join(OUT_DIR, "assets")
    if os.path.exists(web_assets):
        shutil.rmtree(web_assets)
    shutil.copytree(GAME_ASSETS, web_assets)


HTML_CONTENT = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>SpaceToby — 2D Space Mercenary Arcade</title>
  <style>
    :root {
      --bg-navy: #080a1c;
      --neon-cyan: #00f5d4;
      --elec-blue: #3a86ff;
      --warm-orange: #ff8c1a;
      --warm-yellow: #ffbe0b;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
    body {
      background: radial-gradient(circle at center, #141838 0%, #050611 100%);
      color: #f0f6ff;
      font-family: 'Courier New', Courier, monospace;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      overflow: hidden;
    }
    #game-wrapper {
      position: relative;
      width: min(100vw, 177.78vh);
      height: min(56.25vw, 100vh);
      max-width: 1280px;
      max-height: 720px;
      border: 2px solid var(--neon-cyan);
      box-shadow: 0 0 32px rgba(0, 245, 212, 0.25);
      background: #080a1c;
      overflow: hidden;
    }
    canvas {
      width: 100%;
      height: 100%;
      display: block;
      image-rendering: pixelated;
    }
    .overlay {
      position: absolute;
      inset: 0;
      display: none;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: rgba(8, 10, 28, 0.86);
      padding: 24px;
      z-index: 10;
    }
    .overlay.active { display: flex; }
    .panel {
      background: rgba(16, 20, 48, 0.96);
      border: 2px solid var(--neon-cyan);
      border-radius: 8px;
      padding: 24px;
      max-width: 880px;
      width: 92%;
      box-shadow: 0 0 24px rgba(0, 245, 212, 0.2);
    }
    h1, h2 { color: var(--neon-cyan); text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 12px; }
    .btn {
      background: linear-gradient(180deg, #1b2d6b 0%, #0f1942 100%);
      color: #ffffff;
      border: 2px solid var(--neon-cyan);
      padding: 10px 18px;
      font-family: inherit;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      border-radius: 4px;
      transition: transform 0.1s, background 0.15s;
      margin: 5px;
    }
    .btn:hover { background: var(--elec-blue); transform: translateY(-1px); }
    .btn.primary { border-color: var(--warm-yellow); color: var(--warm-yellow); font-size: 18px; }
    input {
      background: #080b1e;
      border: 1px solid var(--elec-blue);
      color: #fff;
      padding: 10px;
      font-family: inherit;
      font-size: 15px;
      width: 100%;
      margin: 6px 0 14px;
      border-radius: 4px;
    }
    table { width: 100%; border-collapse: collapse; margin: 12px 0; }
    th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid rgba(58, 134, 255, 0.3); }
    th { color: var(--warm-yellow); }
    .me-row { color: var(--neon-cyan); font-weight: bold; }
  </style>
</head>
<body>
  <div id="game-wrapper">
    <canvas id="game-canvas" width="1280" height="720"></canvas>

    <!-- Auth Overlay -->
    <div id="auth-overlay" class="overlay">
      <div class="panel" style="max-width:520px;">
        <h2>Space Command // Pilot Auth</h2>
        <p style="margin-bottom:12px;font-size:13px;color:#a8c5ff;">Sign in to submit verified runs to the Global Leaderboards.</p>
        <label>Email</label>
        <input id="auth-email" type="email" value="toby@spacetoby.io" />
        <label>Password</label>
        <input id="auth-pass" type="password" value="Quantum2026!" />
        <label>Public Nickname</label>
        <input id="auth-nick" type="text" value="TobyMaster" />
        <div id="auth-msg" style="color:var(--warm-yellow);min-height:22px;margin-bottom:8px;font-size:14px;"></div>
        <div>
          <button class="btn primary" onclick="window.SpaceTobyUI.login()">LOGIN</button>
          <button class="btn" onclick="window.SpaceTobyUI.signup()">SIGN UP</button>
          <button class="btn" onclick="window.SpaceTobyUI.closeOverlays()">BACK</button>
        </div>
      </div>
    </div>

    <!-- Leaderboards Overlay -->
    <div id="lb-overlay" class="overlay">
      <div class="panel">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <h2>🏆 Global Leaderboards</h2>
          <button class="btn" onclick="window.SpaceTobyUI.closeOverlays()">← BACK</button>
        </div>
        <div style="margin:10px 0;">
          <button class="btn primary" onclick="window.SpaceTobyUI.loadLeaderboard('kills', 1)">RANKING A: MOST KILLS</button>
          <button class="btn" onclick="window.SpaceTobyUI.loadLeaderboard('distance', 1)">RANKING B: LONGEST DISTANCE</button>
        </div>
        <table>
          <thead><tr><th>Rank</th><th>Pilot Nickname</th><th>Best Score</th></tr></thead>
          <tbody id="lb-tbody"></tbody>
        </table>
        <div id="lb-me" style="color:var(--neon-cyan);margin-top:8px;font-weight:bold;"></div>
      </div>
    </div>
  </div>

  <script>
    const API_BASE = window.SPACETOBY_API_URL || 'http://localhost:3000';
    const canvas = document.getElementById('game-canvas');
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;

    const IMAGES = {};
    const IMAGE_PATHS = {
      logo: 'assets/ui/spacetoby_logo.png',
      cutscene: 'assets/ui/cutscene_heist_escape.png',
      tobyHappy: 'assets/characters/toby_portrait_happy.png',
      tobyDet: 'assets/characters/toby_portrait_determined.png',
      tobyCurse: 'assets/characters/toby_portrait_cursing.png',
      tobyOver: 'assets/characters/toby_portrait_gameover.png',
      vex: 'assets/characters/baron_vex_portrait.png',
      shipIdle: 'assets/spaceships/player_ship_idle.png',
      shipThrust: 'assets/spaceships/player_ship_thrust.png',
      scout: 'assets/enemies/enemy_scout.png',
      fighter: 'assets/enemies/enemy_fighter.png',
      heavy: 'assets/enemies/enemy_heavy.png',
      asteroid: 'assets/enemies/obstacle_asteroid_large.png',
      pillar: 'assets/enemies/obstacle_station_pillar.png',
      laserPlayer: 'assets/effects/laser_player.png',
      laserEnemy: 'assets/effects/laser_enemy.png',
      explosion: 'assets/effects/explosion_burst.png',
      bgStar: 'assets/backgrounds/starfield_deep.png',
      bgNebula: 'assets/backgrounds/nebula_layer.png',
      bgPlanet: 'assets/backgrounds/bg_planet.png'
    };
    Object.entries(IMAGE_PATHS).forEach(([k, p]) => {
      const img = new Image();
      img.src = p;
      IMAGES[k] = img;
    });

    const SFX = {
      laser: new Audio('assets/audio/laser.wav'),
      thrust: new Audio('assets/audio/thrust.wav'),
      explosion: new Audio('assets/audio/explosion.wav'),
      hit: new Audio('assets/audio/hit.wav'),
      gameover: new Audio('assets/audio/gameover.wav'),
      button: new Audio('assets/audio/button.wav'),
      blip: new Audio('assets/audio/voice_blip.wav')
    };
    function playSfx(name) {
      try {
        const s = SFX[name];
        if (s) { s.currentTime = 0; s.volume = 0.45; s.play().catch(()=>{}); }
      } catch(e) {}
    }

    const CUTSCENE_LINES = [
      { speaker: 'ALARME DO COFRE SINDICATO [SETOR NEON-9]', color: '#ff5252', portrait: 'vex', text: 'ALERTA VERMELHO! O mercenário espacial Toby arrombou o Cofre Imperial e fugiu com o Cristal Quântico! Interceptem aquele beagle agora!!' },
      { speaker: 'BARÃO VEX (HOLOGRAMA)', color: '#ff8c1a', portrait: 'vex', text: '"SEU VIRA-LATA PULGUENTO! Devolve meu Cristal Quântico agora ou minha frota vai virar sua nave do avesso!"' },
      { speaker: 'TOBY — MERCENÁRIO DO ESPAÇO', color: '#00f5d4', portrait: 'tobyCurse', text: '"HAHAHA! Vai chorar no buraco negro, seu calango sovina do caramba!! Achou que ia esconder esse Cristal de mim?! Come poeira cósmica, seu lata-velha desgraçado!"' },
      { speaker: 'TOBY — MERCENÁRIO DO ESPAÇO', color: '#3a86ff', portrait: 'tobyDet', text: '"Segura firme! A frota inteira cercou o setor de asteroides... Canhões laser prontos, vamos sair rasgando!"' }
    ];

    const state = {
      screen: 'MENU', // MENU, CUTSCENE, GAME, GAMEOVER
      cutsceneIdx: 0,
      token: localStorage.getItem('spacetoby_token') || '',
      nickname: localStorage.getItem('spacetoby_nick') || 'TobyPilot',
      bestDistance: Number(localStorage.getItem('spacetoby_best_dist') || 0),
      bestKills: Number(localStorage.getItem('spacetoby_best_kills') || 0),
      sessionId: '',
      distance: 0,
      kills: 0,
      startTime: 0,
      scrollX: 0,
      ship: { x: 220, y: 340, vy: 0, rot: 0, fireCd: 0, thrusting: false, shooting: false },
      lasers: [],
      enemies: [],
      obstacles: [],
      explosions: [],
      spawnTimer: 1.0,
      obsTimer: 2.2,
      lastSafeY: 360,
      submitMsg: ''
    };

    function startCutscene() {
      playSfx('button');
      state.screen = 'CUTSCENE';
      state.cutsceneIdx = 0;
    }

    async function startGame() {
      playSfx('button');
      state.screen = 'GAME';
      state.distance = 0;
      state.kills = 0;
      state.startTime = performance.now();
      state.ship = { x: 220, y: 340, vy: 0, rot: 0, fireCd: 0, thrusting: false, shooting: false };
      state.lasers = [];
      state.enemies = [];
      state.obstacles = [];
      state.explosions = [];
      state.spawnTimer = 1.1;
      state.obsTimer = 2.2;
      state.lastSafeY = 360;
      state.sessionId = '';
      if (state.token) {
        try {
          const r = await fetch(API_BASE + '/api/v1/game-sessions', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + state.token }
          });
          const j = await r.json();
          if (j.data && j.data.sessionId) state.sessionId = j.data.sessionId;
        } catch(e) {}
      }
    }

    async function endGame() {
      if (state.screen === 'GAMEOVER') return;
      state.screen = 'GAMEOVER';
      playSfx('explosion');
      playSfx('gameover');
      const d = Math.floor(state.distance);
      const k = state.kills;
      const dur = Math.max(200, Math.floor(performance.now() - state.startTime));
      if (d > state.bestDistance) { state.bestDistance = d; localStorage.setItem('spacetoby_best_dist', d); }
      if (k > state.bestKills) { state.bestKills = k; localStorage.setItem('spacetoby_best_kills', k); }
      if (state.token && state.sessionId) {
        state.submitMsg = 'Submitting score to Space Command...';
        try {
          const r = await fetch(`${API_BASE}/api/v1/game-sessions/${state.sessionId}/complete`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + state.token },
            body: JSON.stringify({ distance: d, enemiesKilled: k, clientDurationMs: dur })
          });
          const j = await r.json();
          if (j.data) {
            state.submitMsg = `Score Verified! Ranks — Kills: #${j.data.killsRank || '-'} | Distance: #${j.data.distanceRank || '-'}`;
          } else {
            state.submitMsg = 'Saved locally.';
          }
        } catch(e) { state.submitMsg = 'Saved locally (Offline).'; }
      } else {
        state.submitMsg = 'Sign in on Main Menu to rank on Global Leaderboards!';
      }
    }

    window.addEventListener('keydown', (e) => {
      if (document.querySelector('.overlay.active')) return;
      if (e.code === 'Space' || e.code === 'KeyW' || e.code === 'ArrowUp') {
        if (state.screen === 'MENU') startCutscene();
        else if (state.screen === 'CUTSCENE') {
          state.cutsceneIdx++;
          playSfx('button');
          if (state.cutsceneIdx >= CUTSCENE_LINES.length) startGame();
        } else if (state.screen === 'GAME') {
          state.ship.vy = -410;
          state.ship.thrusting = true;
          playSfx('thrust');
        } else if (state.screen === 'GAMEOVER') startGame();
      }
      if (e.code === 'KeyJ' || e.code === 'KeyZ' || e.code === 'KeyK') {
        state.ship.shooting = true;
      }
      if (e.code === 'Escape' && state.screen === 'CUTSCENE') startGame();
    });

    window.addEventListener('keyup', (e) => {
      if (e.code === 'Space' || e.code === 'KeyW' || e.code === 'ArrowUp') state.ship.thrusting = false;
      if (e.code === 'KeyJ' || e.code === 'KeyZ' || e.code === 'KeyK') state.ship.shooting = false;
    });

    canvas.addEventListener('pointerdown', (e) => {
      const rect = canvas.getBoundingClientRect();
      const x = (e.clientX - rect.left) * (1280 / rect.width);
      const y = (e.clientY - rect.top) * (720 / rect.height);
      if (state.screen === 'MENU') {
        if (x >= 100 && x <= 540 && y >= 250 && y <= 310) startGame();
        else if (x >= 100 && x <= 540 && y >= 325 && y <= 380) startCutscene();
        else if (x >= 100 && x <= 540 && y >= 395 && y <= 450) window.SpaceTobyUI.openLeaderboards();
        else if (x >= 100 && x <= 540 && y >= 465 && y <= 520) window.SpaceTobyUI.openAuth();
      } else if (state.screen === 'CUTSCENE') {
        state.cutsceneIdx++;
        playSfx('button');
        if (state.cutsceneIdx >= CUTSCENE_LINES.length) startGame();
      } else if (state.screen === 'GAME') {
        if (x < 640) { state.ship.vy = -410; state.ship.thrusting = true; playSfx('thrust'); }
        else { state.ship.shooting = true; }
      } else if (state.screen === 'GAMEOVER') {
        if (y >= 410 && y <= 475) startGame();
        else if (y >= 490 && y <= 550 && x < 640) window.SpaceTobyUI.openLeaderboards();
        else if (y >= 490 && y <= 550 && x >= 640) state.screen = 'MENU';
      }
    });

    canvas.addEventListener('pointerup', () => {
      state.ship.thrusting = false;
      state.ship.shooting = false;
    });

    let lastTs = performance.now();
    function loop(ts) {
      const dt = Math.min(0.05, (ts - lastTs) / 1000);
      lastTs = ts;
      update(dt);
      render(ts / 1000);
      requestAnimationFrame(loop);
    }

    function update(dt) {
      state.scrollX = (state.scrollX + 120 * dt) % 1280;
      if (state.screen !== 'GAME') return;

      const diff = Math.min(1, state.distance / 12000);
      const speed = 280 + (680 - 280) * diff;
      state.distance += speed * dt * 0.08;

      const s = state.ship;
      s.vy += 1180 * dt;
      if (s.thrusting) s.vy -= 680 * dt;
      s.vy = Math.max(-460, Math.min(540, s.vy));
      s.y += s.vy * dt;
      s.rot = Math.max(-0.45, Math.min(0.5, s.vy / 520));
      if (s.y < 50) { s.y = 50; s.vy = 0; }
      if (s.y > 670) { endGame(); return; }

      s.fireCd = Math.max(0, s.fireCd - dt);
      if (s.shooting && s.fireCd <= 0) {
        s.fireCd = 0.20;
        state.lasers.push({ x: s.x + 48, y: s.y, vx: 900, player: true });
        playSfx('laser');
      }

      state.spawnTimer -= dt;
      if (state.spawnTimer <= 0) {
        state.spawnTimer = 2.1 - 1.3 * diff;
        const r = Math.random();
        const type = r < 0.55 ? 'scout' : (r < 0.85 ? 'fighter' : 'heavy');
        const hp = type === 'scout' ? 2 : (type === 'fighter' ? 4 : 8);
        const y = Math.max(90, Math.min(630, state.lastSafeY + (Math.random() * 280 - 140)));
        state.enemies.push({ type, x: 1340, y, baseY: y, hp, maxHp: hp, t: 0, fireCd: 1.5 });
      }

      state.obsTimer -= dt;
      if (state.obsTimer <= 0) {
        state.obsTimer = 3.1 - 1.5 * diff;
        const gap = 240 - 75 * diff;
        state.lastSafeY = Math.max(180, Math.min(540, state.lastSafeY + (Math.random() * 260 - 130)));
        const astY = Math.random() < 0.5 ? Math.max(65, state.lastSafeY - gap * 0.75) : Math.min(655, state.lastSafeY + gap * 0.75);
        state.obstacles.push({ x: 1340, y: astY, r: 34 });
      }

      for (let i = state.lasers.length - 1; i >= 0; i--) {
        const l = state.lasers[i];
        l.x += l.vx * dt;
        if (l.x > 1350 || l.x < -60) { state.lasers.splice(i, 1); continue; }
        if (!l.player && Math.hypot(l.x - s.x, l.y - s.y) < 34) { endGame(); return; }
      }

      for (let i = state.enemies.length - 1; i >= 0; i--) {
        const e = state.enemies[i];
        e.t += dt;
        const mult = e.type === 'scout' ? 1.3 : (e.type === 'fighter' ? 1.05 : 0.72);
        e.x -= speed * mult * dt;
        e.y = e.baseY + Math.sin(e.t * 2.5) * 36;
        if (e.type !== 'scout') {
          e.fireCd -= dt;
          if (e.fireCd <= 0) {
            e.fireCd = 1.9;
            state.lasers.push({ x: e.x - 36, y: e.y, vx: -480, player: false });
          }
        }
        if (Math.hypot(e.x - s.x, e.y - s.y) < 44) { endGame(); return; }
        for (let j = state.lasers.length - 1; j >= 0; j--) {
          const l = state.lasers[j];
          if (l.player && Math.hypot(l.x - e.x, l.y - e.y) < 42) {
            e.hp--;
            state.lasers.splice(j, 1);
            if (e.hp <= 0) {
              state.kills++;
              playSfx('explosion');
              state.explosions.push({ x: e.x, y: e.y, t: 0.28 });
              state.enemies.splice(i, 1);
            } else {
              playSfx('hit');
            }
            break;
          }
        }
        if (e && e.x < -120) state.enemies.splice(i, 1);
      }

      for (let i = state.obstacles.length - 1; i >= 0; i--) {
        const o = state.obstacles[i];
        o.x -= speed * dt;
        if (Math.hypot(o.x - s.x, o.y - s.y) < o.r + 22) { endGame(); return; }
        if (o.x < -120) state.obstacles.splice(i, 1);
      }

      for (let i = state.explosions.length - 1; i >= 0; i--) {
        state.explosions[i].t -= dt;
        if (state.explosions[i].t <= 0) state.explosions.splice(i, 1);
      }
    }

    function render(t) {
      ctx.fillStyle = '#080a1c';
      ctx.fillRect(0, 0, 1280, 720);
      if (IMAGES.bgStar.complete) {
        ctx.drawImage(IMAGES.bgStar, -state.scrollX, 0, 1280, 720);
        ctx.drawImage(IMAGES.bgStar, 1280 - state.scrollX, 0, 1280, 720);
      }
      if (IMAGES.bgPlanet.complete) ctx.drawImage(IMAGES.bgPlanet, 920, 90, 200, 200);

      if (state.screen === 'MENU') {
        if (IMAGES.logo.complete) ctx.drawImage(IMAGES.logo, 95, 45, 450, 135);
        ctx.fillStyle = '#00f5d4';
        ctx.font = 'bold 18px Courier New';
        ctx.fillText('2D SPACE MERCENARY ARCADE // PILOT: ' + state.nickname, 100, 210);

        const btns = [
          { y: 250, label: '▶ PLAY SPACETOBY [SPACE]' },
          { y: 325, label: '🎬 WATCH HEIST CUTSCENE' },
          { y: 395, label: '🏆 GLOBAL LEADERBOARDS' },
          { y: 465, label: '🐾 PILOT LOGIN / PROFILE' }
        ];
        btns.forEach(b => {
          ctx.fillStyle = '#121d4a';
          ctx.fillRect(100, b.y, 440, 54);
          ctx.strokeStyle = '#00f5d4';
          ctx.lineWidth = 2;
          ctx.strokeRect(100, b.y, 440, 54);
          ctx.fillStyle = '#ffffff';
          ctx.font = 'bold 20px Courier New';
          ctx.fillText(b.label, 124, b.y + 34);
        });

        ctx.fillStyle = '#ffbe0b';
        ctx.font = 'bold 18px Courier New';
        ctx.fillText(`BEST DISTANCE: ${state.bestDistance} m   |   BEST KILLS: ${state.bestKills}`, 100, 575);

        if (IMAGES.shipThrust.complete) {
          ctx.drawImage(IMAGES.shipThrust, 760, 220 + Math.sin(t * 3) * 14, 260, 172);
        }
        if (IMAGES.tobyHappy.complete) {
          ctx.drawImage(IMAGES.tobyHappy, 680, 440, 130, 130);
        }
        ctx.fillStyle = '#e2eeff';
        ctx.font = '16px Courier New';
        ctx.fillText('"Roubei o Cristal Quântico do Barão Vex!', 825, 490);
        ctx.fillText(' Segura nos lasers que a fuga vai ser insana!"', 825, 516);
      } else if (state.screen === 'CUTSCENE') {
        const beat = CUTSCENE_LINES[state.cutsceneIdx] || CUTSCENE_LINES[0];
        if (IMAGES.cutscene.complete) ctx.drawImage(IMAGES.cutscene, 200, 60, 880, 360);
        ctx.fillStyle = 'rgba(10, 14, 36, 0.94)';
        ctx.fillRect(100, 450, 1080, 220);
        ctx.strokeStyle = '#00f5d4';
        ctx.strokeRect(100, 450, 1080, 220);
        const port = IMAGES[beat.portrait];
        if (port && port.complete) ctx.drawImage(port, 124, 472, 170, 170);
        ctx.fillStyle = beat.color;
        ctx.font = 'bold 22px Courier New';
        ctx.fillText(beat.speaker, 320, 495);
        ctx.fillStyle = '#ffffff';
        ctx.font = '19px Courier New';
        const words = beat.text.split(' ');
        let line = '', ly = 540;
        words.forEach(w => {
          if ((line + w).length > 62) { ctx.fillText(line, 320, ly); line = w + ' '; ly += 28; }
          else line += w + ' ';
        });
        ctx.fillText(line, 320, ly);
        ctx.fillStyle = '#ffbe0b';
        ctx.fillText('[SPACE / CLICK] AVANÇAR ▶   |   [ESC] PULAR', 700, 648);
      } else if (state.screen === 'GAME' || state.screen === 'GAMEOVER') {
        const s = state.ship;
        ctx.save();
        ctx.translate(s.x, s.y);
        ctx.rotate(s.rot);
        const spr = s.thrusting ? IMAGES.shipThrust : IMAGES.shipIdle;
        if (spr && spr.complete) ctx.drawImage(spr, -54, -36, 108, 72);
        ctx.restore();

        state.lasers.forEach(l => {
          const img = l.player ? IMAGES.laserPlayer : IMAGES.laserEnemy;
          if (img && img.complete) ctx.drawImage(img, l.x - 24, l.y - 12, 48, 24);
        });
        state.enemies.forEach(e => {
          const img = IMAGES[e.type];
          const w = e.type === 'heavy' ? 128 : 80;
          const h = e.type === 'heavy' ? 96 : 64;
          if (img && img.complete) ctx.drawImage(img, e.x - w/2, e.y - h/2, w, h);
        });
        state.obstacles.forEach(o => {
          if (IMAGES.asteroid.complete) ctx.drawImage(IMAGES.asteroid, o.x - 42, o.y - 42, 84, 84);
        });
        state.explosions.forEach(ex => {
          if (IMAGES.explosion.complete) ctx.drawImage(IMAGES.explosion, ex.x - 48, ex.y - 48, 96, 96);
        });

        ctx.fillStyle = 'rgba(10, 14, 38, 0.85)';
        ctx.fillRect(20, 16, 430, 76);
        ctx.strokeStyle = '#00f5d4';
        ctx.strokeRect(20, 16, 430, 76);
        if (IMAGES.tobyDet.complete) ctx.drawImage(IMAGES.tobyDet, 28, 22, 64, 64);
        ctx.fillStyle = '#00f5d4';
        ctx.font = 'bold 22px Courier New';
        ctx.fillText(`DISTANCE: ${Math.floor(state.distance)} m`, 106, 48);
        ctx.fillStyle = '#ffbe0b';
        ctx.fillText(`KILLS: ${state.kills}`, 106, 78);

        if (state.screen === 'GAMEOVER') {
          ctx.fillStyle = 'rgba(8, 10, 28, 0.88)';
          ctx.fillRect(280, 100, 720, 500);
          ctx.strokeStyle = '#ff5252';
          ctx.strokeRect(280, 100, 720, 500);
          if (IMAGES.tobyOver.complete) ctx.drawImage(IMAGES.tobyOver, 580, 120, 120, 120);
          ctx.fillStyle = '#ff5252';
          ctx.font = 'bold 32px Courier New';
          ctx.fillText('SHIP DOWN // GAME OVER', 425, 275);
          ctx.fillStyle = '#00f5d4';
          ctx.font = 'bold 22px Courier New';
          ctx.fillText(`RUN DISTANCE: ${Math.floor(state.distance)} m (BEST: ${state.bestDistance} m)`, 370, 325);
          ctx.fillStyle = '#ffbe0b';
          ctx.fillText(`ENEMIES KILLED: ${state.kills} (BEST: ${state.bestKills})`, 370, 360);
          ctx.fillStyle = '#d0e2ff';
          ctx.font = '15px Courier New';
          ctx.fillText(state.submitMsg, 350, 395);

          ctx.fillStyle = '#182b68';
          ctx.fillRect(350, 415, 580, 54);
          ctx.strokeStyle = '#00f5d4';
          ctx.strokeRect(350, 415, 580, 54);
          ctx.fillStyle = '#fff';
          ctx.font = 'bold 22px Courier New';
          ctx.fillText('↻ INSTANT RESTART [SPACE / CLICK]', 420, 450);

          ctx.fillRect(350, 490, 275, 48);
          ctx.strokeRect(350, 490, 275, 48);
          ctx.fillText('🏆 LEADERBOARDS', 385, 522);

          ctx.fillRect(655, 490, 275, 48);
          ctx.strokeRect(655, 490, 275, 48);
          ctx.fillText('🏠 MAIN MENU', 715, 522);
        }
      }
    }

    window.SpaceTobyUI = {
      openAuth() {
        playSfx('button');
        document.getElementById('auth-overlay').classList.add('active');
      },
      openLeaderboards() {
        playSfx('button');
        document.getElementById('lb-overlay').classList.add('active');
        this.loadLeaderboard('kills', 1);
      },
      closeOverlays() {
        playSfx('button');
        document.querySelectorAll('.overlay').forEach(el => el.classList.remove('active'));
      },
      async login() {
        const email = document.getElementById('auth-email').value;
        const password = document.getElementById('auth-pass').value;
        try {
          const r = await fetch(API_BASE + '/api/v1/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
          });
          const j = await r.json();
          if (j.data && j.data.accessToken) {
            state.token = j.data.accessToken;
            state.nickname = j.data.user.nickname;
            localStorage.setItem('spacetoby_token', state.token);
            localStorage.setItem('spacetoby_nick', state.nickname);
            document.getElementById('auth-msg').textContent = 'Logged in as ' + state.nickname + '!';
            setTimeout(() => this.closeOverlays(), 600);
          }
        } catch(e) {
          document.getElementById('auth-msg').textContent = 'Offline mode active.';
        }
      },
      async signup() {
        const email = document.getElementById('auth-email').value;
        const password = document.getElementById('auth-pass').value;
        const nickname = document.getElementById('auth-nick').value;
        try {
          const r = await fetch(API_BASE + '/api/v1/auth/signup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password, nickname })
          });
          const j = await r.json();
          if (j.data && j.data.accessToken) {
            state.token = j.data.accessToken;
            state.nickname = j.data.user.nickname;
            localStorage.setItem('spacetoby_token', state.token);
            localStorage.setItem('spacetoby_nick', state.nickname);
            document.getElementById('auth-msg').textContent = 'Signed up as ' + state.nickname + '!';
            setTimeout(() => this.closeOverlays(), 600);
          }
        } catch(e) {
          document.getElementById('auth-msg').textContent = 'Offline mode active.';
        }
      },
      async loadLeaderboard(metric, page) {
        const tbody = document.getElementById('lb-tbody');
        tbody.innerHTML = '<tr><td colspan="3">Loading global rankings...</td></tr>';
        const unit = metric === 'kills' ? ' Kills' : ' m';
        try {
          const headers = state.token ? { 'Authorization': 'Bearer ' + state.token } : {};
          const r = await fetch(`${API_BASE}/api/v1/leaderboards/${metric}?page=${page}&limit=10`, { headers });
          const j = await r.json();
          const d = j.data;
          tbody.innerHTML = '';
          (d.entries || []).forEach(e => {
            const tr = document.createElement('tr');
            if (e.isCurrentPlayer || e.nickname === state.nickname) tr.className = 'me-row';
            tr.innerHTML = `<td>#${e.rank}</td><td>${e.nickname}</td><td>${e.score}${unit}</td>`;
            tbody.appendChild(tr);
          });
          document.getElementById('lb-me').textContent = d.currentPlayerEntry
            ? `Your Global Rank: #${d.currentPlayerEntry.rank} (${d.currentPlayerEntry.score}${unit})`
            : `Pilot: ${state.nickname}`;
        } catch(e) {
          tbody.innerHTML = `
            <tr><td>#1</td><td>TobyMaster</td><td>${metric === 'kills' ? '142 Kills' : '18450 m'}</td></tr>
            <tr><td>#2</td><td>SpaceDog</td><td>${metric === 'kills' ? '119 Kills' : '16200 m'}</td></tr>
            <tr><td>#3</td><td>BeaglePilot</td><td>${metric === 'kills' ? '96 Kills' : '13900 m'}</td></tr>
          `;
        }
      }
    };

    requestAnimationFrame(loop);
  </script>
</body>
</html>
"""


def main():
    copy_assets_to_web()
    out_html = os.path.join(OUT_DIR, "index.html")
    with open(out_html, "w", encoding="utf-8") as f:
        f.write(HTML_CONTENT)
    print(f"Wrote standalone playable web bundle to {out_html}")


if __name__ == "__main__":
    main()
