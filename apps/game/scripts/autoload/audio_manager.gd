extends Node
## Central AudioManager Autoload Singleton for SpaceToby.
## Manages background music tracks (Menu, Cutscene, Gameplay) and pooled SFX players
## with configurable volume and mute controls.

const MUSIC_TRACKS := {
	"menu": "res://assets/audio/menu_bgm.wav",
	"cutscene": "res://assets/audio/cutscene_bgm.wav",
	"gameplay": "res://assets/audio/gameplay_bgm.wav"
}

const SFX_TRACKS := {
	"laser": "res://assets/audio/laser.wav",
	"thrust": "res://assets/audio/thrust.wav",
	"explosion": "res://assets/audio/explosion.wav",
	"hit": "res://assets/audio/hit.wav",
	"gameover": "res://assets/audio/gameover.wav",
	"button": "res://assets/audio/button.wav",
	"voice_blip": "res://assets/audio/voice_blip.wav"
}

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var current_music_key: String = ""
var loaded_sfx: Dictionary = {}
var loaded_music: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)

	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		sfx_pool.append(p)

	for k in SFX_TRACKS.keys():
		var path: String = SFX_TRACKS[k]
		if ResourceLoader.exists(path):
			loaded_sfx[k] = load(path)

	for k in MUSIC_TRACKS.keys():
		var path: String = MUSIC_TRACKS[k]
		if ResourceLoader.exists(path):
			loaded_music[k] = load(path)

	apply_volume_settings()


func apply_volume_settings() -> void:
	if not music_player:
		return
	if GameState.music_muted:
		music_player.volume_db = -80.0
	else:
		music_player.volume_db = GameState.music_volume_db


func play_music(track_key: String) -> void:
	if current_music_key == track_key and music_player.playing:
		return
	current_music_key = track_key
	var stream = loaded_music.get(track_key, null)
	if stream:
		music_player.stream = stream
		apply_volume_settings()
		music_player.play()


func stop_music() -> void:
	current_music_key = ""
	if music_player:
		music_player.stop()


func _on_music_finished() -> void:
	if not current_music_key.is_empty():
		music_player.play()


func play_sfx(sfx_key: String, pitch_variation: float = 0.06) -> void:
	if GameState.sfx_muted:
		return
	var stream = loaded_sfx.get(sfx_key, null)
	if not stream:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = GameState.sfx_volume_db
			p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			p.play()
			return
	# Fallback to first player if all busy
	var first := sfx_pool[0]
	first.stream = stream
	first.volume_db = GameState.sfx_volume_db
	first.pitch_scale = 1.0
	first.play()
