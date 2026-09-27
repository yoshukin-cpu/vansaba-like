extends "res://weapons/weapon_base.gd"

const LightningFxScript := preload("res://weapons/lightning_fx.gd")

const CHAIN_TABLE := [3, 3, 4, 4, 5, 6, 7, 8]
const DMG_TABLE := [15.0, 18.0, 22.0, 26.0, 30.0, 34.0, 37.0, 40.0]

@export var strike_range: float = 500.0
@export var jump_range: float = 260.0

func _ready() -> void:
	super._ready()
	weapon_id = "C04"
	weapon_name = "Chain Lightning"
	cooldown = 2.5
	damage = DMG_TABLE[0]
	timer = 1.6

func upgrade() -> void:
	super.upgrade()
	damage = DMG_TABLE[clampi(weapon_level - 1, 0, 7)]

func chain_count() -> int:
	return CHAIN_TABLE[clampi(weapon_level - 1, 0, 7)]

func fire() -> void:
	if player == null:
		return
	_audio_play("zap")
	var first: Node2D = find_nearest_enemy(strike_range)
	if first == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var current: Node2D = first
	var from: Vector2 = player.global_position
	var pts := PackedVector2Array([from])
	var rh: Array = roll_hit()
	var dmg: float = rh[0]
	var crit: bool = rh[1]
	var kb: float = kb_mult()
	var hit: Array = []
	for i: int in range(chain_count()):
		if current == null:
			break
		hit.append(current.get_instance_id())
		pts.append(current.global_position)
		var away: Vector2 = current.global_position - from
		if away.length() < 1.0:
			away = Vector2.RIGHT
		current.call("take_damage", dmg, away.normalized() * 100.0 * kb, crit)
		_burst(current.global_position, i)
		from = current.global_position
		current = _next_target(from, hit)
	var fx := Node2D.new()
	fx.set_script(LightningFxScript)
	scene.add_child(fx)
	fx.global_position = Vector2.ZERO
	# D59: 線の太さはLvで増える (Lv1:1.0 → Lv8:2.05。演出のみ、判定は不変)。
	fx.call("setup", pts, 1.0 + 0.15 * float(weapon_level - 1))

## D56: 被弾点のバースト (Lvで数・大きさが増える)。演出のみ。
func _burst(pos: Vector2, idx: int) -> void:
	var fx: Node = get_tree().get_first_node_in_group("combat_fx")
	if fx == null:
		return
	var count: int = 2 + weapon_level / 2
	for i: int in range(count):
		fx.call("spark", pos + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0)), Color(0.7, 0.95, 1.0, 1.0))
	if idx % 3 == 2:
		fx.call("poof", pos, Color(0.7, 0.95, 1.0), weapon_level >= 6)

func _next_target(from: Vector2, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = jump_range
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		if exclude.has((n as Node).get_instance_id()):
			continue
		var d: float = ((n as Node2D).global_position - from).length()
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best
