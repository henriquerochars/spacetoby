extends Control
## SpaceToby Opening Cutscene (`Cutscene.tscn`).
## Tells the story of Toby, the charismatic anthropomorphic beagle space mercenary,
## escaping at warp speed from a heist on Baron Vex's syndicate vault while cursing
## him out over the comms before launching directly into gameplay.

const DIALOGUE_BEATS := [
	{
		"speaker": "ALARME DO COFRE SINDICATO [SETOR NEON-9]",
		"speaker_color": Color(1.0, 0.32, 0.32),
		"portrait": "res://assets/characters/baron_vex_portrait.png",
		"text": "ALERTA VERMELHO! O mercenário espacial Toby acabou de arrombar o Cofre Imperial e roubou o Cristal Quântico! Interceptem a nave daquele beagle agora!!"
	},
	{
		"speaker": "BARÃO VEX (TRANSMISSÃO HOLOGRÁFICA)",
		"speaker_color": Color(1.0, 0.55, 0.12),
		"portrait": "res://assets/characters/baron_vex_portrait.png",
		"text": "\"SEU VIRA-LATA PULGUENTO! Devolve o meu Cristal Quântico imediatamente ou minha frota vai transformar sua lata-velha em poeira cósmica!\""
	},
	{
		"speaker": "TOBY — MERCENÁRIO DO ESPAÇO",
		"speaker_color": Color(0.0, 0.96, 0.83),
		"portrait": "res://assets/characters/toby_portrait_cursing.png",
		"text": "\"HAHAHA! Vai chorar no buraco negro, seu calango sovina do caramba!! Achou mesmo que ia esconder esse Cristal de mim?! Come plasma dos meus propulsores, seu lata-velha desgraçado!\""
	},
	{
		"speaker": "TOBY — MERCENÁRIO DO ESPAÇO",
		"speaker_color": Color(0.35, 0.72, 1.0),
		"portrait": "res://assets/characters/toby_portrait_determined.png",
		"text": "\"Droga, esse cara mandou a frota inteira bloquear o cinturão de asteroides! Canhões laser carregados... Segura firme que a fuga vai ser no talento!\""
	}
]

var current_beat_idx: int = 0
var char_idx: int = 0
var type_timer: float = 0.0
var blip_counter: int = 0
var alarm_time: float = 0.0

var bg_rect: TextureRect
var alarm_overlay: ColorRect
var illustration_rect: TextureRect
var ship_preview: Sprite2D
var portrait_rect: TextureRect
var speaker_label: Label
var dialogue_label: Label
var next_button: Button
var skip_button: Button


func _ready() -> void:
	AudioManager.play_music("cutscene")
	_build_ui()
	_load_beat(0)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Deep Space Background
	bg_rect = TextureRect.new()
	bg_rect.texture = load("res://assets/backgrounds/starfield_deep.png")
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)

	# Red Heist Alarm Flash Overlay
	alarm_overlay = ColorRect.new()
	alarm_overlay.color = Color(0.95, 0.1, 0.2, 0.12)
	alarm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(alarm_overlay)

	# Top Header Banner
	var header_lbl := Label.new()
	header_lbl.text = "PRÓLOGO // A GRANDE FUGA DO SETOR NEON-9"
	header_lbl.position = Vector2(60, 26)
	header_lbl.add_theme_font_size_override("font_size", 22)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
	add_child(header_lbl)

	# Skip Cutscene Button
	skip_button = Button.new()
	skip_button.text = "PULAR CUTSCENE [ESC]"
	skip_button.position = Vector2(1010, 22)
	skip_button.size = Vector2(210, 42)
	skip_button.pressed.connect(_finish_cutscene)
	add_child(skip_button)

	# Central PixelLab Cutscene Illustration Frame
	var frame_panel := Panel.new()
	frame_panel.position = Vector2(160, 82)
	frame_panel.size = Vector2(960, 355)
	add_child(frame_panel)

	illustration_rect = TextureRect.new()
	illustration_rect.texture = load("res://assets/ui/cutscene_heist_escape.png")
	illustration_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration_rect.position = Vector2(8, 8)
	illustration_rect.size = Vector2(944, 339)
	frame_panel.add_child(illustration_rect)

	# Animated Fleeing Ship Sprite Overlay
	ship_preview = Sprite2D.new()
	ship_preview.texture = load("res://assets/spaceships/player_ship_thrust.png")
	ship_preview.position = Vector2(740, 250)
	ship_preview.scale = Vector2(2.0, 2.0)
	frame_panel.add_child(ship_preview)

	# Bottom Dialogue Box Panel
	var dialog_panel := Panel.new()
	dialog_panel.position = Vector2(80, 460)
	dialog_panel.size = Vector2(1120, 225)
	add_child(dialog_panel)

	# Character Portrait Box inside Dialogue Panel
	var portrait_bg := ColorRect.new()
	portrait_bg.color = Color(0.05, 0.07, 0.18, 1.0)
	portrait_bg.position = Vector2(20, 20)
	portrait_bg.size = Vector2(185, 185)
	dialog_panel.add_child(portrait_bg)

	portrait_rect = TextureRect.new()
	portrait_rect.position = Vector2(24, 24)
	portrait_rect.size = Vector2(177, 177)
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_panel.add_child(portrait_rect)

	speaker_label = Label.new()
	speaker_label.position = Vector2(230, 22)
	speaker_label.size = Vector2(850, 34)
	speaker_label.add_theme_font_size_override("font_size", 22)
	dialog_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(230, 64)
	dialogue_label.size = Vector2(850, 100)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 20)
	dialogue_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	dialog_panel.add_child(dialogue_label)

	next_button = Button.new()
	next_button.text = "AVANÇAR [ESPAÇO / CLIQUE] ▶"
	next_button.position = Vector2(810, 165)
	next_button.size = Vector2(285, 44)
	next_button.pressed.connect(_on_next_pressed)
	dialog_panel.add_child(next_button)


func _load_beat(index: int) -> void:
	current_beat_idx = index
	var beat: Dictionary = DIALOGUE_BEATS[current_beat_idx]
	speaker_label.text = str(beat["speaker"])
	speaker_label.add_theme_color_override("font_color", beat["speaker_color"])
	portrait_rect.texture = load(str(beat["portrait"]))
	dialogue_label.text = ""
	char_idx = 0
	type_timer = 0.0
	if current_beat_idx == DIALOGUE_BEATS.size() - 1:
		next_button.text = "DECOLAR PARA A FUGA! 🚀"
	else:
		next_button.text = "AVANÇAR [ESPAÇO / CLIQUE] ▶"


func _process(delta: float) -> void:
	alarm_time += delta
	if alarm_overlay:
		alarm_overlay.color.a = 0.05 + 0.10 * abs(sin(alarm_time * 3.5))
	if ship_preview:
		ship_preview.position.y = 240.0 + sin(alarm_time * 5.0) * 14.0
		ship_preview.rotation = sin(alarm_time * 4.0) * 0.08

	var full_text: String = str(DIALOGUE_BEATS[current_beat_idx]["text"])
	if char_idx < full_text.length():
		type_timer += delta
		while type_timer >= 0.022 and char_idx < full_text.length():
			type_timer -= 0.022
			char_idx += 1
			dialogue_label.text = full_text.substr(0, char_idx)
			blip_counter += 1
			if blip_counter % 3 == 0:
				AudioManager.play_sfx("voice_blip", 0.12)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_finish_cutscene()
	elif event.is_action_pressed("thrust") or event.is_action_pressed("shoot"):
		_on_next_pressed()


func _on_next_pressed() -> void:
	AudioManager.play_sfx("button", 0.05)
	var full_text: String = str(DIALOGUE_BEATS[current_beat_idx]["text"])
	if char_idx < full_text.length():
		# Instant complete current line on first press
		char_idx = full_text.length()
		dialogue_label.text = full_text
		return

	if current_beat_idx + 1 < DIALOGUE_BEATS.size():
		_load_beat(current_beat_idx + 1)
	else:
		_finish_cutscene()


func _finish_cutscene() -> void:
	GameState.has_seen_intro_cutscene = true
	GameState.save_local_data()
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")
