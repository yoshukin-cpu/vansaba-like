extends "res://projectiles/projectile.gd"

var target: Node2D = null
var turn_rate: float = 6.0
var blast_radius: float = 30.0
## D55: 煙トレイル (半透明でだんだん消える。Lvで大きくなる)。演出のみ。
var trail_scale: float = 1.0
var smoke_timer: float = 0.0
var smokes: Array = []
const SMOKE_INTERVAL := 0.05
const SMOKE_LIFE := 0.4
const SMOKE_MAX := 24

func _process(delta: float) -> void:
	_update_smokes(delta)
	if not active:
		return
	smoke_timer += delta
	if smoke_timer < SMOKE_INTERVAL:
		return
	smoke_timer = 0.0
	_spawn_smoke()

func _smoke_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(8):
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 8.0) * r)
	return pts

func _spawn_smoke() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var s := Polygon2D.new()
	s.polygon = _smoke_poly(6.0 * trail_scale)
	s.color = Color(0.62, 0.62, 0.66, 0.35)
	parent.add_child(s)
	s.global_position = global_position - direction * 10.0
	smokes.append({"node": s, "age": 0.0})
	while smokes.size() > SMOKE_MAX:
		var old: Dictionary = smokes.pop_front()
		var on: Node = old["node"]
		if is_instance_valid(on):
			on.queue_free()

func _update_smokes(delta: float) -> void:
	var alive: Array = []
	for sm: Dictionary in smokes:
		var sn: Node = sm["node"]
		if sn == null or not is_instance_valid(sn):
			continue
		var age: float = float(sm["age"]) + delta
		if age >= SMOKE_LIFE:
			(sn as Node).queue_free()
			continue
		var k: float = age / SMOKE_LIFE
		(sn as Polygon2D).modulate.a = 0.35 * (1.0 - k)
		var sc: float = 1.0 + 0.6 * k
		(sn as Node2D).scale = Vector2(sc, sc)
		sm["age"] = age
		alive.append(sm)
	smokes = alive

func _physics_process(delta: float) -> void:
	if not active:
		return
	if target != null and (not is_instance_valid(target) or bool(target.get("dead"))):
		target = null
	if target == null:
		target = _find_nearest(700.0)
	if target != null:
		var want: Vector2 = target.global_position - global_position
		if want.length() > 1.0:
			direction = direction.lerp(want.normalized(), clampf(turn_rate * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle()
	super._physics_process(delta)

func _find_nearest(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var d: float = ((n as Node2D).global_position - global_position).length()
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best

func _on_area_entered(area: Area2D) -> void:
	var enemy: Node = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage"):
		return
	if bool(enemy.get("dead")):
		return
	var id: int = enemy.get_instance_id()
	if hit_set.has(id):
		return
	hit_set[id] = true
	var r: float = blast_radius
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var nn: Node2D = n as Node2D
		if nn.global_position.distance_to(global_position) <= r:
			var away: Vector2 = nn.global_position - global_position
			if away.length() < 1.0:
				away = direction
			n.call("take_damage", damage, away.normalized() * 120.0 * kb_scale, crit_hit)
	_despawn()
