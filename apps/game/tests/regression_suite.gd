extends Node
## Regression scenarios exercise live scene controls and delayed network responses.

class MockApiClient extends "res://scripts/autoload/api_client.gd":
	var requests: Array[Dictionary] = []

	func _request_json(endpoint: String, method: HTTPClient.Method, body_dict: Variant = null, callback: Callable = Callable()) -> void:
		requests.append({"endpoint": endpoint, "method": method, "body": body_dict, "callback": callback})

	func reply(index: int, ok: bool, code: int, data: Dictionary) -> void:
		var callback: Callable = requests[index]["callback"]
		callback.call(ok, code, data)


var check: Callable


func run(assertion: Callable) -> void:
	check = assertion
	print("\n-> Testing Input, Combat, Offline Features & Delayed API Responses...")
	_test_gameplay_controls()
	_test_projectile_single_impact()
	_test_offline_account_and_ranking()
	_test_profile_response_isolation()
	_test_session_responses()
	_test_leaderboard_page_order()
	_test_checkpoint_crossings()
	await _test_physics_collisions()
	await _test_screen_flow()
	_test_local_persistence()


func _mouse(button: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	return event


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	return event


func _test_gameplay_controls() -> void:
	GameState.clear_auth()
	var game = load("res://scenes/Gameplay.tscn").instantiate()
	add_child(game)
	game._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true, Vector2(200, 300)))
	check.call(game.player.touch_thrust_active, "Left mouse starts thrust")
	game._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false, Vector2(900, 300)))
	check.call(not game.player.touch_thrust_active, "Mouse release across screen halves stops thrust")
	game._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true, Vector2(900, 300)))
	check.call(game.player.touch_thrust_active and not game.player.touch_shoot_active, "Desktop left click thrusts on either side, as documented")
	game._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false, Vector2(900, 300)))
	game._unhandled_input(_touch(0, true, Vector2(200, 300)))
	game._unhandled_input(_touch(1, true, Vector2(900, 300)))
	check.call(game.player.touch_thrust_active and game.player.touch_shoot_active, "Two touches can thrust and shoot simultaneously")
	var distance_before: float = GameState.current_distance
	game._toggle_pause()
	game._process(1.0)
	check.call(GameState.current_distance == distance_before and not game.player.can_process(), "Pause freezes both score and player physics")
	game._unhandled_input(_touch(0, false, Vector2(200, 300)))
	game._unhandled_input(_touch(1, false, Vector2(900, 300)))
	game._toggle_pause()
	check.call(not game.player.touch_thrust_active and not game.player.touch_shoot_active, "Releasing touches while paused does not leave controls stuck")
	game.free()
	GameState.is_running = false


func _test_projectile_single_impact() -> void:
	GameState.start_new_run()
	var first := EnemyShip.new()
	var second := EnemyShip.new()
	add_child(first)
	add_child(second)
	var laser := Projectile.new()
	add_child(laser)
	laser._on_area_entered(first)
	laser._on_area_entered(second)
	check.call(first.hp == 1 and second.hp == 2, "One laser damages only its first target in a physics frame")
	laser.free()
	first.free()
	second.free()


func _test_offline_account_and_ranking() -> void:
	GameState.clear_auth()
	var api := MockApiClient.new()
	add_child(api)
	var auth_results: Array[bool] = []
	api.auth_completed.connect(func(ok: bool, _message: String): auth_results.append(ok))
	api.login("pilot@example.com", "incorrect-password")
	api.reply(0, false, 0, {})
	check.call(not GameState.is_authenticated and auth_results == [false], "Offline login never creates a fake authenticated account")
	GameState.clear_auth()
	api.sign_up("pilot@example.com", "password", "OfflinePilot")
	api.reply(1, false, 0, {})
	check.call(not GameState.is_authenticated and not auth_results.back(), "Offline signup reports that no account was created")
	var rankings: Array[Dictionary] = []
	api.leaderboard_loaded.connect(func(_metric: String, data: Dictionary): rankings.append(data))
	api.fetch_leaderboard("kills")
	api.reply(2, false, 0, {})
	check.call(rankings.size() == 1 and rankings[0].get("entries", []).is_empty() and rankings[0].get("offlineFallback", false), "Unavailable rankings never display fabricated players or scores")
	api.free()
	GameState.clear_auth()


func _test_session_responses() -> void:
	GameState.set_authenticated_user("test-token", {"id": "test-pilot", "nickname": "TestPilot"})
	var api := MockApiClient.new()
	add_child(api)
	GameState.start_new_run()
	api.start_server_game_session()
	GameState.start_new_run()
	api.start_server_game_session()
	api.reply(1, true, 201, {"data": {"sessionId": "new-run"}})
	api.reply(0, true, 201, {"data": {"sessionId": "old-run"}})
	check.call(GameState.active_session_id == "new-run", "Late session creation cannot replace a restarted run's session")
	api.free()

	api = MockApiClient.new()
	add_child(api)
	GameState.start_new_run()
	api.start_server_game_session()
	var payload := GameState.finish_run()
	api.submit_completed_run(payload)
	check.call(api.requests.size() == 1, "Dying before session creation responds waits for the original session")
	api.reply(0, true, 201, {"data": {"sessionId": "early-death"}})
	check.call(api.requests.size() == 2 and api.requests[1]["endpoint"] == "/api/v1/game-sessions/early-death/complete", "Early death submits using the session requested at run start")
	api.free()

	api = MockApiClient.new()
	add_child(api)
	GameState.start_new_run()
	GameState.active_session_id = "finished-run"
	payload = GameState.finish_run()
	api.submit_completed_run(payload)
	GameState.start_new_run()
	api.start_server_game_session()
	api.reply(1, true, 201, {"data": {"sessionId": "next-run"}})
	api.reply(0, true, 200, {"data": {"validationStatus": "VALID"}})
	check.call(GameState.active_session_id == "next-run" and GameState.last_submission_status == "IDLE", "Previous score response cannot clear the next session or overwrite its status")
	api.free()

	api = MockApiClient.new()
	add_child(api)
	GameState.start_new_run()
	GameState.active_session_id = ""
	payload = GameState.finish_run()
	api.submit_completed_run(payload)
	check.call(api.requests.is_empty() and GameState.last_submission_status == "OFFLINE", "A run without a server session stays local instead of allocating one after death")
	api.free()
	GameState.clear_auth()


func _test_profile_response_isolation() -> void:
	GameState.set_authenticated_user("profile-test-token", {"nickname": "OriginalPilot"})
	var api := MockApiClient.new()
	add_child(api)
	var profiles: Array[Dictionary] = []
	api.profile_loaded.connect(func(data: Dictionary): profiles.append(data))
	api.update_nickname("RenamedPilot")
	api.reply(0, false, 0, {})
	check.call(GameState.player_nickname == "OriginalPilot" and profiles.back().has("error"), "Offline nickname update does not pretend the account was changed")
	api.fetch_my_stats()
	GameState.clear_auth()
	var guest_nickname: String = GameState.player_nickname
	api.reply(1, true, 200, {"data": {"nickname": "LatePilot", "killsRank": 99}})
	check.call(GameState.player_nickname == guest_nickname and GameState.kills_rank == 0, "Late profile response after logout cannot restore account ranks or nickname")
	api.free()


func _test_leaderboard_page_order() -> void:
	# Build only the UI so no actual HTTP request is needed for response ordering.
	var board = load("res://scenes/LeaderboardsScreen.tscn").instantiate()
	board._build_ui()
	board.current_page = 2
	board._on_leaderboard_loaded("kills", {"page": 1, "totalPages": 3, "entries": []})
	check.call(board.current_page == 2, "Late leaderboard page cannot replace the requested page")
	board._on_leaderboard_loaded("kills", {"page": 2, "totalPages": 1, "entries": [], "offlineFallback": true})
	check.call("unavailable" in board.rows_container.get_child(board.rows_container.get_child_count() - 1).text.to_lower(), "Leaderboard screen explains when the service is unavailable")
	board.free()


func _test_checkpoint_crossings() -> void:
	GameState.start_new_run()
	GameState.add_distance(499.8)
	GameState.add_distance(2.5)
	check.call(GameState.checkpoint_events.size() == 1 and GameState.checkpoint_events[0]["value"] == 500, "Distance checkpoints are recorded when a frame crosses a milestone")


func _test_physics_collisions() -> void:
	GameState.clear_auth()
	GameState.start_new_run()
	var world := Node2D.new()
	add_child(world)
	var ship := PlayerShip.new()
	ship.position = Vector2(220, 340)
	ship.set_physics_process(false)
	world.add_child(ship)
	ship.set_physics_process(false)
	var bullet := Projectile.new()
	bullet.is_player_projectile = false
	bullet.speed = 0
	bullet.position = ship.position
	world.add_child(bullet)
	for frame in range(3):
		await get_tree().physics_frame
	check.call(not ship.is_alive, "Actual physics overlap with enemy projectile kills the player")
	world.free()
	GameState.is_running = false


func _test_screen_flow() -> void:
	# Keep the test runner alive while exercising the real scene transition path.
	var test_scene := get_tree().current_scene
	get_tree().current_scene = null
	GameState.has_seen_intro_cutscene = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().scene_changed
	var menu = get_tree().current_scene
	check.call("GUEST" in menu.auth_status_label.text, "Main menu initializes guest controls")
	menu._on_play_pressed()
	await get_tree().scene_changed
	var intro = get_tree().current_scene
	check.call(intro.scene_file_path.ends_with("Cutscene.tscn"), "First play opens the heist cutscene")
	# Click outside the advance/skip buttons, as supported by the documented controls.
	get_viewport().push_input(_mouse(MOUSE_BUTTON_LEFT, true, Vector2(640, 400)), true)
	get_viewport().push_input(_mouse(MOUSE_BUTTON_LEFT, false, Vector2(640, 400)), true)
	check.call(intro.char_idx == str(intro.DIALOGUE_BEATS[0]["text"]).length(), "Clicking the cutscene illustration reveals the dialogue")
	intro._on_next_pressed()
	check.call(intro.current_beat_idx == 1, "Advancing a completed dialogue moves to the next beat")
	intro._finish_cutscene()
	await get_tree().scene_changed
	var game = get_tree().current_scene
	check.call(GameState.has_seen_intro_cutscene and GameState.is_running, "Skipping the intro starts gameplay and saves the intro flag")
	game.player.set_physics_process(false)
	game.set_process(false)
	GameState.add_distance(50)
	game.player.die()
	await get_tree().scene_changed
	var over = get_tree().current_scene
	check.call(over.scene_file_path.ends_with("GameOverScreen.tscn") and GameState.last_run_distance == 50, "Death opens Game Over with the actual run score")
	check.call(GameState.last_submission_status == "OFFLINE", "Guest runs are saved locally without requiring the API")
	over._restart_game()
	await get_tree().scene_changed
	game = get_tree().current_scene
	check.call(GameState.is_running and GameState.current_distance == 0 and game.player.is_alive, "Instant restart creates a living player and resets the score")
	game._toggle_pause()
	game._restart_immediately()
	await get_tree().scene_changed
	check.call(not get_tree().paused and GameState.is_running, "Restart from pause resumes a fresh run")
	GameState.is_running = false
	get_tree().change_scene_to_file("res://scenes/AuthScreen.tscn")
	await get_tree().scene_changed
	var auth = get_tree().current_scene
	check.call(auth.password_input.text.is_empty() and auth.password_input.secret, "Authentication never prefills a shared password")
	get_tree().change_scene_to_file("res://scenes/ProfileScreen.tscn")
	await get_tree().scene_changed
	check.call("Local Guest" in get_tree().current_scene.stats_label.text, "Profile opens with local guest records")
	get_tree().change_scene_to_file("res://scenes/LeaderboardsScreen.tscn")
	await get_tree().scene_changed
	check.call(get_tree().current_scene.rows_container != null, "Leaderboard screen initializes its controls")
	get_tree().current_scene.free()
	get_tree().current_scene = test_scene


func _test_local_persistence() -> void:
	GameState.best_distance = 1234
	GameState.best_kills = 12
	GameState.music_volume_db = -15
	GameState.music_muted = true
	GameState.save_local_data()
	GameState.best_distance = 0
	GameState.best_kills = 0
	GameState.music_muted = false
	GameState.load_local_data()
	check.call(GameState.best_distance == 1234 and GameState.best_kills == 12 and GameState.has_seen_intro_cutscene, "Personal records and intro progress survive reload")
	AudioManager.apply_volume_settings()
	check.call(GameState.music_muted and AudioManager.music_player.volume_db == -80, "Saved mute setting is applied to music playback")
	GameState.music_muted = false
	AudioManager.apply_volume_settings()
	check.call(AudioManager.music_player.volume_db == -15, "Unmuting restores the saved music volume")
