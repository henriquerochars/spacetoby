class_name EnemyShip
extends Area2D
## SpaceToby Enemy Spaceship Entity.
## Supports three distinct enemy archetypes using original PixelLab assets:
## 1. "scout"   — Small, fast, 2 HP, sine-wave path.
## 2. "fighter" — Medium, 4 HP, tactical weave + shoots energy projectiles toward player.
## 3. "heavy"   — Large armored warship, 9 HP, slow advance + periodic dual plasma fire.

signal enemy_destroyed(enemy_type: String, world_pos: Vector2)
signal enemy_fired_projectile(spawn_pos: Vector2, dir: Vector2)

@export var enemy_type: String = "scout"

var max_hp: int = 2
var hp: int = 2
var speed_multiplier: float = 1.25
var wave_amplitude: float = 40.0
var wave_frequency: float = 2.6
var can_shoot: bool = false
var base_fire_cooldown: float = 2.2
var fire_timer: float = 1.2

var base_y: float = 360.0
var time_alive: float = 0.0
var hit_flash_timer: float = 0.0

var sprite: Sprite2D
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect


func configure(type_name: String, spawn_pos: Vector2) -> void:
	enemy_type = type_name
	position = spawn_pos
	base_y = spawn_pos.y

	match enemy_type:
		"scout":
			max_hp = 2
			hp = 2
			speed_multiplier = 1.32
			wave_amplitude = 34.0
			wave_frequency = 3.1
			can_shoot = false
		"fighter":
			max_hp = 4
			hp = 4
			speed_multiplier = 1.05
			wave_amplitude = 62.0
			wave_frequency = 2.0
			can_shoot = true
			base_fire_cooldown = 1.95
			fire_timer = 0.9
		"heavy":
			max_hp = 8
			hp = 8
			speed_multiplier = 0.72
			wave_amplitude = 18.0
			wave_frequency = 1.1
			can_shoot = true
			base_fire_cooldown = 1.65
			fire_timer = 1.1
		_:
			max_hp = 2
			hp = 2


func _ready() -> void:
	add_to_group("enemy")
	monitoring = true
	monitorable = true
	_setup_visuals()
	body_entered.connect(_on_body_entered)


func _setup_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	var tex_path := "res://assets/enemies/enemy_scout.png"
	var hitbox_size := Vector2(54.0, 38.0)

	if enemy_type == "fighter":
		tex_path = "res://assets/enemies/enemy_fighter.png"
		hitbox_size = Vector2(72.0, 52.0)
	elif enemy_type == "heavy":
		tex_path = "res://assets/enemies/enemy_heavy.png"
		hitbox_size = Vector2(114.0, 82.0)

	sprite.texture = load(tex_path)
	sprite.scale = Vector2(1.1, 1.1)
	add_child(sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = hitbox_size
	col.shape = rect
	add_child(col)

	# Health bar above multi-hit enemies
	var bar_w: float = hitbox_size.x * 0.8
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(bar_w, 6.0)
	hp_bar_bg.position = Vector2(-bar_w * 0.5, -hitbox_size.y * 0.65 - 10.0)
	hp_bar_bg.color = Color(0.08, 0.08, 0.16, 0.85)
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(bar_w, 6.0)
	hp_bar_fill.position = hp_bar_bg.position
	hp_bar_fill.color = Color(0.0, 0.96, 0.83, 0.95) if enemy_type != "heavy" else Color(1.0, 0.55, 0.1, 0.95)
	add_child(hp_bar_fill)


func _physics_process(delta: float) -> void:
	time_alive += delta
	var scroll_spd: float = DifficultyManager.get_scroll_speed() if DifficultyManager else 280.0
	position.x -= scroll_spd * speed_multiplier * delta
	position.y = clampf(
		base_y + sin(time_alive * wave_frequency) * wave_amplitude,
		68.0,
		652.0
	)

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0 and sprite:
			sprite.modulate = Color(1, 1, 1, 1)

	if can_shoot and position.x < 1220.0 and position.x > 260.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			var mult: float = DifficultyManager.get_enemy_fire_cooldown_multiplier() if DifficultyManager else 1.0
			fire_timer = base_fire_cooldown * mult
			var muzzle := global_position + Vector2(-42.0, 0.0)
			enemy_fired_projectile.emit(muzzle, Vector2.LEFT)

	if position.x < -160.0:
		queue_free()


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= maxi(1, amount)
	hit_flash_timer = 0.09
	if sprite:
		sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	if hp_bar_fill and hp_bar_bg:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		hp_bar_fill.size.x = hp_bar_bg.size.x * ratio

	if hp <= 0:
		AudioManager.play_sfx("explosion", 0.08)
		GameState.register_enemy_kill(1)
		enemy_destroyed.emit(enemy_type, global_position)
		queue_free()
	else:
		AudioManager.play_sfx("hit", 0.08)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerShip:
		body.die()
