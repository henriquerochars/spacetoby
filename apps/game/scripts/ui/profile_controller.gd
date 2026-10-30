extends Control
## SpaceToby Player Profile Screen (`ProfileScreen.tscn`).
## Displays public nickname, nickname editor, total games played,
## personal best kills, personal best distance, and global ranking positions.

var nickname_input: LineEdit
var stats_label: Label
var status_msg: Label


func _ready() -> void:
	ApiClient.stats_loaded.connect(_on_stats_loaded)
	ApiClient.profile_loaded.connect(_on_profile_loaded)
	_build_ui()
	ApiClient.fetch_my_stats()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(260, 70)
	panel.size = Vector2(760, 580)
	add_child(panel)

	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/characters/toby_portrait_happy.png")
	portrait.position = Vector2(44, 36)
	portrait.size = Vector2(140, 140)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(portrait)

	var title := Label.new()
	title.text = "PILOT SERVICE RECORD // PROFILE"
	title.position = Vector2(210, 42)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	panel.add_child(title)

	var nick_lbl := Label.new()
	nick_lbl.text = "Public Leaderboard Nickname:"
	nick_lbl.position = Vector2(210, 88)
	panel.add_child(nick_lbl)

	nickname_input = LineEdit.new()
	nickname_input.text = GameState.player_nickname
	nickname_input.position = Vector2(210, 116)
	nickname_input.size = Vector2(310, 42)
	panel.add_child(nickname_input)

	var save_nick_btn := Button.new()
	save_nick_btn.text = "UPDATE NICKNAME"
	save_nick_btn.position = Vector2(535, 116)
	save_nick_btn.size = Vector2(180, 42)
	save_nick_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		status_msg.text = "Updating nickname..."
		ApiClient.update_nickname(nickname_input.text)
	)
	panel.add_child(save_nick_btn)

	var stats_panel := Panel.new()
	stats_panel.position = Vector2(44, 205)
	stats_panel.size = Vector2(672, 260)
	panel.add_child(stats_panel)

	stats_label = Label.new()
	stats_label.position = Vector2(32, 24)
	stats_label.size = Vector2(610, 215)
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_panel.add_child(stats_label)
	_refresh_stats_text()

	status_msg = Label.new()
	status_msg.position = Vector2(44, 480)
	status_msg.size = Vector2(672, 28)
	status_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_msg.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	panel.add_child(status_msg)

	var back_btn := Button.new()
	back_btn.text = "← BACK TO MAIN MENU"
	back_btn.position = Vector2(250, 515)
	back_btn.size = Vector2(260, 46)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	panel.add_child(back_btn)


func _refresh_stats_text() -> void:
	var k_rank := ("#" + str(GameState.kills_rank)) if GameState.kills_rank > 0 else "Unranked"
	var d_rank := ("#" + str(GameState.distance_rank)) if GameState.distance_rank > 0 else "Unranked"
	stats_label.text = (
		"PILOT CALLSIGN:           %s\n" +
		"ACCOUNT STATUS:           %s\n" +
		"TOTAL GAMES PLAYED:       %d\n\n" +
		"PERSONAL BEST KILLS:      %d Enemies   (Global Rank: %s)\n" +
		"PERSONAL BEST DISTANCE:   %d m         (Global Rank: %s)"
	) % [
		GameState.player_nickname,
		"Authenticated (Supabase)" if GameState.is_authenticated else "Local Guest",
		GameState.total_games_played,
		GameState.best_kills,
		k_rank,
		GameState.best_distance,
		d_rank
	]


func _on_stats_loaded(_stats: Dictionary) -> void:
	nickname_input.text = GameState.player_nickname
	_refresh_stats_text()


func _on_profile_loaded(profile: Dictionary) -> void:
	if profile.has("error"):
		status_msg.text = str(profile["error"])
	else:
		status_msg.text = "Nickname updated to " + GameState.player_nickname + "!"
		_refresh_stats_text()
