extends Node
## Optional live client/API verification against an isolated QA service.
## Enable with SPACETOBY_TEST_API_URL; creates a unique disposable pilot account.

var responses: Dictionary = {}
var check: Callable


func run(assertion: Callable) -> void:
	check = assertion
	print("\n-> Testing Live Godot -> API -> PostgreSQL Workflow...")
	ApiClient.api_base_url = OS.get_environment("SPACETOBY_TEST_API_URL").rstrip("/")
	GameState.clear_auth()
	var suffix := "%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()]
	var email := "godot_qa_%s@example.test" % suffix
	var nickname := "QA_%s" % suffix
	ApiClient.auth_completed.connect(_on_auth)
	ApiClient.session_started.connect(_on_session_started)
	ApiClient.session_completed.connect(_on_session_completed)
	ApiClient.leaderboard_loaded.connect(_on_leaderboard)
	ApiClient.profile_loaded.connect(_on_data)
	ApiClient.stats_loaded.connect(_on_stats)
	ApiClient.sign_up(email, "Disposable-QA-Password-123!", nickname)
	if not await _expect_response("Live signup authenticates a new pilot", "auth"):
		return
	check.call(GameState.is_authenticated and GameState.player_nickname == nickname, "Godot stores the real account returned by the API")
	responses.clear()
	GameState.start_new_run()
	ApiClient.start_server_game_session()
	if not await _expect_response("Live gameplay receives a server-issued session", "session"):
		return
	GameState.add_distance(20)
	GameState.register_enemy_kill()
	var payload := GameState.finish_run()
	responses.clear()
	ApiClient.submit_completed_run(payload)
	if not await _expect_response("Live run submission is accepted", "submission"):
		return
	check.call(GameState.last_submission_status == "VALID" and GameState.kills_rank > 0, "Verified score updates the real global rank")
	responses.clear()
	ApiClient.fetch_leaderboard("kills")
	if not await _expect_response("Live kills leaderboard loads", "leaderboard"):
		return
	var entry: Dictionary = responses["leaderboard"].get("currentPlayerEntry", {})
	check.call(entry.get("nickname") == nickname and int(entry.get("score", 0)) == 1, "Leaderboard includes the authenticated player's verified kill count")
	responses.clear()
	ApiClient.update_nickname(nickname + "X")
	if not await _expect_response("Live nickname update succeeds", "profile"):
		return
	GameState.clear_auth()
	responses.clear()
	ApiClient.login(email, "Disposable-QA-Password-123!")
	if not await _expect_response("Live login succeeds after logout", "auth"):
		return
	check.call(GameState.player_nickname == nickname + "X", "Nickname change persists across real account login")
	await _expect_response("Live profile stats load after login", "stats")
	GameState.clear_auth()


func _expect_response(label: String, kind: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while not responses.has(kind) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	var success: bool = responses.has(kind) and not responses[kind].has("error")
	check.call(success, label)
	return success


func _on_auth(success: bool, message: String) -> void:
	responses["auth"] = {} if success else {"error": message}


func _on_session_started(session_id: String) -> void:
	responses["session"] = {"sessionId": session_id}


func _on_session_completed(success: bool, data: Dictionary) -> void:
	responses["submission"] = data if success else {"error": "Submission failed"}


func _on_leaderboard(_metric: String, data: Dictionary) -> void:
	responses["leaderboard"] = data


func _on_data(data: Dictionary) -> void:
	responses["profile"] = data


func _on_stats(data: Dictionary) -> void:
	responses["stats"] = data
