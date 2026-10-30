extends Control
## SpaceToby Global Leaderboards Screen (`LeaderboardsScreen.tscn`).
## Features two independent tabs:
## - Ranking A: Most Kills (Most Enemies Destroyed in a single run)
## - Ranking B: Longest Distance (Maximum distance traveled without dying)
## Supports Top 10 display, pagination, and current player rank highlighting.

var current_metric: String = "kills"
var current_page: int = 1
var total_pages: int = 1
const PAGE_LIMIT: int = 10

var tab_kills_btn: Button
var tab_dist_btn: Button
var rows_container: VBoxContainer
var my_rank_label: Label
var page_label: Label
var prev_btn: Button
var next_btn: Button


func _ready() -> void:
	ApiClient.leaderboard_loaded.connect(_on_leaderboard_loaded)
	_build_ui()
	_load_tab("kills", 1)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(140, 44)
	panel.size = Vector2(1000, 632)
	add_child(panel)

	var title := Label.new()
	title.text = "🏆 GLOBAL MERCENARY LEADERBOARDS"
	title.position = Vector2(36, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	panel.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "← BACK TO MENU"
	back_btn.position = Vector2(790, 20)
	back_btn.size = Vector2(175, 42)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	panel.add_child(back_btn)

	# Tabs: Most Kills vs Longest Distance
	tab_kills_btn = Button.new()
	tab_kills_btn.text = "RANKING A: MOST ENEMIES DESTROYED"
	tab_kills_btn.position = Vector2(36, 78)
	tab_kills_btn.size = Vector2(450, 46)
	tab_kills_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		_load_tab("kills", 1)
	)
	panel.add_child(tab_kills_btn)

	tab_dist_btn = Button.new()
	tab_dist_btn.text = "RANKING B: LONGEST DISTANCE"
	tab_dist_btn.position = Vector2(514, 78)
	tab_dist_btn.size = Vector2(450, 46)
	tab_dist_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		_load_tab("distance", 1)
	)
	panel.add_child(tab_dist_btn)

	# Table Column Headers
	var header_box := Panel.new()
	header_box.position = Vector2(36, 138)
	header_box.size = Vector2(928, 38)
	panel.add_child(header_box)

	var h_lbl := Label.new()
	h_lbl.text = "   RANK          PILOT NICKNAME                                          BEST SCORE"
	h_lbl.position = Vector2(16, 7)
	h_lbl.add_theme_font_size_override("font_size", 16)
	h_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.15))
	header_box.add_child(h_lbl)

	# Rows VBoxContainer
	rows_container = VBoxContainer.new()
	rows_container.position = Vector2(36, 184)
	rows_container.size = Vector2(928, 340)
	rows_container.add_theme_constant_override("separation", 6)
	panel.add_child(rows_container)

	# Current Player Rank Highlight Bar
	var my_bar := Panel.new()
	my_bar.position = Vector2(36, 530)
	my_bar.size = Vector2(928, 42)
	panel.add_child(my_bar)

	my_rank_label = Label.new()
	my_rank_label.text = "Your Ranking: Loading..."
	my_rank_label.position = Vector2(20, 9)
	my_rank_label.add_theme_font_size_override("font_size", 17)
	my_rank_label.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	my_bar.add_child(my_rank_label)

	# Pagination Controls
	prev_btn = Button.new()
	prev_btn.text = "◀ PREV PAGE"
	prev_btn.position = Vector2(290, 580)
	prev_btn.size = Vector2(140, 38)
	prev_btn.pressed.connect(func() -> void:
		if current_page > 1:
			AudioManager.play_sfx("button")
			_load_tab(current_metric, current_page - 1)
	)
	panel.add_child(prev_btn)

	page_label = Label.new()
	page_label.text = "Page 1 / 1"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.position = Vector2(440, 586)
	page_label.size = Vector2(120, 30)
	panel.add_child(page_label)

	next_btn = Button.new()
	next_btn.text = "NEXT PAGE ▶"
	next_btn.position = Vector2(570, 580)
	next_btn.size = Vector2(140, 38)
	next_btn.pressed.connect(func() -> void:
		if current_page < total_pages:
			AudioManager.play_sfx("button")
			_load_tab(current_metric, current_page + 1)
	)
	panel.add_child(next_btn)


func _load_tab(metric: String, page: int) -> void:
	current_metric = metric
	current_page = page
	tab_kills_btn.modulate = Color(0.2, 1.0, 0.9) if metric == "kills" else Color(0.75, 0.75, 0.85)
	tab_dist_btn.modulate = Color(0.2, 1.0, 0.9) if metric == "distance" else Color(0.75, 0.75, 0.85)
	ApiClient.fetch_leaderboard(metric, page, PAGE_LIMIT)


func _on_leaderboard_loaded(metric: String, data: Dictionary) -> void:
	if metric != current_metric:
		return

	for child in rows_container.get_children():
		child.queue_free()

	var entries: Array = data.get("entries", [])
	total_pages = maxi(1, int(data.get("totalPages", 1)))
	current_page = int(data.get("page", 1))
	page_label.text = "Page %d / %d" % [current_page, total_pages]
	prev_btn.disabled = (current_page <= 1)
	next_btn.disabled = (current_page >= total_pages)

	var unit := " Kills" if metric == "kills" else " m"
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No ranked runs recorded yet. Be the first pilot on the board!"
		rows_container.add_child(empty_lbl)
	else:
		for e in entries:
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(920, 28)

			var is_me: bool = bool(e.get("isCurrentPlayer", false)) or (
				GameState.is_authenticated and str(e.get("nickname", "")) == GameState.player_nickname
			)
			var col := Color(0.0, 0.96, 0.83) if is_me else Color(0.92, 0.95, 1.0)

			var r_lbl := Label.new()
			r_lbl.custom_minimum_size = Vector2(120, 26)
			r_lbl.text = "   #%d" % int(e.get("rank", 1))
			r_lbl.add_theme_color_override("font_color", col)
			row.add_child(r_lbl)

			var n_lbl := Label.new()
			n_lbl.custom_minimum_size = Vector2(520, 26)
			n_lbl.text = str(e.get("nickname", "Pilot")) + (" (YOU)" if is_me else "")
			n_lbl.add_theme_color_override("font_color", col)
			row.add_child(n_lbl)

			var s_lbl := Label.new()
			s_lbl.custom_minimum_size = Vector2(240, 26)
			s_lbl.text = str(e.get("score", 0)) + unit
			s_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if int(e.get("rank", 99)) <= 3 else col)
			row.add_child(s_lbl)

			rows_container.add_child(row)

	var my_entry = data.get("currentPlayerEntry", null)
	if typeof(my_entry) == TYPE_DICTIONARY and my_entry != null:
		my_rank_label.text = "YOUR GLOBAL POSITION: #%d — %s (%d%s)" % [
			int(my_entry.get("rank", 0)),
			str(my_entry.get("nickname", GameState.player_nickname)),
			int(my_entry.get("score", 0)),
			unit
		]
	elif GameState.is_authenticated:
		var local_best := GameState.best_kills if metric == "kills" else GameState.best_distance
		my_rank_label.text = "PILOT %s — Personal Best: %d%s (Complete a run to rank globally)" % [
			GameState.player_nickname,
			local_best,
			unit
		]
	else:
		my_rank_label.text = "Anonymous runs do not qualify for Global Rankings — Sign in from the Main Menu!"
