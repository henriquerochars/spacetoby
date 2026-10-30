extends Control
## SpaceToby Main Menu Screen (`MainMenu.tscn`).
## Displays SpaceToby branding, animated cosmic background, Toby piloting his spaceship,
## Play button (triggers opening heist cutscene on first run), Watch Cutscene button,
## Leaderboards, Profile, Login/Logout controls, and Settings modal.

var hero_ship: Sprite2D
var bg_nebula: TextureRect
var auth_status_label: Label
var auth_btn: Button
var settings_panel: Panel
var anim_time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music("menu")
	_build_ui()
	if GameState.is_authenticated:
		ApiClient.fetch_my_stats()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Deep Space Background
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	bg_nebula = TextureRect.new()
	bg_nebula.texture = load("res://assets/backgrounds/nebula_layer.png")
	bg_nebula.stretch_mode = TextureRect.STRETCH_SCALE
	bg_nebula.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_nebula)

	var planet := TextureRect.new()
	planet.texture = load("res://assets/backgrounds/bg_planet.png")
	planet.position = Vector2(930, 80)
	planet.size = Vector2(220, 220)
	planet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(planet)

	# SpaceToby PixelLab Logo
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/spacetoby_logo.png")
	logo.position = Vector2(100, 48)
	logo.size = Vector2(460, 138)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "2D SPACE MERCENARY ARCADE // FLAPPY COMBAT EDITION"
	subtitle.position = Vector2(108, 192)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	add_child(subtitle)

	# Right Side Showcase: Toby Inside His Spaceship + Character Card
	var showcase_panel := Panel.new()
	showcase_panel.position = Vector2(640, 230)
	showcase_panel.size = Vector2(540, 390)
	add_child(showcase_panel)

	hero_ship = Sprite2D.new()
	hero_ship.texture = load("res://assets/spaceships/player_ship_thrust.png")
	hero_ship.position = Vector2(270, 145)
	hero_ship.scale = Vector2(2.6, 2.6)
	showcase_panel.add_child(hero_ship)

	var toby_badge := TextureRect.new()
	toby_badge.texture = load("res://assets/characters/toby_portrait_happy.png")
	toby_badge.position = Vector2(24, 245)
	toby_badge.size = Vector2(120, 120)
	toby_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	showcase_panel.add_child(toby_badge)

	var lore_lbl := Label.new()
	lore_lbl.text = "PILOT: TOBY (SPACE MERCENARY)\n\"Acabei de roubar o Cristal Quântico daquele sovina do Barão Vex! Prepara os lasers que a frota dele tá na nossa cola!\""
	lore_lbl.position = Vector2(160, 252)
	lore_lbl.size = Vector2(355, 115)
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.add_theme_font_size_override("font_size", 15)
	lore_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	showcase_panel.add_child(lore_lbl)

	# Top Right Auth Status Bar
	auth_status_label = Label.new()
	auth_status_label.position = Vector2(640, 34)
	auth_status_label.size = Vector2(380, 32)
	auth_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	auth_status_label.add_theme_font_size_override("font_size", 16)
	add_child(auth_status_label)

	auth_btn = Button.new()
	auth_btn.position = Vector2(1040, 26)
	auth_btn.size = Vector2(140, 42)
	auth_btn.pressed.connect(_on_auth_button_pressed)
	add_child(auth_btn)
	_refresh_auth_header()

	# Left Side Navigation Buttons
	var btn_x := 108.0
	var btn_w := 440.0

	var play_btn := Button.new()
	play_btn.text = "▶  PLAY SPACETOBY"
	play_btn.position = Vector2(btn_x, 245)
	play_btn.size = Vector2(btn_w, 60)
	play_btn.add_theme_font_size_override("font_size", 22)
	play_btn.pressed.connect(_on_play_pressed)
	add_child(play_btn)

	var cutscene_btn := Button.new()
	cutscene_btn.text = "🎬  WATCH INTRO CUTSCENE (THE HEIST)"
	cutscene_btn.position = Vector2(btn_x, 320)
	cutscene_btn.size = Vector2(btn_w, 50)
	cutscene_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/Cutscene.tscn")
	)
	add_child(cutscene_btn)

	var lb_btn := Button.new()
	lb_btn.text = "🏆  GLOBAL LEADERBOARDS"
	lb_btn.position = Vector2(btn_x, 385)
	lb_btn.size = Vector2(btn_w, 50)
	lb_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/LeaderboardsScreen.tscn")
	)
	add_child(lb_btn)

	var profile_btn := Button.new()
	profile_btn.text = "🐾  PILOT PROFILE & RECORDS"
	profile_btn.position = Vector2(btn_x, 450)
	profile_btn.size = Vector2(btn_w, 50)
	profile_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/ProfileScreen.tscn")
	)
	add_child(profile_btn)

	var settings_btn := Button.new()
	settings_btn.text = "⚙  AUDIO & CONTROLS SETTINGS"
	settings_btn.position = Vector2(btn_x, 515)
	settings_btn.size = Vector2(btn_w, 50)
	settings_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		settings_panel.visible = true
	)
	add_child(settings_btn)

	# Best Scores Footer
	var records_lbl := Label.new()
	records_lbl.text = "PERSONAL BESTS — DISTANCE: %d m   |   MOST KILLS: %d" % [
		GameState.best_distance,
		GameState.best_kills
	]
	records_lbl.position = Vector2(btn_x, 590)
	records_lbl.add_theme_font_size_override("font_size", 17)
	records_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.15))
	add_child(records_lbl)

	_build_settings_modal()


func _build_settings_modal() -> void:
	settings_panel = Panel.new()
	settings_panel.visible = false
	settings_panel.position = Vector2(360, 150)
	settings_panel.size = Vector2(560, 420)
	add_child(settings_panel)

	var title := Label.new()
	title.text = "AUDIO & CONTROLS SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 24)
	title.size = Vector2(520, 36)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	settings_panel.add_child(title)

	var music_lbl := Label.new()
	music_lbl.text = "Music Volume (dB)"
	music_lbl.position = Vector2(50, 85)
	settings_panel.add_child(music_lbl)

	var music_slider := HSlider.new()
	music_slider.min_value = -36.0
	music_slider.max_value = 0.0
	music_slider.step = 1.0
	music_slider.value = GameState.music_volume_db
	music_slider.position = Vector2(50, 115)
	music_slider.size = Vector2(460, 28)
	music_slider.value_changed.connect(func(val: float) -> void:
		GameState.music_volume_db = val
		GameState.music_muted = (val <= -35.0)
		AudioManager.apply_volume_settings()
		GameState.save_local_data()
	)
	settings_panel.add_child(music_slider)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "SFX Volume (dB)"
	sfx_lbl.position = Vector2(50, 165)
	settings_panel.add_child(sfx_lbl)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -36.0
	sfx_slider.max_value = 6.0
	sfx_slider.step = 1.0
	sfx_slider.value = GameState.sfx_volume_db
	sfx_slider.position = Vector2(50, 195)
	sfx_slider.size = Vector2(460, 28)
	sfx_slider.value_changed.connect(func(val: float) -> void:
		GameState.sfx_volume_db = val
		GameState.sfx_muted = (val <= -35.0)
		GameState.save_local_data()
		AudioManager.play_sfx("laser")
	)
	settings_panel.add_child(sfx_slider)

	var controls_info := Label.new()
	controls_info.text = "CONTROLS:\n• Desktop: SPACE / W / Left Click = Thrust Up | J / Z / Right Click = Shoot Laser | ESC = Pause\n• Mobile / Touch: Left half of screen = Thrust Up | Right half of screen = Shoot Laser"
	controls_info.position = Vector2(50, 245)
	controls_info.size = Vector2(460, 95)
	controls_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_info.add_theme_font_size_override("font_size", 14)
	settings_panel.add_child(controls_info)

	var close_btn := Button.new()
	close_btn.text = "SAVE & CLOSE"
	close_btn.position = Vector2(180, 350)
	close_btn.size = Vector2(200, 46)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		settings_panel.visible = false
	)
	settings_panel.add_child(close_btn)


func _refresh_auth_header() -> void:
	if GameState.is_authenticated:
		auth_status_label.text = "ONLINE PILOT: " + GameState.player_nickname
		auth_status_label.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
		auth_btn.text = "LOGOUT"
	else:
		auth_status_label.text = "GUEST MODE (Unranked)"
		auth_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
		auth_btn.text = "LOGIN / SIGN UP"


func _on_auth_button_pressed() -> void:
	AudioManager.play_sfx("button")
	if GameState.is_authenticated:
		GameState.clear_auth()
		_refresh_auth_header()
	else:
		get_tree().change_scene_to_file("res://scenes/AuthScreen.tscn")


func _on_play_pressed() -> void:
	AudioManager.play_sfx("button")
	if not GameState.has_seen_intro_cutscene:
		get_tree().change_scene_to_file("res://scenes/Cutscene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")


func _process(delta: float) -> void:
	anim_time += delta
	if hero_ship:
		hero_ship.position.y = 145.0 + sin(anim_time * 3.2) * 12.0
		hero_ship.rotation = sin(anim_time * 2.1) * 0.06
