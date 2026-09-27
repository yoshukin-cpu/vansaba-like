extends Area2D

const COLLECT_RADIUS := 22.0
const ATTRACT_INITIAL_SPEED := 180.0
const ATTRACT_MAX_SPEED := 600.0
const ATTRACT_ACCEL := 1500.0
const FALLBACK_MAGNET_RADIUS := 110.0

## 経験値量による3段階色 (D35): 1=緑 / 5=赤 / 20=白。
const TIER_SMALL := Color(0.30, 1.00, 0.40)
const TIER_MID := Color(1.00, 0.32, 0.26)
const TIER_BIG := Color(1.00, 1.00, 1.00)
## きらめき (金色の十字) の周期・点灯時間・本体の拡縮。
const SPARKLE_PERIOD := 1.4
const SPARKLE_TIME := 0.2
const SPARKLE_POP := 0.12

@export var value: int = 1:
	set(v):
		value = v
		_refresh_visual()

var attracted: bool = false
var attract_speed: float = ATTRACT_INITIAL_SPEED
var active: bool = true
var home_pool: Node = null
var sparkle_phase: float = 0.0

@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual
@onready var sparkle: Polygon2D = $Sparkle

func _ready() -> void:
	add_to_group("gems")
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	sparkle.modulate.a = 0.0
	_refresh_visual()

## 値 → 色 (低→高で 緑→赤→白。D35)。
static func color_for_value(v: int) -> Color:
	if v >= 20:
		return TIER_BIG
	if v >= 5:
		return TIER_MID
	return TIER_SMALL

## 色の反映。setter はシーン読込順で子ノードより先に走るためガードする。
func _refresh_visual() -> void:
	if not is_node_ready() or visual == null:
		return
	visual.color = color_for_value(value)

## きらめき (D35): 約1.4秒ごとに0.2秒だけ金色の十字が光り、本体が一瞬膨らむ。
func _process(delta: float) -> void:
	if not active or sparkle == null:
		return
	sparkle_phase += delta
	var t: float = fmod(sparkle_phase, SPARKLE_PERIOD)
	if t < SPARKLE_TIME:
		var a: float = sin(t / SPARKLE_TIME * PI)
		sparkle.modulate.a = a
		sparkle.scale = Vector2.ONE * (0.6 + 0.6 * a)
		visual.scale = Vector2.ONE * (1.0 + SPARKLE_POP * a)
	else:
		sparkle.modulate.a = 0.0
		sparkle.scale = Vector2.ONE
		visual.scale = Vector2.ONE

func activate() -> void:
	active = true
	visible = true
	attracted = false
	attract_speed = ATTRACT_INITIAL_SPEED
	sparkle_phase = randf() * SPARKLE_PERIOD
	_refresh_visual()
	set_deferred("monitorable", true)
	shape_node.set_deferred("disabled", false)

func deactivate() -> void:
	active = false
	visible = false
	attracted = false
	attract_speed = ATTRACT_INITIAL_SPEED
	if sparkle != null:
		sparkle.modulate.a = 0.0
		sparkle.scale = Vector2.ONE
	if visual != null:
		visual.scale = Vector2.ONE
	set_deferred("monitorable", false)
	# プール待機中はコリジョンを無効化する。原点などに重なったまま残すと
	# マグネット側の重複ペアが古い状態で保持され、再利用時に吸い寄せが
	# 発火しない(エリアの entered が来ない)不具合の原因になる。
	shape_node.set_deferred("disabled", true)

func attract() -> void:
	attracted = true
	attract_speed = ATTRACT_INITIAL_SPEED

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
		attract_speed = ATTRACT_INITIAL_SPEED
	var d: Vector2 = p.global_position - global_position
	if d.length() < COLLECT_RADIUS:
		p.call("add_xp", value)
		var audio: Node = get_tree().get_first_node_in_group("audio")
		if audio != null:
			audio.call("play", "gem")
		_despawn()
		return
	# 吸い寄せはゆっくり始まって徐々に加速する
	attract_speed = minf(ATTRACT_MAX_SPEED, attract_speed + ATTRACT_ACCEL * delta)
	global_position = global_position.move_toward(p.global_position, attract_speed * delta)

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
