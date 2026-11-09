extends Node
## REST API & local account client (`ApiClient`) for SpaceToby.
## Communicates with the NestJS backend (`/api/v1/*`) for authentication,
## player profiles, server-issued game sessions, score submissions, and global leaderboards.
## Gracefully falls back to local/offline persistence when the backend is unreachable.

signal auth_completed(success: bool, message: String)
signal profile_loaded(profile: Dictionary)
signal stats_loaded(stats: Dictionary)
signal session_started(session_id: String)
signal session_completed(success: bool, data: Dictionary)
signal leaderboard_loaded(metric: String, data: Dictionary)

var api_base_url: String = "http://localhost:3000"
var _session_context: Dictionary = {}


func _ready() -> void:
	var env_url := OS.get_environment("SPACETOBY_API_URL")
	if not env_url.is_empty():
		api_base_url = env_url.rstrip("/")


func _build_headers(require_auth: bool = true) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if require_auth and not GameState.access_token.is_empty():
		headers.append("Authorization: Bearer " + GameState.access_token)
	return headers


func _request_json(
	endpoint: String,
	method: HTTPClient.Method,
	body_dict: Variant = null,
	callback: Callable = Callable()
) -> void:
	var http := HTTPRequest.new()
	http.timeout = 6.0
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var parsed: Dictionary = {}
		if body.size() > 0:
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				parsed = json.data
		var ok: bool = (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
		if callback.is_valid():
			callback.call(ok, response_code, parsed)
	)

	var url := api_base_url + endpoint
	var payload_str := "" if body_dict == null else JSON.stringify(body_dict)
	var err := http.request(url, _build_headers(true), method, payload_str)
	if err != OK:
		http.queue_free()
		if callback.is_valid():
			callback.call(false, 0, {"error": "Request init failed"})


# =============================================================================
# Authentication & Player Profile
# =============================================================================

func sign_up(email: String, password: String, nickname: String) -> void:
	var payload := {
		"email": email.strip_edges(),
		"password": password,
		"nickname": nickname.strip_edges()
	}
	_request_json("/api/v1/auth/signup", HTTPClient.METHOD_POST, payload, func(ok: bool, _code: int, res: Dictionary) -> void:
		if ok and res.has("data"):
			var data: Dictionary = res["data"]
			GameState.set_authenticated_user(str(data.get("accessToken", "")), data.get("user", {}))
			auth_completed.emit(true, "Pilot account registered! Welcome aboard, " + GameState.player_nickname + "!")
		else:
			if _code == 0:
				auth_completed.emit(false, "Account not created: service unavailable. You can still play as a guest.")
			else:
				var err_msg := _extract_error(res, "Registration failed")
				auth_completed.emit(false, err_msg)
	)


func login(email: String, password: String) -> void:
	var payload := {
		"email": email.strip_edges(),
		"password": password
	}
	_request_json("/api/v1/auth/login", HTTPClient.METHOD_POST, payload, func(ok: bool, _code: int, res: Dictionary) -> void:
		if ok and res.has("data"):
			var data: Dictionary = res["data"]
			GameState.set_authenticated_user(str(data.get("accessToken", "")), data.get("user", {}))
			fetch_my_stats()
			auth_completed.emit(true, "Welcome back, Commander " + GameState.player_nickname + "!")
		else:
			if _code == 0:
				auth_completed.emit(false, "Cannot sign in: service unavailable. You can still play as a guest.")
			else:
				auth_completed.emit(false, _extract_error(res, "Login failed"))
	)


func recover_password(email: String) -> void:
	_request_json("/api/v1/auth/recover", HTTPClient.METHOD_POST, {"email": email.strip_edges()}, func(ok: bool, _code: int, res: Dictionary) -> void:
		if ok:
			auth_completed.emit(true, "Recovery request received for " + email)
		elif _code == 0:
			auth_completed.emit(false, "Password recovery is unavailable while the game service is offline.")
		else:
			auth_completed.emit(false, _extract_error(res, "Password recovery is not configured. Contact the service operator to reset this account."))
	)


func update_nickname(new_nickname: String) -> void:
	var nickname := new_nickname.strip_edges()
	var pattern := RegEx.create_from_string("^[a-zA-Z0-9_-]{3,24}$")
	if pattern.search(nickname) == null:
		profile_loaded.emit({"error": "Use 3–24 letters, numbers, underscores or hyphens."})
		return
	if not GameState.is_authenticated:
		GameState.player_nickname = nickname
		GameState.save_local_data()
		profile_loaded.emit({"nickname": nickname})
		return
	var token := GameState.access_token
	_request_json("/api/v1/players/me", HTTPClient.METHOD_PATCH, {"nickname": new_nickname.strip_edges()}, func(ok: bool, _code: int, res: Dictionary) -> void:
		if token != GameState.access_token:
			return
		if ok and res.has("data"):
			var data: Dictionary = res["data"]
			GameState.player_nickname = str(data.get("nickname", new_nickname))
			GameState.save_local_data()
			profile_loaded.emit(data)
		elif _code == 0:
			profile_loaded.emit({"error": "Nickname not updated: account service unavailable. Please try again when connected."})
		else:
			profile_loaded.emit({"error": _extract_error(res, "Could not update nickname")})
	)


func fetch_my_stats() -> void:
	if not GameState.is_authenticated:
		return
	var token := GameState.access_token
	_request_json("/api/v1/players/me/stats", HTTPClient.METHOD_GET, null, func(ok: bool, _code: int, res: Dictionary) -> void:
		if token != GameState.access_token:
			return
		if ok and res.has("data"):
			var d: Dictionary = res["data"]
			GameState.best_kills = maxi(GameState.best_kills, int(d.get("bestKills", 0)))
			GameState.best_distance = maxi(GameState.best_distance, int(d.get("bestDistance", 0)))
			GameState.total_games_played = maxi(GameState.total_games_played, int(d.get("totalGamesPlayed", 0)))
			GameState.kills_rank = int(d.get("killsRank", 0)) if d.get("killsRank") != null else 0
			GameState.distance_rank = int(d.get("distanceRank", 0)) if d.get("distanceRank") != null else 0
			GameState.player_nickname = str(d.get("nickname", GameState.player_nickname))
			GameState.save_local_data()
			stats_loaded.emit(d)
		else:
			stats_loaded.emit({
				"nickname": GameState.player_nickname,
				"totalGamesPlayed": GameState.total_games_played,
				"bestKills": GameState.best_kills,
				"bestDistance": GameState.best_distance,
				"killsRank": GameState.kills_rank if GameState.kills_rank > 0 else null,
				"distanceRank": GameState.distance_rank if GameState.distance_rank > 0 else null
			})
	)


# =============================================================================
# Game Sessions & Score Submission
# =============================================================================

func start_server_game_session() -> void:
	GameState.active_session_id = ""
	_session_context = {}
	if not GameState.is_authenticated:
		return
	# Capture this run independently; the player may restart before HTTP completes.
	var context := {
		"run_id": GameState.run_id,
		"token": GameState.access_token,
		"pending": true,
		"payload": {}
	}
	_session_context = context
	_request_json("/api/v1/game-sessions", HTTPClient.METHOD_POST, {}, func(ok: bool, _code: int, res: Dictionary) -> void:
		context["pending"] = false
		if context["token"] != GameState.access_token:
			return
		var is_current: bool = context["run_id"] == GameState.run_id
		if ok and res.has("data"):
			var sid := str(res["data"].get("sessionId", ""))
			if not sid.is_empty():
				if is_current:
					GameState.active_session_id = sid
					session_started.emit(sid)
				if not context["payload"].is_empty():
					_complete_session_request(sid, context["payload"], context["run_id"], context["token"])
				return
		if is_current and not context["payload"].is_empty():
			_mark_run_local("Saved locally: no server session was available for this run.")
	)


func submit_completed_run(run_payload: Dictionary) -> void:
	if run_payload.is_empty() or GameState.last_submission_status in ["SUBMITTING", "VALID"]:
		return
	if not GameState.is_authenticated:
		_mark_run_local("Anonymous run — Sign in to qualify for Global Leaderboards!")
		return

	GameState.last_submission_status = "SUBMITTING"
	GameState.last_submission_message = "Validating & submitting score to Space Command..."

	if GameState.active_session_id.is_empty():
		if _session_context.get("run_id", -1) == GameState.run_id and _session_context.get("pending", false):
			_session_context["payload"] = run_payload.duplicate(true)
		else:
			_mark_run_local("Saved locally: no server session was available for this run.")
	else:
		_complete_session_request(GameState.active_session_id, run_payload, GameState.run_id, GameState.access_token)


func _mark_run_local(message: String) -> void:
	GameState.last_submission_status = "OFFLINE"
	GameState.last_submission_message = message
	session_completed.emit(false, {"reason": message})


func _complete_session_request(session_id: String, run_payload: Dictionary, run_id: int, token: String) -> void:
	var endpoint := "/api/v1/game-sessions/" + session_id + "/complete"
	if run_id == GameState.run_id and GameState.active_session_id == session_id:
		GameState.active_session_id = ""
	_request_json(endpoint, HTTPClient.METHOD_POST, run_payload, func(ok: bool, _code: int, res: Dictionary) -> void:
		if run_id != GameState.run_id or token != GameState.access_token:
			return
		if ok and res.has("data"):
			var d: Dictionary = res["data"]
			GameState.last_submission_status = "VALID"
			GameState.kills_rank = int(d.get("killsRank", 0)) if d.get("killsRank") != null else 0
			GameState.distance_rank = int(d.get("distanceRank", 0)) if d.get("distanceRank") != null else 0
			GameState.best_distance = maxi(GameState.best_distance, int(d.get("personalBestDistance", 0)))
			GameState.best_kills = maxi(GameState.best_kills, int(d.get("personalBestKills", 0)))
			GameState.save_local_data()
			GameState.last_submission_message = "Score verified! Global Ranks — Kills: #%s | Distance: #%s" % [
				str(GameState.kills_rank) if GameState.kills_rank > 0 else "-",
				str(GameState.distance_rank) if GameState.distance_rank > 0 else "-"
			]
			session_completed.emit(true, d)
		else:
			if _code == 0:
				GameState.last_submission_status = "OFFLINE"
				GameState.last_submission_message = "Saved to local records (API offline)"
			else:
				GameState.last_submission_status = "ERROR"
				GameState.last_submission_message = _extract_error(res, "Score validation failed")
			session_completed.emit(false, res)
	)


# =============================================================================
# Global Leaderboards
# =============================================================================

func fetch_leaderboard(metric: String = "kills", page: int = 1, limit: int = 10) -> void:
	var safe_metric := "distance" if metric == "distance" else "kills"
	var endpoint := "/api/v1/leaderboards/%s?page=%d&limit=%d" % [safe_metric, page, limit]
	_request_json(endpoint, HTTPClient.METHOD_GET, null, func(ok: bool, _code: int, res: Dictionary) -> void:
		if ok and res.has("data"):
			leaderboard_loaded.emit(safe_metric, res["data"])
		else:
			leaderboard_loaded.emit(safe_metric, {
				"metric": safe_metric,
				"entries": [],
				"page": page,
				"limit": limit,
				"totalPlayers": 0,
				"totalPages": 1,
				"offlineFallback": true
			})
	)


func _extract_error(res: Dictionary, default_msg: String) -> String:
	if res.has("error") and typeof(res["error"]) == TYPE_DICTIONARY:
		var msg = res["error"].get("message", default_msg)
		if typeof(msg) == TYPE_ARRAY and msg.size() > 0:
			return str(msg[0])
		return str(msg)
	return default_msg
