extends Area2D

@export var value: int = 1

var attracted: bool = false
var active: bool = true
var home_pool: Node = null
var idle_age: float = 0.0

func _ready() -> void:
	add_to_group("gems")
	collision_layer = 16
	collision_mask = 0
	monitoring = false

func activate() -> void:
	active = true
	visible = true
	attracted = false
	idle_age = 0.0
	set_deferred("monitorable", true)

func deactivate() -> void:
	active = false
	visible = false
	attracted = false
	set_deferred("monitorable", false)

func attract() -> void:
	attracted = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not attracted:
		idle_age += delta
		if idle_age > 12.0:
			attracted = true
		else:
			return
	var p: Node2D = _find_player()
	if p == null:
		return
	var d: Vector2 = p.global_position - global_position
	if d.length() < 22.0:
		p.call("add_xp", value)
		_despawn()
		return
	global_position = global_position.move_toward(p.global_position, 600.0 * delta)

func _despawn() -> void:
	if home_pool != null and is_instance_valid(home_pool):
		home_pool.call("release", self)
	else:
		queue_free()

func _find_player() -> Node2D:
	var ps: Array[Node] = get_tree().get_nodes_in_group("player")
	if ps.size() > 0 and ps[0] is Node2D:
		var p: Node = ps[0]
		if bool(p.get("dead")):
			return null
		return ps[0] as Node2D
	return null
