extends Node
## Central GameState Autoload Singleton for SpaceToby.
## Manages run metrics, personal bests, cutscene state, and settings persistence.

signal score_updated(distance: int, kills: int)
signal run_started()
signal run_ended(distance: int, kills: int, is_new_best_dist: bool, is_new_best_kills: bool)
signal auth_state_changed(is_authenticated: bool, nickname: String)

const SAVE_PATH := "user://spacetoby_save.cfg"

# Current Run State
var is_running: bool = false
var current_distance: float = 0.0
var current_kills: int = 0
var run_start_ticks_ms: int = 0
var active_session_id: String = ""
var checkpoint_events: Array = []

# Persistent Player Records
var best_distance: int = 0
var best_kills: int = 0
var total_games_played: int = 0
var kills_rank: int = 0
var distance_rank: int = 0
var has_seen_intro_cutscene: bool = false

# Auth & Profile State
var is_authenticated: bool = false
var access_token: String = ""
var player_id: String = ""
var player_email: String = ""
var player_nickname: String = "TobyPilot"

# Audio Settings
var music_volume_db: float = -6.0
var sfx_volume_db: float = -2.0
var music_muted: bool = false
var sfx_muted: bool = false

# Last Run Summary (for Game Over Screen)
var last_run_distance: int = 0
var last_run_kills: int = 0
var last_run_duration_ms: int = 0
var last_run_new_best_distance: bool = false
var last_run_new_best_kills: bool = false
var last_submission_status: String = "IDLE" # IDLE, SUBMITTING, VALID, OFFLINE, ERROR
var last_submission_message: String = ""


func _ready() -> void:
	load_local_data()


func start_new_run() -> void:
	is_running = true
	current_distance = 0.0
	current_kills = 0
	run_start_ticks_ms = Time.get_ticks_msec()
	checkpoint_events.clear()
	last_submission_status = "IDLE"
	last_submission_message = ""
	if DifficultyManager:
		DifficultyManager.reset()
	run_started.emit()
	score_updated.emit(0, 0)


func add_distance(delta_distance: float) -> void:
	if not is_running or delta_distance <= 0.0:
		return
	var prev_int := int(current_distance)
	current_distance += delta_distance
	var curr_int := int(current_distance)
	if curr_int != prev_int:
		score_updated.emit(curr_int, current_kills)
		if curr_int > 0 and curr_int % 500 == 0 and checkpoint_events.size() < 200:
			checkpoint_events.append({
				"type": "DISTANCE_CHECKPOINT",
				"timestampOffsetMs": Time.get_ticks_msec() - run_start_ticks_ms,
				"value": curr_int
			})


func register_enemy_kill(points: int = 1) -> void:
	if not is_running:
		return
	current_kills += maxi(1, points)
	var curr_dist: int = int(current_distance)
	score_updated.emit(curr_dist, current_kills)
	if checkpoint_events.size() < 200:
		checkpoint_events.append({
			"type": "ENEMY_DESTROYED",
			"timestampOffsetMs": Time.get_ticks_msec() - run_start_ticks_ms,
			"value": current_kills
		})


func finish_run() -> Dictionary:
	if not is_running:
		return {}
	is_running = false
	var final_dist: int = int(current_distance)
	var final_kills: int = current_kills
	var duration_ms: int = maxi(100, Time.get_ticks_msec() - run_start_ticks_ms)

	last_run_distance = final_dist
	last_run_kills = final_kills
	last_run_duration_ms = duration_ms
	total_games_played += 1

	last_run_new_best_distance = final_dist > best_distance and final_dist > 0
	last_run_new_best_kills = final_kills > best_kills and final_kills > 0

	if final_dist > best_distance:
		best_distance = final_dist
	if final_kills > best_kills:
		best_kills = final_kills

	if checkpoint_events.size() < 250:
		checkpoint_events.append({
			"type": "SESSION_ENDED",
			"timestampOffsetMs": duration_ms,
			"value": final_dist
		})

	save_local_data()
	run_ended.emit(final_dist, final_kills, last_run_new_best_distance, last_run_new_best_kills)

	return {
		"distance": final_dist,
		"enemiesKilled": final_kills,
		"clientDurationMs": duration_ms,
		"events": checkpoint_events.duplicate()
	}


func set_authenticated_user(token: String, user_data: Dictionary) -> void:
	access_token = token
	is_authenticated = not token.is_empty()
	player_id = str(user_data.get("playerId", user_data.get("id", "")))
	player_email = str(user_data.get("email", ""))
	player_nickname = str(user_data.get("nickname", "TobyPilot"))
	save_local_data()
	auth_state_changed.emit(is_authenticated, player_nickname)


func clear_auth() -> void:
	access_token = ""
	is_authenticated = false
	active_session_id = ""
	save_local_data()
	auth_state_changed.emit(false, player_nickname)


func save_local_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_distance", best_distance)
	cfg.set_value("records", "best_kills", best_kills)
	cfg.set_value("records", "total_games_played", total_games_played)
	cfg.set_value("records", "kills_rank", kills_rank)
	cfg.set_value("records", "distance_rank", distance_rank)
	cfg.set_value("story", "has_seen_intro_cutscene", has_seen_intro_cutscene)
	cfg.set_value("auth", "access_token", access_token)
	cfg.set_value("auth", "player_id", player_id)
	cfg.set_value("auth", "player_email", player_email)
	cfg.set_value("auth", "player_nickname", player_nickname)
	cfg.set_value("audio", "music_volume_db", music_volume_db)
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("audio", "sfx_muted", sfx_muted)
	cfg.save(SAVE_PATH)


func load_local_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_distance = int(cfg.get_value("records", "best_distance", 0))
	best_kills = int(cfg.get_value("records", "best_kills", 0))
	total_games_played = int(cfg.get_value("records", "total_games_played", 0))
	kills_rank = int(cfg.get_value("records", "kills_rank", 0))
	distance_rank = int(cfg.get_value("records", "distance_rank", 0))
	has_seen_intro_cutscene = bool(cfg.get_value("story", "has_seen_intro_cutscene", false))
	access_token = str(cfg.get_value("auth", "access_token", ""))
	player_id = str(cfg.get_value("auth", "player_id", ""))
	player_email = str(cfg.get_value("auth", "player_email", ""))
	player_nickname = str(cfg.get_value("auth", "player_nickname", "TobyPilot"))
	is_authenticated = not access_token.is_empty()
	music_volume_db = float(cfg.get_value("audio", "music_volume_db", -6.0))
	sfx_volume_db = float(cfg.get_value("audio", "sfx_volume_db", -2.0))
	music_muted = bool(cfg.get_value("audio", "music_muted", false))
	sfx_muted = bool(cfg.get_value("audio", "sfx_muted", false))
