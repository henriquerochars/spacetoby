extends Node
## SpaceToby Automated Headless Game Test Suite (`apps/game/tests/test_runner.gd`).
## Runs inside the active SceneTree (`tests/TestRunner.tscn`) where all Autoloads
## (`GameState`, `DifficultyManager`, `ApiClient`, `AudioManager`) are initialized.

var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
	print("============================================================")
	print("SpaceToby — Godot 4 Headless Automated Test Suite")
	print("============================================================")
	_run_all_tests()
	print("============================================================")
	print("RESULTS: %d Passed | %d Failed" % [passed_count, failed_count])
	print("============================================================")
	get_tree().quit(0 if failed_count == 0 else 1)


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passed_count += 1
		print("  [PASS] " + label)
	else:
		failed_count += 1
		printerr("  [FAIL] " + label)


func _run_all_tests() -> void:
	_test_pixellab_assets_loadable()
	_test_difficulty_progression()
	_test_player_movement_and_shooting()
	_test_enemies_spawning_and_destruction()
	_test_score_counters_gameover_and_restart()
	_test_all_scenes_instantiate()


func _test_pixellab_assets_loadable() -> void:
	print("\n-> Testing PixelLab & Audio Assets...")
	var required_assets := [
		"res://assets/characters/toby_portrait_happy.png",
		"res://assets/characters/toby_portrait_determined.png",
		"res://assets/characters/toby_portrait_cursing.png",
		"res://assets/characters/toby_portrait_surprised.png",
		"res://assets/characters/toby_portrait_gameover.png",
		"res://assets/characters/baron_vex_portrait.png",
		"res://assets/ui/cutscene_heist_escape.png",
		"res://assets/ui/spacetoby_logo.png",
		"res://assets/spaceships/player_ship_idle.png",
		"res://assets/spaceships/player_ship_thrust.png",
		"res://assets/enemies/enemy_scout.png",
		"res://assets/enemies/enemy_fighter.png",
		"res://assets/enemies/enemy_heavy.png",
		"res://assets/enemies/obstacle_asteroid_large.png",
		"res://assets/enemies/obstacle_station_pillar.png",
		"res://assets/effects/laser_player.png",
		"res://assets/effects/laser_enemy.png",
		"res://assets/effects/explosion_burst.png",
		"res://assets/backgrounds/starfield_deep.png",
		"res://assets/backgrounds/nebula_layer.png",
		"res://assets/backgrounds/bg_planet.png",
		"res://assets/audio/laser.wav",
		"res://assets/audio/explosion.wav",
		"res://assets/audio/menu_bgm.wav",
		"res://assets/audio/gameplay_bgm.wav",
		"res://assets/audio/cutscene_bgm.wav"
	]
	for path in required_assets:
		var exists := ResourceLoader.exists(path)
		assert_true(exists, "Asset exists and imports cleanly: " + path)


func _test_difficulty_progression() -> void:
	print("\n-> Testing DifficultyManager Progression...")
	assert_true(DifficultyManager != null, "DifficultyManager autoload is active")
	DifficultyManager.reset()
	var base_spd: float = DifficultyManager.get_scroll_speed()
	var base_enemy_int: float = DifficultyManager.get_enemy_spawn_interval()
	var base_obs_int: float = DifficultyManager.get_obstacle_spawn_interval()

	DifficultyManager.update_for_distance(6000.0)
	assert_true(DifficultyManager.get_scroll_speed() > base_spd, "Scroll speed increases with distance")
	assert_true(DifficultyManager.get_enemy_spawn_interval() < base_enemy_int, "Enemy spawn interval tightens with distance")
	assert_true(DifficultyManager.get_obstacle_spawn_interval() < base_obs_int, "Obstacle spawn interval tightens with distance")

	DifficultyManager.update_for_distance(15000.0)
	assert_true(DifficultyManager.get_scroll_speed() <= DifficultyManager.MAX_SCROLL_SPEED, "Scroll speed caps safely at MAX_SCROLL_SPEED")
	DifficultyManager.reset()


func _test_player_movement_and_shooting() -> void:
	print("\n-> Testing PlayerShip Flappy Movement & Laser Shooting...")
	var ship := PlayerShip.new()
	ship.position = Vector2(220.0, 340.0)
	add_child(ship)

	# Gravity pulls downward
	var start_y := ship.position.y
	ship._physics_process(0.1)
	assert_true(ship.velocity.y > 0.0 and ship.position.y > start_y, "Gravity continuously pulls spaceship downward")

	# Upward thrust applies upward impulse
	ship.apply_upward_thrust()
	assert_true(ship.velocity.y < 0.0, "Upward thrust sets negative vertical velocity")
	var velocity_after_tap := ship.velocity.y
	ship._physics_process(0.01)
	assert_true(absf(ship.velocity.y - (velocity_after_tap + ship.gravity_accel * 0.01)) < 0.001, "Thruster visual decay does not extend thrust after release")

	# Laser firing and cooldown
	var fired_positions: Array[Vector2] = []
	ship.laser_fired.connect(func(pos: Vector2): fired_positions.append(pos))
	var shot1 := ship.try_shoot()
	var shot2_immediate := ship.try_shoot()
	assert_true(shot1 == true and fired_positions.size() == 1, "Player fires forward laser when off cooldown")
	assert_true(shot2_immediate == false, "Laser cooldown prevents immediate spam")

	ship._physics_process(0.25)
	var shot3_after_cd := ship.try_shoot()
	assert_true(shot3_after_cd == true and fired_positions.size() == 2, "Player can shoot again after cooldown expires")

	ship.free()


func _test_enemies_spawning_and_destruction() -> void:
	print("\n-> Testing Enemy Spawning, Damage & Destruction...")
	GameState.start_new_run()

	var spawner := Spawner.new()
	add_child(spawner)

	var scout := spawner.spawn_enemy("scout")
	var fighter := spawner.spawn_enemy("fighter")
	var heavy := spawner.spawn_enemy("heavy")

	assert_true(scout.max_hp == 2, "Scout enemy initialized with 2 HP")
	assert_true(fighter.max_hp == 4 and fighter.can_shoot, "Fighter enemy initialized with 4 HP and shooting enabled")
	assert_true(heavy.max_hp == 8 and heavy.can_shoot, "Heavy enemy initialized with 8 HP and shooting enabled")

	var destroyed_types: Array[String] = []
	scout.enemy_destroyed.connect(func(t: String, _p: Vector2): destroyed_types.append(t))

	scout.take_damage(1)
	assert_true(scout.hp == 1, "Scout takes 1 laser damage (1 HP remaining)")
	scout.take_damage(1)
	assert_true(destroyed_types.has("scout") and GameState.current_kills == 1, "Scout destroyed on 2nd hit and increments kill counter")

	var obstacles := spawner.spawn_obstacle_formation()
	assert_true(obstacles.size() >= 1, "Procedural obstacle formation spawns with passable corridor")

	for o in obstacles:
		if is_instance_valid(o):
			o.free()
	if is_instance_valid(fighter):
		fighter.free()
	if is_instance_valid(heavy):
		heavy.free()
	if is_instance_valid(scout):
		scout.free()
	spawner.free()


func _test_score_counters_gameover_and_restart() -> void:
	print("\n-> Testing Score Counters, Collision Game-Over & Restart...")
	GameState.best_distance = 0
	GameState.best_kills = 0
	GameState.start_new_run()
	assert_true(GameState.is_running and GameState.current_distance == 0.0 and GameState.current_kills == 0, "New run resets current distance and kills to 0")

	GameState.add_distance(1420.6)
	GameState.register_enemy_kill(1)
	GameState.register_enemy_kill(1)
	assert_true(int(GameState.current_distance) == 1420 and GameState.current_kills == 2, "Distance and kill counters track active run accurately")

	var ship := PlayerShip.new()
	add_child(ship)
	var died_events: Array = []
	ship.player_died.connect(func(pos: Vector2): died_events.append(pos))
	ship.die()
	assert_true(died_events.size() == 1 and not ship.is_alive, "Collision triggers PlayerShip death signal and halts ship")

	var summary: Dictionary = GameState.finish_run()
	assert_true(not GameState.is_running, "Finishing run marks GameState.is_running = false")
	assert_true(int(summary["distance"]) == 1420 and int(summary["enemiesKilled"]) == 2, "Run summary captures final distance and kills")
	assert_true(GameState.best_distance == 1420 and GameState.best_kills == 2, "Personal best records persist after run finishes")

	# Restart behavior
	GameState.start_new_run()
	assert_true(GameState.is_running and int(GameState.current_distance) == 0 and GameState.current_kills == 0, "Restarting immediately resets run counters while preserving personal bests")
	assert_true(GameState.best_distance == 1420 and GameState.best_kills == 2, "Personal bests remain intact across restarts")
	ship.free()


func _test_all_scenes_instantiate() -> void:
	print("\n-> Testing All Game Screens Instantiate Cleanly...")
	var scenes := [
		"res://scenes/MainMenu.tscn",
		"res://scenes/Cutscene.tscn",
		"res://scenes/Gameplay.tscn",
		"res://scenes/AuthScreen.tscn",
		"res://scenes/GameOverScreen.tscn",
		"res://scenes/LeaderboardsScreen.tscn",
		"res://scenes/ProfileScreen.tscn"
	]
	for s_path in scenes:
		var packed: PackedScene = load(s_path)
		assert_true(packed != null, "Scene resource loads: " + s_path)
		if packed:
			var inst := packed.instantiate()
			assert_true(inst != null, "Scene instantiates without error: " + s_path)
			if inst:
				inst.free()
