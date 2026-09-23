extends "res://projectiles/projectile.gd"

var target: Node2D = null
var turn_rate: float = 6.0
var blast_radius: float = 30.0

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
