extends Control
## SpaceToby Authentication Screen (`AuthScreen.tscn`).
## Supports Sign Up, Login, Password Recovery, and Public Nickname setup via Supabase/NestJS API.

var email_input: LineEdit
var password_input: LineEdit
var nickname_input: LineEdit
var status_label: Label


func _ready() -> void:
	ApiClient.auth_completed.connect(_on_auth_completed)
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(340, 80)
	panel.size = Vector2(600, 560)
	add_child(panel)

	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/characters/toby_portrait_determined.png")
	portrait.position = Vector2(250, 20)
	portrait.size = Vector2(100, 100)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(portrait)

	var title := Label.new()
	title.text = "SPACE COMMAND // PILOT AUTHENTICATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(30, 128)
	title.size = Vector2(540, 34)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Sign in to qualify for Global Leaderboards (Kills & Distance)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(30, 160)
	sub.size = Vector2(540, 26)
	sub.add_theme_font_size_override("font_size", 14)
	panel.add_child(sub)

	var email_lbl := Label.new()
	email_lbl.text = "Pilot Email:"
	email_lbl.position = Vector2(70, 198)
	panel.add_child(email_lbl)

	email_input = LineEdit.new()
	email_input.placeholder_text = "toby@spacetoby.io"
	email_input.text = GameState.player_email if not GameState.player_email.is_empty() else "toby@spacetoby.io"
	email_input.position = Vector2(70, 224)
	email_input.size = Vector2(460, 38)
	panel.add_child(email_input)

	var pass_lbl := Label.new()
	pass_lbl.text = "Password (min 6 chars):"
	pass_lbl.position = Vector2(70, 272)
	panel.add_child(pass_lbl)

	password_input = LineEdit.new()
	password_input.secret = true
	password_input.placeholder_text = "••••••••"
	password_input.text = "Quantum2026!"
	password_input.position = Vector2(70, 298)
	password_input.size = Vector2(460, 38)
	panel.add_child(password_input)

	var nick_lbl := Label.new()
	nick_lbl.text = "Public Nickname (for Sign Up):"
	nick_lbl.position = Vector2(70, 346)
	panel.add_child(nick_lbl)

	nickname_input = LineEdit.new()
	nickname_input.placeholder_text = "TobyMaster"
	nickname_input.text = GameState.player_nickname
	nickname_input.position = Vector2(70, 372)
	nickname_input.size = Vector2(460, 38)
	panel.add_child(nickname_input)

	var login_btn := Button.new()
	login_btn.text = "LOGIN"
	login_btn.position = Vector2(70, 428)
	login_btn.size = Vector2(220, 46)
	login_btn.pressed.connect(_on_login_pressed)
	panel.add_child(login_btn)

	var signup_btn := Button.new()
	signup_btn.text = "SIGN UP NEW PILOT"
	signup_btn.position = Vector2(310, 428)
	signup_btn.size = Vector2(220, 46)
	signup_btn.pressed.connect(_on_signup_pressed)
	panel.add_child(signup_btn)

	var recover_btn := Button.new()
	recover_btn.text = "RECOVER PASSWORD"
	recover_btn.position = Vector2(70, 486)
	recover_btn.size = Vector2(220, 40)
	recover_btn.pressed.connect(_on_recover_pressed)
	panel.add_child(recover_btn)

	var back_btn := Button.new()
	back_btn.text = "BACK TO MAIN MENU"
	back_btn.position = Vector2(310, 486)
	back_btn.size = Vector2(220, 40)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	panel.add_child(back_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(40, 532)
	status_label.size = Vector2(520, 26)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	panel.add_child(status_label)


func _on_login_pressed() -> void:
	AudioManager.play_sfx("button")
	status_label.text = "Authenticating with Space Command..."
	ApiClient.login(email_input.text, password_input.text)


func _on_signup_pressed() -> void:
	AudioManager.play_sfx("button")
	status_label.text = "Registering pilot profile..."
	ApiClient.sign_up(email_input.text, password_input.text, nickname_input.text)


func _on_recover_pressed() -> void:
	AudioManager.play_sfx("button")
	ApiClient.recover_password(email_input.text)


func _on_auth_completed(success: bool, message: String) -> void:
	status_label.text = message
	if success:
		status_label.add_theme_color_override("font_color", Color(0.0, 0.96, 0.83))
		var t := get_tree().create_timer(0.8)
		t.timeout.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		)
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
