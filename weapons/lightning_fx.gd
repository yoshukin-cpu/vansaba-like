extends Node2D

var points: PackedVector2Array = PackedVector2Array()
var age: float = 0.0
var lifetime: float = 0.25
## D59: 線の太さ係数 (Lvで太くなる)。演出のみ (判定・ダメージは武器側)。
var thickness: float = 1.0
const WIDTH_OUTER := 5.0
const WIDTH_CORE := 2.0

func setup(pts: PackedVector2Array, thick: float = 1.0) -> void:
	points = pts
	thickness = maxf(0.1, thick)
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
	draw_polyline(local, Color(0.7, 0.95, 1.0, 1.0), WIDTH_OUTER * thickness, true)
	draw_polyline(local, Color(1, 1, 1, 1.0), WIDTH_CORE * thickness, true)
