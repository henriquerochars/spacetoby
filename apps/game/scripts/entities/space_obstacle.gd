class_name SpaceObstacle
extends Area2D
## SpaceToby Procedural Space Obstacle Entity.
## Represents either a rotating cosmic asteroid or a space station barrier pillar
## that scrolls left across the screen and ends the run on collision.

@export var obstacle_kind: String = "asteroid" # "asteroid" or "pillar"
var rotation_speed: float = 0.0
var custom_height: float = 192.0


func configure(kind: String, spawn_pos: Vector2, height_override: float = 192.0, flip_v_flag: bool = false) -> void:
	obstacle_kind = kind
	position = spawn_pos
	custom_height = height_override
	set_meta("flip_v", flip_v_flag)


func _ready() -> void:
	add_to_group("obstacle")
	monitoring = true
	monitorable = true
	_setup_visuals()
	body_entered.connect(_on_body_entered)


func _setup_visuals() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"

	if obstacle_kind == "pillar":
		sprite.texture = load("res://assets/enemies/obstacle_station_pillar.png")
		var scale_y := custom_height / 192.0
		sprite.scale = Vector2(1.0, scale_y)
		sprite.flip_v = bool(get_meta("flip_v", false))
		var rect := RectangleShape2D.new()
		rect.size = Vector2(46.0, custom_height - 8.0)
		col.shape = rect
	else:
		sprite.texture = load("res://assets/enemies/obstacle_asteroid_large.png")
		sprite.scale = Vector2(0.88, 0.88)
		rotation_speed = randf_range(-1.2, 1.2)
		var circle := CircleShape2D.new()
		circle.radius = 34.0
		col.shape = circle

	add_child(sprite)
	add_child(col)


func _physics_process(delta: float) -> void:
	var scroll_spd: float = DifficultyManager.get_scroll_speed() if DifficultyManager else 280.0
	position.x -= scroll_spd * delta
	if rotation_speed != 0.0:
		rotation += rotation_speed * delta
	if position.x < -160.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerShip:
		body.die()
