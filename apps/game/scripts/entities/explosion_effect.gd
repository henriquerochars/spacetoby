extends Node2D
const FRAME_DURATION: float = 0.055
const FRAME_COUNT: int = 8
const GRID_SIZE: float = 4.0

var elapsed: float = 0.0
var frame: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20


func _process(delta: float) -> void:
	elapsed += delta
	var next_frame := int(elapsed / FRAME_DURATION)
	if next_frame >= FRAME_COUNT:
		queue_free()
		return
	modulate.a = clampf(1.0 - float(next_frame) / float(FRAME_COUNT), 0.0, 1.0)
	if next_frame != frame:
		frame = next_frame
		queue_redraw()


func _draw() -> void:
	var radius: float = 7.0 + frame * 4.2
	var core_radius: float = maxf(1.0, 10.0 - frame * 1.5)
	for y in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2(float(x), float(y))
			var distance := cell.length()
			var angle := atan2(cell.y, cell.x)
			var spoke := absf(sin(angle * 5.0 + frame * 0.45))
			var edge := radius * (0.72 + spoke * 0.32)
			if distance > edge or distance < 1.0:
				continue
			var color: Color
			if distance <= core_radius:
				color = Color(1.0, 0.96, 0.68, 1.0)
			elif distance <= core_radius + 4.0:
				color = Color(1.0, 0.63, 0.16, 1.0)
			else:
				color = Color(1.0, 0.25, 0.12, 0.88)
			draw_rect(Rect2(cell * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE)), color)
