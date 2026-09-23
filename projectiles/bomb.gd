extends Area2D

var target: Vector2 = Vector2.ZERO
var start: Vector2 = Vector2.ZERO
var damage: float = 30.0
var blast_radius: float = 90.0
var kb_scale: float = 1.0
var crit_hit: bool = false
var flight_time: float = 0.45
var age: float = 0.0
var exploded: bool = false
var fade: float = 0.0

func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 4
	collision_mask = 0
	monitoring = false

func setup(from: Vector2, to: Vector2, dmg: float, radius: float, kb: float) -> void:
	start = from
	target = to
	damage = dmg
	blast_radius = radius
	kb_scale = kb
	global_position = from
	queue_redraw()

func _physics_process(delta: float) -> void:
	if exploded:
		return
	age += delta
	var t: float = clampf(age / flight_time, 0.0, 1.0)
	global_position = start.lerp(target, t)
	queue_redraw()
	if t >= 1.0:
		_explode()

func _process(delta: float) -> void:
	if not exploded:
		return
	fade += delta
	queue_redraw()
	if fade > 0.3:
		queue_free()

func _explode() -> void:
	exploded = true
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var nn: Node2D = n as Node2D
		if nn.global_position.distance_to(target) <= blast_radius:
			var away: Vector2 = nn.global_position - target
			if away.length() < 1.0:
				away = Vector2.RIGHT
			n.call("take_damage", damage, away.normalized() * 260.0 * kb_scale, crit_hit)

func _draw() -> void:
	if not exploded:
		draw_circle(Vector2.ZERO, 10.0, Color(0.15, 0.15, 0.2, 1.0))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.6, 0.1, 0.35))
		draw_circle(Vector2(0, -12), 3.0, Color(1.0, 0.85, 0.3, 1.0))
	else:
		var k: float = clampf(fade / 0.3, 0.0, 1.0)
		draw_circle(Vector2.ZERO, blast_radius * (0.4 + 0.6 * k), Color(1.0, 0.6, 0.15, 0.5 * (1.0 - k)))
		draw_circle(Vector2.ZERO, blast_radius * k, Color(1, 1, 1, 0.6 * (1.0 - k)))
