extends Node
## Central DifficultyManager for SpaceToby.
## Smoothly scales scroll speed, enemy spawn frequency, enemy type distribution,
## obstacle density, and enemy projectile rates based on distance traveled.

const BASE_SCROLL_SPEED: float = 280.0
const MAX_SCROLL_SPEED: float = 680.0
const SPEED_RAMP_DISTANCE: float = 12000.0

const BASE_ENEMY_SPAWN_INTERVAL: float = 2.15
const MIN_ENEMY_SPAWN_INTERVAL: float = 0.68

const BASE_OBSTACLE_SPAWN_INTERVAL: float = 3.20
const MIN_OBSTACLE_SPAWN_INTERVAL: float = 1.35

const BASE_GAP_HEIGHT: float = 250.0
const MIN_GAP_HEIGHT: float = 158.0

var current_scroll_speed: float = BASE_SCROLL_SPEED
var difficulty_factor: float = 0.0 # 0.0 (start) -> 1.0 (max challenge)


func reset() -> void:
	current_scroll_speed = BASE_SCROLL_SPEED
	difficulty_factor = 0.0


func update_for_distance(distance: float) -> void:
	var clamped_dist: float = max(0.0, distance)
	# Smooth ease-out curve so difficulty rises steadily without sudden unfair spikes
	var linear_t: float = clampf(clamped_dist / SPEED_RAMP_DISTANCE, 0.0, 1.0)
	difficulty_factor = 1.0 - pow(1.0 - linear_t, 1.45)
	current_scroll_speed = lerpf(BASE_SCROLL_SPEED, MAX_SCROLL_SPEED, difficulty_factor)


func get_scroll_speed() -> float:
	return current_scroll_speed


func get_enemy_spawn_interval() -> float:
	return lerpf(BASE_ENEMY_SPAWN_INTERVAL, MIN_ENEMY_SPAWN_INTERVAL, difficulty_factor)


func get_obstacle_spawn_interval() -> float:
	return lerpf(BASE_OBSTACLE_SPAWN_INTERVAL, MIN_OBSTACLE_SPAWN_INTERVAL, difficulty_factor)


func get_obstacle_gap_height() -> float:
	return lerpf(BASE_GAP_HEIGHT, MIN_GAP_HEIGHT, difficulty_factor)


func get_enemy_fire_cooldown_multiplier() -> float:
	return lerpf(1.25, 0.58, difficulty_factor)


func get_enemy_weights() -> Dictionary:
	# Early game favors Scouts; mid game introduces Fighters; late game increases Heavy warships
	var scout_w: float = lerpf(72.0, 38.0, difficulty_factor)
	var fighter_w: float = lerpf(23.0, 40.0, difficulty_factor)
	var heavy_w: float = lerpf(5.0, 22.0, difficulty_factor)
	return {
		"scout": scout_w,
		"fighter": fighter_w,
		"heavy": heavy_w
	}


func pick_weighted_enemy_type(rng: RandomNumberGenerator) -> String:
	var weights := get_enemy_weights()
	var total: float = weights["scout"] + weights["fighter"] + weights["heavy"]
	var roll: float = rng.randf_range(0.0, total)
	if roll < weights["scout"]:
		return "scout"
	elif roll < weights["scout"] + weights["fighter"]:
		return "fighter"
	return "heavy"
