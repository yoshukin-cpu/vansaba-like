extends Node2D

const GRID_STEP: float = 128.0
const GRID_COLOR := Color(1, 1, 1, 0.08)
const AXIS_COLOR := Color(1, 1, 1, 0.2)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var xform: Transform2D = get_canvas_transform()
	if xform.get_scale().length() < 0.001:
		return
	var inv: Transform2D = xform.affine_inverse()
	var view_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = inv * Vector2.ZERO
	var bottom_right: Vector2 = inv * view_size
	var x0: float = floor(top_left.x / GRID_STEP) * GRID_STEP
	var x1: float = bottom_right.x
	var y0: float = floor(top_left.y / GRID_STEP) * GRID_STEP
	var y1: float = bottom_right.y
	var x: float = x0
	while x <= x1:
		var c := AXIS_COLOR if absf(x) < 1.0 else GRID_COLOR
		var w := 2.0 if absf(x) < 1.0 else 1.0
		draw_line(Vector2(x, y0), Vector2(x, y1), c, w)
		x += GRID_STEP
	var y: float = y0
	while y <= y1:
		var c2 := AXIS_COLOR if absf(y) < 1.0 else GRID_COLOR
		var w2 := 2.0 if absf(y) < 1.0 else 1.0
		draw_line(Vector2(x0, y), Vector2(x1, y), c2, w2)
		y += GRID_STEP
	draw_circle(Vector2.ZERO, 8.0, Color(1, 1, 1, 0.25))
