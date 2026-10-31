# Gameplay and Tuning

SpaceToby is a 1280×720 side-scrolling arcade game. Toby pilots through enemy waves and procedural space-station gates, collecting kills and distance while avoiding collisions.

## Controls

| Action | Desktop | Mobile |
| --- | --- | --- |
| Thrust | `Space`, `W`, or left click | Touch the left half of the screen |
| Fire | `J` or `Z` | Touch the right half of the screen |
| Pause/back | `Esc` | On-screen navigation controls |

The first thrust press applies an upward impulse of `-410 px/s`. Holding thrust adds `-720 px/s²`; gravity continuously adds `1180 px/s²`. Vertical velocity is clamped between `-460 px/s` and `540 px/s`.

## Combat

The player fires forward lasers with a `0.20 s` cooldown. Enemy ships move left with archetype-specific speed and vertical weave:

| Enemy | HP | Scroll multiplier | Behavior |
| --- | ---: | ---: | --- |
| Scout | 2 | 1.32× | Fast sine-wave movement; does not fire. |
| Fighter | 4 | 1.05× | Medium weave; fires toward the player. |
| Heavy | 8 | 0.72× | Armored and slow; fires heavier volleys. |

Destroying an enemy advances kills and plays an eight-frame pixel explosion. The player thruster flame cycles through four stepped silhouettes.

## Difficulty curve

`DifficultyManager` derives a smooth factor from distance: `1 - (1 - clamp(distance / 12000, 0, 1))^1.45`.

| Tuning | Start | Maximum difficulty |
| --- | ---: | ---: |
| Scroll speed | 280 px/s | 680 px/s |
| Enemy spawn interval | 2.15 s | 0.68 s |
| Obstacle spawn interval | 3.20 s | 1.35 s |
| Obstacle opening height | 250 px | 158 px |

Enemy selection weights shift from Scout/Fighter/Heavy `72/23/5` at the start to `38/40/22` at maximum difficulty. Obstacle openings shift between safe vertical bounds so gates remain reachable.

## Run lifecycle

The game records distance and kills for each run. The backend issues a session before play and validates its owner, completion state, duration, speed, kill rate, and telemetry before accepting a score. The two global boards rank kills and distance separately.
