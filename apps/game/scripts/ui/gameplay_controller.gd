extends Node2D
## SpaceToby Main Gameplay Scene Controller (`Gameplay.tscn`).
## Orchestrates the scrolling parallax environment, PlayerShip, Spawner, Projectiles,
## Explosion FX, Cockpit HUD, Mobile multitouch zones, Pause Overlay, and Game Over transition.

const DISTANCE_UNITS_PER_PIXEL: float = 0.08

var world_layer: Node2D
var player: PlayerShip
var spawner: Spawner

# Parallax Scrolling Sprites
var bg_star_a: Sprite2D
var bg_star_b: Sprite2D
var bg_nebula_a: Sprite2D
var bg_nebula_b: Sprite2D
var bg_planet: Sprite2D

# HUD Elements
var hud_layer: CanvasLayer
var distance_label: Label
var kills_label: Label
var speed_label: Label
var cockpit_portrait: TextureRect
var cockpit_status_label: Label
var pause_btn: Button

# Overlays
var pause_panel: Panel
var settings_panel: Panel
var is_transitioning_to_gameover: bool = false

# Multi-touch tracking (supports simultaneous left-screen thrust & right-screen shoot)
var active_touches: Dictionary = {} # touch_index -> Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.play_music("gameplay")
	_build_parallax_background()
	_build_world_and_entities()
	_build_hud_and_pause_ui()

	GameState.score_updated.connect(_on_score_updated)
	GameState.start_new_run()
	ApiClient.start_server_game_session()


func _build_parallax_background() -> void:
	var bg_node := Node2D.new()
	bg_node.name = "ParallaxBackground"
	add_child(bg_node)

	var star_tex: Texture2D = load("res://assets/backgrounds/starfield_deep.png")
	bg_star_a = Sprite2D.new()
	bg_star_a.centered = false
	bg_star_a.texture = star_tex
	bg_star_a.scale = Vector2(2.0, 2.0)
	bg_node.add_child(bg_star_a)

	bg_star_b = Sprite2D.new()
	bg_star_b.centered = false
	bg_star_b.texture = star_tex
	bg_star_b.scale = Vector2(2.0, 2.0)
	bg_star_b.position = Vector2(1280.0, 0.0)
	bg_node.add_child(bg_star_b)

	bg_planet = Sprite2D.new()
	bg_planet.texture = load("res://assets/backgrounds/bg_planet.png")
	bg_planet.position = Vector2(980.0, 190.0)
	bg_planet.scale = Vector2(1.35, 1.35)
	bg_planet.modulate = Color(1, 1, 1, 0.78)
	bg_node.add_child(bg_planet)

	var neb_tex: Texture2D = load("res://assets/backgrounds/nebula_layer.png")
	bg_nebula_a = Sprite2D.new()
	bg_nebula_a.centered = false
	bg_nebula_a.texture = neb_tex
	bg_nebula_a.scale = Vector2(2.0, 2.0)
	bg_node.add_child(bg_nebula_a)

	bg_nebula_b = Sprite2D.new()
	bg_nebula_b.centered = false
	bg_nebula_b.texture = neb_tex
	bg_nebula_b.scale = Vector2(2.0, 2.0)
	bg_nebula_b.position = Vector2(1280.0, 0.0)
	bg_node.add_child(bg_nebula_b)


func _build_world_and_entities() -> void:
	world_layer = Node2D.new()
	world_layer.name = "WorldLayer"
	world_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_layer)

	player = PlayerShip.new()
	player.name = "PlayerShip"
	player.position = Vector2(220.0, 340.0)
	player.laser_fired.connect(_on_player_laser_fired)
	player.player_died.connect(_on_player_died)
	player.cockpit_expression_changed.connect(_on_cockpit_expression_changed)
	world_layer.add_child(player)

	spawner = Spawner.new()
	spawner.name = "Spawner"
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	world_layer.add_child(spawner)


func _build_hud_and_pause_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)

	# Top Left Cockpit Mini-Monitor + Score Counters
	var hud_panel := Panel.new()
	hud_panel.position = Vector2(20, 16)
	hud_panel.size = Vector2(440, 84)
	hud_layer.add_child(hud_panel)

	cockpit_portrait = TextureRect.new()
	cockpit_portrait.texture = load("res://assets/characters/toby_portrait_happy.png")
	cockpit_portrait.position = Vector2(10, 8)
	cockpit_portrait.size = Vector2(68, 68)
	cockpit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_panel.add_child(cockpit_portrait)

	distance_label = Label.new()
	distance_label.text = "DISTANCE: 0 m"
	distance_label.position = Vector2(92, 10)
	distance_label.add_theme_font_size_override("font_size", 22)
	distance_label.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	hud_panel.add_child(distance_label)

	kills_label = Label.new()
	kills_label.text = "KILLS: 0"
	kills_label.position = Vector2(92, 42)
	kills_label.add_theme_font_size_override("font_size", 20)
	kills_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.12))
	hud_panel.add_child(kills_label)

	speed_label = Label.new()
	speed_label.text = "MACH 1.0"
	speed_label.position = Vector2(280, 44)
	speed_label.add_theme_font_size_override("font_size", 16)
	speed_label.add_theme_color_override("font_color", Color(0.65, 0.78, 1.0))
	hud_panel.add_child(speed_label)

	# Controls Hint Banner (Bottom Left, unobtrusive)
	var controls_hint := Label.new()
	controls_hint.text = "[SPACE / LEFT TOUCH] THRUST UP    |    [J / RIGHT TOUCH] FIRE LASER    |    [ESC] PAUSE"
	controls_hint.position = Vector2(24, 688)
	controls_hint.add_theme_font_size_override("font_size", 14)
	controls_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95, 0.75))
	hud_layer.add_child(controls_hint)

	# Pause Button (Top Right)
	pause_btn = Button.new()
	pause_btn.text = "II PAUSE"
	pause_btn.position = Vector2(1140, 18)
	pause_btn.size = Vector2(118, 46)
	pause_btn.pressed.connect(_toggle_pause)
	hud_layer.add_child(pause_btn)

	# Pause Modal Overlay
	pause_panel = Panel.new()
	pause_panel.visible = false
	pause_panel.position = Vector2(420, 160)
	pause_panel.size = Vector2(440, 390)
	hud_layer.add_child(pause_panel)

	var p_title := Label.new()
	p_title.text = "GAME PAUSED"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_title.position = Vector2(20, 24)
	p_title.size = Vector2(400, 40)
	p_title.add_theme_font_size_override("font_size", 28)
	p_title.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	pause_panel.add_child(p_title)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME RUN"
	resume_btn.position = Vector2(80, 90)
	resume_btn.size = Vector2(280, 48)
	resume_btn.pressed.connect(_toggle_pause)
	pause_panel.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "INSTANT RESTART"
	restart_btn.position = Vector2(80, 155)
	restart_btn.size = Vector2(280, 48)
	restart_btn.pressed.connect(_restart_immediately)
	pause_panel.add_child(restart_btn)

	var audio_btn := Button.new()
	audio_btn.text = "TOGGLE MUTE AUDIO"
	audio_btn.position = Vector2(80, 220)
	audio_btn.size = Vector2(280, 48)
	audio_btn.pressed.connect(func() -> void:
		GameState.music_muted = not GameState.music_muted
		GameState.sfx_muted = GameState.music_muted
		AudioManager.apply_volume_settings()
		GameState.save_local_data()
	)
	pause_panel.add_child(audio_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.position = Vector2(80, 285)
	menu_btn.size = Vector2(280, 48)
	menu_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		GameState.is_running = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	pause_panel.add_child(menu_btn)


func _process(delta: float) -> void:
	if get_tree().paused or not GameState.is_running or is_transitioning_to_gameover:
		return

	var spd: float = DifficultyManager.get_scroll_speed()
	GameState.add_distance(spd * delta * DISTANCE_UNITS_PER_PIXEL)
	DifficultyManager.update_for_distance(GameState.current_distance)

	var mach: float = 1.0 + (spd - DifficultyManager.BASE_SCROLL_SPEED) / 200.0
	if speed_label:
		speed_label.text = "MACH %.1f" % mach

	# Scroll parallax layers
	_scroll_pair(bg_star_a, bg_star_b, spd * 0.18 * delta)
	_scroll_pair(bg_nebula_a, bg_nebula_b, spd * 0.42 * delta)
	if bg_planet:
		bg_planet.position.x -= spd * 0.08 * delta
		if bg_planet.position.x < -200.0:
			bg_planet.position.x = 1480.0

	spawner.tick(delta)


func _scroll_pair(s1: Sprite2D, s2: Sprite2D, dx: float) -> void:
	if not s1 or not s2:
		return
	s1.position.x -= dx
	s2.position.x -= dx
	if s1.position.x <= -1280.0:
		s1.position.x = s2.position.x + 1280.0
	if s2.position.x <= -1280.0:
		s2.position.x = s1.position.x + 1280.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_toggle_pause()
		return

	if get_tree().paused or not player or not player.is_alive:
		return

	# Desktop mouse support: Left click on left half thrusts, right half or right mouse shoots
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.position.x < 640.0:
				player.touch_thrust_active = mb.pressed
				if mb.pressed:
					player.apply_upward_thrust()
			else:
				player.touch_shoot_active = mb.pressed
				if mb.pressed:
					player.try_shoot()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			player.touch_shoot_active = mb.pressed
			if mb.pressed:
				player.try_shoot()

	# Mobile Touchscreen support: simultaneous left-screen thrust & right-screen shoot
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			active_touches[st.index] = st.position
			if st.position.x < 640.0:
				player.apply_upward_thrust()
			else:
				player.try_shoot()
		else:
			active_touches.erase(st.index)
		_refresh_touch_states()

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		active_touches[sd.index] = sd.position
		_refresh_touch_states()


func _refresh_touch_states() -> void:
	var thrust_down := false
	var shoot_down := false
	for pos in active_touches.values():
		if pos.x < 640.0:
			thrust_down = true
		else:
			shoot_down = true
	if player:
		player.touch_thrust_active = thrust_down
		player.touch_shoot_active = shoot_down


func _on_player_laser_fired(spawn_pos: Vector2) -> void:
	var laser := Projectile.new()
	laser.is_player_projectile = true
	laser.speed = 920.0
	laser.direction = Vector2.RIGHT
	laser.damage = 1
	laser.position = spawn_pos
	world_layer.add_child(laser)


func _on_enemy_spawned(enemy: EnemyShip) -> void:
	enemy.enemy_destroyed.connect(_on_enemy_destroyed)
	enemy.enemy_fired_projectile.connect(_on_enemy_fired_projectile)


func _on_enemy_fired_projectile(spawn_pos: Vector2, dir: Vector2) -> void:
	var proj := Projectile.new()
	proj.is_player_projectile = false
	proj.speed = 460.0 + DifficultyManager.difficulty_factor * 180.0
	proj.direction = dir
	proj.damage = 1
	proj.position = spawn_pos
	world_layer.add_child(proj)


func _on_enemy_destroyed(_enemy_type: String, world_pos: Vector2) -> void:
	_spawn_explosion_fx(world_pos)
	_on_cockpit_expression_changed("happy")


func _spawn_explosion_fx(world_pos: Vector2) -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/entities/explosion_effect.gd"))
	fx.position = world_pos
	world_layer.add_child(fx)


func _on_cockpit_expression_changed(expr: String) -> void:
	if not cockpit_portrait:
		return
	var map := {
		"happy": "res://assets/characters/toby_portrait_happy.png",
		"determined": "res://assets/characters/toby_portrait_determined.png",
		"surprised": "res://assets/characters/toby_portrait_surprised.png",
		"gameover": "res://assets/characters/toby_portrait_gameover.png"
	}
	var path: String = map.get(expr, map["happy"])
	cockpit_portrait.texture = load(path)


func _on_score_updated(dist: int, kills: int) -> void:
	if distance_label:
		distance_label.text = "DISTANCE: %d m" % dist
	if kills_label:
		kills_label.text = "KILLS: %d" % kills


func _on_player_died(collision_pos: Vector2) -> void:
	if is_transitioning_to_gameover:
		return
	is_transitioning_to_gameover = true
	_spawn_explosion_fx(collision_pos)
	var payload := GameState.finish_run()
	ApiClient.submit_completed_run(payload)

	# Short collision animation before transitioning to GameOverScreen
	var timer := get_tree().create_timer(0.65)
	timer.timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/GameOverScreen.tscn")
	)


func _toggle_pause() -> void:
	if is_transitioning_to_gameover:
		return
	AudioManager.play_sfx("button", 0.04)
	get_tree().paused = not get_tree().paused
	if pause_panel:
		pause_panel.visible = get_tree().paused


func _restart_immediately() -> void:
	AudioManager.play_sfx("button", 0.04)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")
