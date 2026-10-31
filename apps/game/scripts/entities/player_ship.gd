class_name PlayerShip
extends CharacterBody2D
## SpaceToby Player Spaceship Controller.
## Implements responsive Flappy Bird-inspired gravity & thrust physics,
## smooth pitch tilting, cockpit Toby portrait reactions, forward laser weapon
## with configurable cooldown, and collision detection.

signal laser_fired(spawn_pos: Vector2)
signal player_died(collision_pos: Vector2)
signal cockpit_expression_changed(expression_key: String)

@export var gravity_accel: float = 1180.0
@export var thrust_impulse: float = -410.0
@export var hold_thrust_accel: float = -720.0
@export var max_fall_speed: float = 540.0
@export var max_rise_speed: float = -460.0
@export var fire_cooldown: float = 0.20

const MIN_Y: float = 54.0
const MAX_Y: float = 666.0

var is_alive: bool = true
var fire_timer: float = 0.0
var touch_thrust_active: bool = false
var touch_shoot_active: bool = false

var ship_sprite: Sprite2D
var thruster_glow: Polygon2D
var thruster_core: Polygon2D
var tex_idle: Texture2D
var tex_thrust: Texture2D
var hover_time: float = 0.0
var thruster_frame: int = 0
var thruster_frame_timer: float = 0.0
var thruster_flame_timer: float = 0.0


func _ready() -> void:
	tex_idle = load("res://assets/spaceships/player_ship_idle.png")
	tex_thrust = load("res://assets/spaceships/player_ship_thrust.png")
	_setup_visuals()


func _setup_visuals() -> void:
	if get_node_or_null("ShipSprite") == null:
		ship_sprite = Sprite2D.new()
		ship_sprite.name = "ShipSprite"
		ship_sprite.texture = tex_idle
		ship_sprite.scale = Vector2(1.15, 1.15)
		add_child(ship_sprite)
	else:
		ship_sprite = get_node("ShipSprite")

	if get_node_or_null("ThrusterGlow") == null:
		thruster_glow = Polygon2D.new()
		thruster_glow.name = "ThrusterGlow"
		thruster_glow.z_index = -1
		thruster_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thruster_glow.visible = false
		add_child(thruster_glow)
	else:
		thruster_glow = get_node("ThrusterGlow")
	if get_node_or_null("ThrusterCore") == null:
		thruster_core = Polygon2D.new()
		thruster_core.name = "ThrusterCore"
		thruster_core.z_index = -1
		thruster_core.color = Color(1.0, 0.86, 0.36, 0.95)
		thruster_core.visible = false
		add_child(thruster_core)
	else:
		thruster_core = get_node("ThrusterCore")
	_update_thruster_frame()

	if get_node_or_null("CollisionShape2D") == null:
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := CapsuleShape2D.new()
		shape.radius = 18.0
		shape.height = 68.0
		col.rotation = PI * 0.5
		col.shape = shape
		add_child(col)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	hover_time += delta
	thruster_frame_timer += delta
	thruster_flame_timer = maxf(0.0, thruster_flame_timer - delta)
	if thruster_frame_timer >= 0.055:
		thruster_frame_timer = 0.0
		thruster_frame = (thruster_frame + 1) % 4
		_update_thruster_frame()
	fire_timer = maxf(0.0, fire_timer - delta)

	# 1. Gravity pulls spaceship downward continuously
	velocity.y += gravity_accel * delta

	# 2. Check upward thrust input (Spacebar / Left Mouse / Touch Left Side)
	var just_pressed_thrust: bool = Input.is_action_just_pressed("thrust")
	var holding_thrust: bool = Input.is_action_pressed("thrust") or touch_thrust_active

	if just_pressed_thrust:
		apply_upward_thrust()
	else:
		if holding_thrust:
			velocity.y += hold_thrust_accel * delta
		if holding_thrust or thruster_flame_timer > 0.0:
			if ship_sprite and tex_thrust:
				ship_sprite.texture = tex_thrust
			if thruster_glow:
				thruster_glow.visible = true
			if thruster_core:
				thruster_core.visible = true
		else:
			if ship_sprite and tex_idle:
				ship_sprite.texture = tex_idle
			if thruster_glow:
				thruster_glow.visible = false
			if thruster_core:
				thruster_core.visible = false

	velocity.y = clampf(velocity.y, max_rise_speed, max_fall_speed)
	velocity.x = 0.0

	# Move vertically and clamp to arena ceiling/floor
	position.y += velocity.y * delta
	if position.y < MIN_Y:
		position.y = MIN_Y
		velocity.y = maxf(0.0, velocity.y)
	elif position.y > MAX_Y:
		# Touching extreme bottom radiation floor triggers collision hazard
		position.y = MAX_Y
		die()
		return

	# Smooth pitch rotation based on vertical velocity
	var target_rot: float = clampf(velocity.y / 520.0, -0.45, 0.52)
	rotation = lerpf(rotation, target_rot, minf(1.0, delta * 12.0))

	# 3. Check laser shooting input (J / Z / K / Touch Right Side)
	if Input.is_action_pressed("shoot") or touch_shoot_active:
		try_shoot()


func apply_upward_thrust() -> void:
	if not is_alive:
		return
	velocity.y = thrust_impulse
	thruster_flame_timer = 0.14
	if ship_sprite and tex_thrust:
		ship_sprite.texture = tex_thrust
	if thruster_glow:
		thruster_glow.visible = true
	if thruster_core:
		thruster_core.visible = true
	AudioManager.play_sfx("thrust", 0.08)
	cockpit_expression_changed.emit("determined")


func try_shoot() -> bool:
	if not is_alive or fire_timer > 0.0:
		return false
	fire_timer = fire_cooldown
	var muzzle_pos := global_position + Vector2(52.0, 2.0).rotated(rotation)
	AudioManager.play_sfx("laser", 0.05)
	cockpit_expression_changed.emit("determined")
	laser_fired.emit(muzzle_pos)
	return true


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	if thruster_glow:
		thruster_glow.visible = false
	if thruster_core:
		thruster_core.visible = false
	AudioManager.play_sfx("explosion", 0.04)
	AudioManager.play_sfx("gameover", 0.0)
	cockpit_expression_changed.emit("gameover")
	player_died.emit(global_position)


func _update_thruster_frame() -> void:
	if not thruster_glow:
		return
	var outer_lengths: Array[float] = [30.0, 38.0, 34.0, 42.0]
	var half_heights: Array[float] = [7.0, 9.0, 6.0, 8.0]
	var length: float = outer_lengths[thruster_frame]
	var half_height: float = half_heights[thruster_frame]
	thruster_glow.polygon = PackedVector2Array([
		Vector2(-46, -8), Vector2(-56, -8), Vector2(-61, -half_height),
		Vector2(-46 - length, 0), Vector2(-61, half_height), Vector2(-56, 8), Vector2(-46, 8)
	])
	thruster_glow.color = [Color(1.0, 0.48, 0.08), Color(1.0, 0.62, 0.12), Color(1.0, 0.4, 0.06), Color(1.0, 0.7, 0.16)][thruster_frame]
	if thruster_core:
		var core_len: float = length * 0.58
		thruster_core.polygon = PackedVector2Array([
			Vector2(-46, -4), Vector2(-54, -4), Vector2(-54 - core_len, 0), Vector2(-54, 4)
		])
