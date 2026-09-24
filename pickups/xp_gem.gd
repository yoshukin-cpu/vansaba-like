extends Area2D

@export var value: int = 1

const COLLECT_RADIUS := 22.0
const ATTRACT_SPEED := 600.0
const FALLBACK_MAGNET_RADIUS := 110.0

var attracted: bool = false
var active: bool = true
var home_pool: Node = null

@onready var shape_node: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("gems")
	collision_layer = 16
	collision_mask = 0
	monitoring = false

func activate() -> void:
	active = true
	visible = true
	attracted = false
	set_deferred("monitorable", true)
	shape_node.set_deferred("disabled", false)

func deactivate() -> void:
	active = false
	visible = false
	attracted = false
	set_deferred("monitorable", false)
	# プール待機中はコリジョンを無効化する。原点などに重なったまま残すと
	# マグネット側の重複ペアが古い状態で保持され、再利用時に吸い寄せが
	# 発火しない(エリアの entered が来ない)不具合の原因になる。
	shape_node.set_deferred("disabled", true)

func attract() -> void:
	attracted = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	var p: Node2D = _find_player()
	if p == null:
		return
	# 吸い寄せは取得範囲(マグネット半径)内に入ったときのみ。
	# 範囲外に落ちたジェムはその場に残る(取りに行かないと回収できない)。
	if not attracted:
		if global_position.distance_squared_to(p.global_position) > _magnet_range_sq(p):
			return
		attracted = true
	var d: Vector2 = p.global_position - global_position
	if d.length() < COLLECT_RADIUS:
		p.call("add_xp", value)
		_despawn()
		return
	global_position = global_position.move_toward(p.global_position, ATTRACT_SPEED * delta)

func _magnet_range_sq(p: Node) -> float:
	var r: float = FALLBACK_MAGNET_RADIUS
	if p.has_method("magnet_radius"):
		r = float(p.call("magnet_radius"))
	return r * r

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
