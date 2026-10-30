extends Control
## SpaceToby Game Over Screen (`GameOverScreen.tscn`).
## Displays run Distance, Enemies Destroyed, Personal Bests, New Record badge,
## live Score Submission status, and instant Restart / Leaderboards / Main Menu buttons.

var submission_label: Label
var record_badge: Label


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music("menu")
	ApiClient.session_completed.connect(_on_session_completed)
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(280, 68)
	panel.size = Vector2(720, 584)
	add_child(panel)

	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/characters/toby_portrait_gameover.png")
	portrait.position = Vector2(300, 22)
	portrait.size = Vector2(120, 120)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(portrait)

	var title := Label.new()
	title.text = "SHIP DOWN // RUN OVER!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, 148)
	title.size = Vector2(640, 42)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.38, 0.25))
	panel.add_child(title)

	# New Personal Record Indicator
	record_badge = Label.new()
	var is_new_record := GameState.last_run_new_best_distance or GameState.last_run_new_best_kills
	if is_new_record:
		var parts: Array[String] = []
		if GameState.last_run_new_best_distance:
			parts.append("NEW DISTANCE RECORD!")
		if GameState.last_run_new_best_kills:
			parts.append("NEW KILLS RECORD!")
		record_badge.text = "★ " + " & ".join(parts) + " ★"
	else:
		record_badge.text = "Toby swore at Baron Vex and readied the backup thruster!"
	record_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_badge.position = Vector2(40, 192)
	record_badge.size = Vector2(640, 32)
	record_badge.add_theme_font_size_override("font_size", 18)
	record_badge.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.1) if is_new_record else Color(0.75, 0.85, 1.0)
	)
	panel.add_child(record_badge)

	# Run Stats Grid
	var stats_box := Panel.new()
	stats_box.position = Vector2(70, 235)
	stats_box.size = Vector2(580, 150)
	panel.add_child(stats_box)

	var dist_lbl := Label.new()
	dist_lbl.text = "DISTANCE TRAVELED:   %d m\nPERSONAL BEST DIST:  %d m" % [
		GameState.last_run_distance,
		GameState.best_distance
	]
	dist_lbl.position = Vector2(28, 26)
	dist_lbl.add_theme_font_size_override("font_size", 20)
	dist_lbl.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	stats_box.add_child(dist_lbl)

	var kills_lbl := Label.new()
	kills_lbl.text = "ENEMIES DESTROYED:   %d\nPERSONAL BEST KILLS: %d" % [
		GameState.last_run_kills,
		GameState.best_kills
	]
	kills_lbl.position = Vector2(320, 26)
	kills_lbl.add_theme_font_size_override("font_size", 20)
	kills_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.15))
	stats_box.add_child(kills_lbl)

	submission_label = Label.new()
	submission_label.text = GameState.last_submission_message if not GameState.last_submission_message.is_empty() else "Score recorded."
	submission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submission_label.position = Vector2(20, 108)
	submission_label.size = Vector2(540, 30)
	submission_label.add_theme_font_size_override("font_size", 15)
	submission_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	stats_box.add_child(submission_label)

	# Action Buttons (Fast Restart prioritized)
	var restart_btn := Button.new()
	restart_btn.text = "↻  INSTANT RESTART [SPACE]"
	restart_btn.position = Vector2(70, 410)
	restart_btn.size = Vector2(580, 58)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(_restart_game)
	panel.add_child(restart_btn)

	var lb_btn := Button.new()
	lb_btn.text = "🏆  LEADERBOARDS"
	lb_btn.position = Vector2(70, 484)
	lb_btn.size = Vector2(280, 50)
	lb_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/LeaderboardsScreen.tscn")
	)
	panel.add_child(lb_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🏠  MAIN MENU"
	menu_btn.position = Vector2(370, 484)
	menu_btn.size = Vector2(280, 50)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	panel.add_child(menu_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("thrust"):
		_restart_game()


func _restart_game() -> void:
	AudioManager.play_sfx("button")
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")


func _on_session_completed(_success: bool, _data: Dictionary) -> void:
	if submission_label:
		submission_label.text = GameState.last_submission_message
