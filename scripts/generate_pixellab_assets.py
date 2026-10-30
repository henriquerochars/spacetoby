#!/usr/bin/env python3
"""
SpaceToby — PixelLab MCP Asset Generation Pipeline.
Connects to https://api.pixellab.ai/mcp using PIXELLAB_API_KEY from .env,
queues all original pixel-art assets for SpaceToby (Toby portraits, cutscenes,
player spaceship, enemies, projectiles, obstacles, backgrounds, UI), waits for
background jobs to complete, and downloads PNG sprites directly into apps/game/assets/.
"""
import os
import sys
import json
import time
import base64
import urllib.request
import urllib.error

from pixellab_mcp_client import PixelLabMCPClient

ASSETS_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "apps", "game", "assets")

ASSET_SPECS = [
    # --- Toby Portraits & Cutscene ---
    {
        "id": "toby_portrait_happy",
        "path": "characters/toby_portrait_happy.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Toby, a charismatic anthropomorphic male beagle space pilot with floppy brown and white ears, wearing a sleek futuristic navy and neon cyan space mercenary jacket, confident smirk, vibrant cosmic colors",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "toby_portrait_determined",
        "path": "characters/toby_portrait_determined.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Toby, an anthropomorphic male beagle space pilot with floppy brown and white ears, futuristic pilot visor and neon cyan jacket, intense determined expression, gritted teeth, sci-fi arcade style",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "toby_portrait_cursing",
        "path": "characters/toby_portrait_cursing.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Toby, a mischievous anthropomorphic male beagle space mercenary with floppy brown and white ears, shouting and cursing angrily while laughing, holding a glowing cyan stolen quantum crystal, red alarm light glow, expressive anime face",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "toby_portrait_surprised",
        "path": "characters/toby_portrait_surprised.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Toby, an anthropomorphic male beagle space pilot with floppy brown and white ears flying upward in shock, wide surprised eyes, sweat drop, futuristic neon cyan pilot suit",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "toby_portrait_gameover",
        "path": "characters/toby_portrait_gameover.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Toby, an anthropomorphic male beagle space pilot with singed fur, dizzy spiral eyes, smoke puff, funny defeated game over expression, scuffed futuristic pilot uniform",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "baron_vex_portrait",
        "path": "characters/baron_vex_portrait.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "anime style pixel art bust portrait of Baron Vex, a furious alien crime boss cyborg lizard in dark purple and orange armor, screaming into a hologram communicator in rage, sci-fi arcade villain",
            "width": 128,
            "height": 128,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "cutscene_heist_escape",
        "path": "ui/cutscene_heist_escape.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "dramatic pixel art sci-fi cutscene illustration, sleek blue and neon cyan starfighter blasting out of an exploding purple space syndicate vault with laser beams and alarms flashing, glowing quantum crystal in cockpit piloted by a beagle, retro arcade style",
            "width": 320,
            "height": 180,
            "no_background": False,
            "shading": "detailed shading",
            "detail": "highly detailed"
        }
    },
    # --- Player Spaceship (Facing Right) ---
    {
        "id": "player_ship_idle",
        "path": "spaceships/player_ship_idle.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "side view 2D arcade pixel art futuristic starfighter spaceship facing right, electric blue and white hull with neon cyan glowing accents and orange thruster nozzle, large transparent glass cockpit dome clearly showing a cute beagle dog pilot head inside, clean silhouette",
            "width": 96,
            "height": 64,
            "no_background": True,
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "player_ship_thrust",
        "path": "spaceships/player_ship_thrust.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "side view 2D arcade pixel art futuristic starfighter spaceship facing right tilting slightly upward with bright orange and warm yellow plasma flames roaring from rear thrusters, electric blue and neon cyan hull, transparent glass cockpit showing determined beagle pilot inside",
            "width": 96,
            "height": 64,
            "no_background": True,
            "view": "side",
            "direction": "east",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    # --- Enemy Spaceships (Facing Left) ---
    {
        "id": "enemy_scout",
        "path": "enemies/enemy_scout.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "side view 2D arcade pixel art small fast alien scout interceptor spaceship facing left, sharp crimson and dark purple hull with glowing orange cockpit visor and twin wings, retro space shooter enemy",
            "width": 64,
            "height": 48,
            "no_background": True,
            "view": "side",
            "direction": "west",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail"
        }
    },
    {
        "id": "enemy_fighter",
        "path": "enemies/enemy_fighter.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "side view 2D arcade pixel art medium alien assault fighter spaceship facing left, menacing dark purple and neon magenta armor with forward plasma cannons and glowing yellow engine core, space shooter enemy",
            "width": 80,
            "height": 64,
            "no_background": True,
            "view": "side",
            "direction": "west",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "enemy_heavy",
        "path": "enemies/enemy_heavy.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "side view 2D arcade pixel art massive heavy armored dreadnought warship facing left, bulky dark navy and purple plating with glowing orange reactor cores and heavy laser turrets, space arcade mini-boss enemy",
            "width": 128,
            "height": 96,
            "no_background": True,
            "view": "side",
            "direction": "west",
            "outline": "single color black outline",
            "shading": "detailed shading",
            "detail": "highly detailed"
        }
    },
    # --- Obstacles & Environment ---
    {
        "id": "obstacle_asteroid_large",
        "path": "enemies/obstacle_asteroid_large.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art jagged cosmic space asteroid rock with craters and glowing purple and cyan crystal veins, deep navy shadows, isolated game obstacle sprite",
            "width": 96,
            "height": 96,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "highly detailed"
        }
    },
    {
        "id": "obstacle_station_pillar",
        "path": "enemies/obstacle_station_pillar.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art vertical futuristic space station metal girder column obstacle with hazard orange stripes and glowing neon cyan energy conduits, side-scroller barrier",
            "width": 64,
            "height": 192,
            "no_background": True,
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail"
        }
    },
    {
        "id": "bg_planet",
        "path": "backgrounds/bg_planet.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art alien ringed gas giant planet in deep purple, electric blue, and neon cyan with glowing orbital rings, cosmic space background object",
            "width": 160,
            "height": 160,
            "no_background": True,
            "shading": "detailed shading",
            "detail": "highly detailed"
        }
    },
    # --- Projectiles & Effects ---
    {
        "id": "laser_player",
        "path": "effects/laser_player.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art bright neon cyan and white horizontal laser bolt energy projectile facing right with glowing plasma trail",
            "width": 64,
            "height": 32,
            "no_background": True
        }
    },
    {
        "id": "laser_enemy",
        "path": "effects/laser_enemy.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art fiery orange and red plasma orb projectile facing left with glowing energy tail",
            "width": 32,
            "height": 32,
            "no_background": True
        }
    },
    {
        "id": "explosion_burst",
        "path": "effects/explosion_burst.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art vibrant arcade space explosion fireball burst with bright yellow core, orange flames, and neon cyan shockwave sparks",
            "width": 96,
            "height": 96,
            "no_background": True
        }
    },
    {
        "id": "spacetoby_logo",
        "path": "ui/spacetoby_logo.png",
        "tool": "create_image_pixflux",
        "args": {
            "description": "pixel art retro arcade game title logo reading SPACETOBY in bold chrome electric blue and warm orange lettering with neon cyan star wings and a small beagle emblem",
            "width": 320,
            "height": 96,
            "no_background": True
        }
    }
]


def ensure_dirs():
    for sub in ["characters", "spaceships", "enemies", "backgrounds", "ui", "effects", "audio"]:
        os.makedirs(os.path.join(ASSETS_ROOT, sub), exist_ok=True)


def extract_job_id_or_save(res, out_path):
    """Parse MCP tool response to either extract a queued job_id or directly save returned image data."""
    if not isinstance(res, dict):
        return None
    result = res.get("result", {})
    content = result.get("content", [])
    job_id = None
    for item in content:
        if item.get("type") == "image" and item.get("data"):
            raw = base64.b64decode(item["data"])
            with open(out_path, "wb") as f:
                f.write(raw)
            return "SAVED"
        if item.get("type") == "text":
            txt = item.get("text", "")
            # Look for URL or job_id
            for line in txt.splitlines():
                if "job_id" in line or "id:" in line or "get_image" in line:
                    import re
                    m = re.search(r'job_id=["\']?([a-zA-Z0-9_:-]+)["\']?', line)
                    if m:
                        job_id = m.group(1)
                    else:
                        m2 = re.search(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', line)
                        if m2:
                            job_id = m2.group(1)
                if "https://" in line and (".png" in line or "storage" in line or "pixellab" in line):
                    import re
                    urls = re.findall(r'https://[^\s"\')>]+', line)
                    for u in urls:
                        try:
                            req = urllib.request.Request(u, headers={"User-Agent": "SpaceToby/1.0"})
                            with urllib.request.urlopen(req, timeout=30) as r:
                                data = r.read()
                                if data.startswith(b"\x89PNG"):
                                    with open(out_path, "wb") as f:
                                        f.write(data)
                                    return "SAVED"
                        except Exception:
                            pass
    return job_id


def main():
    ensure_dirs()
    client = PixelLabMCPClient()
    client.initialize()

    pending = {}
    manifest_records = []

    print(f"Starting PixelLab MCP generation for {len(ASSET_SPECS)} SpaceToby assets...")
    # Queue in batches of 4 to respect concurrency slots
    specs_queue = list(ASSET_SPECS)
    idx = 0
    while idx < len(specs_queue) or pending:
        while idx < len(specs_queue) and len(pending) < 4:
            spec = specs_queue[idx]
            idx += 1
            out_path = os.path.join(ASSETS_ROOT, spec["path"])
            if os.path.exists(out_path) and os.path.getsize(out_path) > 500:
                print(f"[SKIP] {spec['id']} already exists at {spec['path']}")
                manifest_records.append({
                    "id": spec["id"],
                    "path": f"res://assets/{spec['path']}",
                    "tool": spec["tool"],
                    "status": "cached"
                })
                continue

            print(f"[QUEUE] {spec['id']} via {spec['tool']}...")
            res = client.call_tool(spec["tool"], spec["args"])
            status = extract_job_id_or_save(res, out_path)
            if status == "SAVED":
                print(f"[DONE] {spec['id']} saved directly to {spec['path']}!")
                manifest_records.append({
                    "id": spec["id"],
                    "path": f"res://assets/{spec['path']}",
                    "tool": spec["tool"],
                    "status": "generated_direct"
                })
            elif status:
                print(f"[JOB] {spec['id']} -> job_id={status}")
                pending[status] = spec
            else:
                print(f"[WARN] Unexpected response for {spec['id']}: {json.dumps(res)[:300]}")

        if pending:
            print(f"Waiting for {len(pending)} active PixelLab jobs: {list(pending.keys())}...")
            client.call_tool("wait_for_jobs", {"timeout_seconds": 25, "min_finished": 1})
            finished = []
            for jid, spec in list(pending.items()):
                out_path = os.path.join(ASSETS_ROOT, spec["path"])
                img_res = client.call_tool("get_image", {"job_id": jid})
                st = extract_job_id_or_save(img_res, out_path)
                if st == "SAVED":
                    print(f"[SAVED] {spec['id']} (job {jid}) -> {spec['path']}")
                    manifest_records.append({
                        "id": spec["id"],
                        "path": f"res://assets/{spec['path']}",
                        "tool": spec["tool"],
                        "job_id": jid,
                        "status": "completed"
                    })
                    finished.append(jid)
                else:
                    txt = json.dumps(img_res)
                    if "failed" in txt.lower() or "error" in txt.lower() and "processing" not in txt.lower():
                        print(f"[FAILED] Job {jid} for {spec['id']}: {txt[:200]}")
                        finished.append(jid)
            for jid in finished:
                pending.pop(jid, None)

    manifest_file = os.path.join(ASSETS_ROOT, "pixellab_generation_log.json")
    with open(manifest_file, "w", encoding="utf-8") as f:
        json.dump(manifest_records, f, indent=2)
    print(f"All PixelLab MCP jobs processed! Log saved to {manifest_file}")


if __name__ == "__main__":
    main()
