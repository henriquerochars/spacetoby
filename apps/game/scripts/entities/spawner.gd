class_name Spawner
extends Node2D
## SpaceToby Procedural Enemy & Obstacle Spawner.
## Spawns enemies outside the visible screen using weighted random selection,
## scales difficulty over time via DifficultyManager, and enforces a passable
## safe-corridor height so impossible obstacle configurations never occur.

signal enemy_spawned(enemy: EnemyShip)
signal obstacle_spawned(obstacle: SpaceObstacle)

const SPAWN_X: float = 1360.0
const VIEWPORT_HEIGHT: float = 720.0
const SAFE_MARGIN_Y: float = 110.0

var rng := RandomNumberGenerator.new()
var enemy_timer: float = 1.2
var obstacle_timer: float = 2.4
var last_safe_gap_y: float = 360.0


func _ready() -> void:
	rng.randomize()


func reset() -> void:
	enemy_timer = 1.2
	obstacle_timer = 2.4
	last_safe_gap_y = 360.0


func tick(delta: float) -> void:
	enemy_timer -= delta
	obstacle_timer -= delta

	if obstacle_timer <= 0.0:
		obstacle_timer = DifficultyManager.get_obstacle_spawn_interval()
		spawn_obstacle_formation()

	if enemy_timer <= 0.0:
		enemy_timer = DifficultyManager.get_enemy_spawn_interval()
		spawn_enemy()


func spawn_enemy(forced_type: String = "") -> EnemyShip:
	var etype := forced_type if not forced_type.is_empty() else DifficultyManager.pick_weighted_enemy_type(rng)
	var enemy := EnemyShip.new()
	# Spawn near or within reachable vertical corridor
	var spawn_y := clampf(
		last_safe_gap_y + rng.randf_range(-160.0, 160.0),
		90.0,
		630.0
	)
	enemy.configure(etype, Vector2(SPAWN_X, spawn_y))
	get_parent().add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func spawn_obstacle_formation() -> Array[SpaceObstacle]:
	var created: Array[SpaceObstacle] = []
	var gap_height: float = DifficultyManager.get_obstacle_gap_height()
	# Limit vertical delta between consecutive gates so the player can always physically reach the next gap
	var max_shift: float = 185.0
	var next_gap_y: float = clampf(
		last_safe_gap_y + rng.randf_range(-max_shift, max_shift),
		SAFE_MARGIN_Y + gap_height * 0.5,
		VIEWPORT_HEIGHT - SAFE_MARGIN_Y - gap_height * 0.5
	)
	last_safe_gap_y = next_gap_y

	var roll: float = rng.randf()
	if roll < 0.55:
		# Classic Flappy Bird-style top & bottom space-station pillar gate with guaranteed gap
		var top_bottom_edge: float = next_gap_y - gap_height * 0.5
		var bottom_top_edge: float = next_gap_y + gap_height * 0.5

		if top_bottom_edge > 48.0:
			var top_pillar := SpaceObstacle.new()
			top_pillar.configure("pillar", Vector2(SPAWN_X, top_bottom_edge * 0.5), top_bottom_edge, true)
			get_parent().add_child(top_pillar)
			obstacle_spawned.emit(top_pillar)
			created.append(top_pillar)

		var bottom_h: float = VIEWPORT_HEIGHT - bottom_top_edge
		if bottom_h > 48.0:
			var bottom_pillar := SpaceObstacle.new()
			bottom_pillar.configure("pillar", Vector2(SPAWN_X, bottom_top_edge + bottom_h * 0.5), bottom_h, false)
			get_parent().add_child(bottom_pillar)
			obstacle_spawned.emit(bottom_pillar)
			created.append(bottom_pillar)
	else:
		# Asteroid cluster placed OUTSIDE the safe gap corridor
		var place_above: bool = rng.randf() < 0.5
		var ast_y: float = (next_gap_y - gap_height * 0.65 - 40.0) if place_above else (next_gap_y + gap_height * 0.65 + 40.0)
		ast_y = clampf(ast_y, 64.0, 656.0)
		var ast := SpaceObstacle.new()
		ast.configure("asteroid", Vector2(SPAWN_X, ast_y))
		get_parent().add_child(ast)
		obstacle_spawned.emit(ast)
		created.append(ast)

	return created
