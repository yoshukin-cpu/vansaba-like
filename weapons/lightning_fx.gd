extends Node2D

var points: PackedVector2Array = PackedVector2Array()
var age: float = 0.0
var lifetime: float = 0.25

func setup(pts: PackedVector2Array) -> void:
	points = pts
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	modulate.a = 1.0 - age / lifetime
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var local := PackedVector2Array()
	for p: Vector2 in points:
		local.append(p - global_position)
	draw_polyline(local, Color(0.7, 0.95, 1.0, 1.0), 5.0, true)
	draw_polyline(local, Color(1, 1, 1, 1.0), 2.0, true)
