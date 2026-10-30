class_name Projectile
extends Area2D
## SpaceToby Laser & Plasma Projectile Entity.
## Handles player forward cyan lasers and enemy orange plasma projectiles,
## collision detection, impact sparks, and automatic off-screen cleanup.

@export var speed: float = 860.0
@export var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 1
@export var is_player_projectile: bool = true

var sprite: Sprite2D


func _ready() -> void:
	monitoring = true
	monitorable = true
	_setup_visuals()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _setup_visuals() -> void:
	if get_node_or_null("Sprite2D") == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		if is_player_projectile:
			sprite.texture = load("res://assets/effects/laser_player.png")
			sprite.scale = Vector2(0.85, 0.75)
		else:
			sprite.texture = load("res://assets/effects/laser_enemy.png")
			sprite.scale = Vector2(0.9, 0.9)
		add_child(sprite)

	if get_node_or_null("CollisionShape2D") == null:
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36.0, 12.0) if is_player_projectile else Vector2(22.0, 14.0)
		col.shape = rect
		add_child(col)


func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	# Cleanup when leaving the visible 1280x720 viewport bounds
	if position.x > 1420.0 or position.x < -120.0 or position.y < -80.0 or position.y > 800.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_player_projectile and area.is_in_group("enemy"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
	elif is_player_projectile and area.is_in_group("obstacle"):
		AudioManager.play_sfx("hit", 0.1)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not is_player_projectile and body is PlayerShip:
		body.die()
		queue_free()
