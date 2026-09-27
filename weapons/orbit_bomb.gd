extends "res://weapons/weapon_base.gd"

const BombScript := preload("res://projectiles/bomb.gd")

const COUNT_TABLE := [1, 1, 1, 2, 2, 2, 3, 3]
const DMG_TABLE := [30.0, 38.0, 46.0, 54.0, 62.0, 70.0, 80.0, 90.0]

@export var blast_radius: float = 90.0
@export var throw_range: float = 420.0
## D47: 目標がこれより近い場合は押し出して投下する (足元爆発の回避)。
const MIN_THROW_DIST := 160.0

func _ready() -> void:
	super._ready()
	weapon_id = "C06"
	weapon_name = "Orbit Bomb"
	cooldown = 3.0
	damage = DMG_TABLE[0]
	timer = 2.2

func upgrade() -> void:
	super.upgrade()
	damage = DMG_TABLE[clampi(weapon_level - 1, 0, 7)]

func base_count() -> int:
	return COUNT_TABLE[clampi(weapon_level - 1, 0, 7)]

func fire() -> void:
	if player == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var n: int = base_count() + int(pstat("bonus_projectiles", 0.0))
	var dir: Vector2 = get_fire_direction()
	var rh: Array = roll_hit()
	var dmg: float = rh[0]
	var crit: bool = rh[1]
	var radius: float = blast_radius * pstat("area_mult", 1.0)
	var used := {}
	for i: int in range(n):
		var to: Vector2 = _pick_target(dir, i, n, radius, used)
		var b := Area2D.new()
		b.set_script(BombScript)
		scene.add_child(b)
		b.call("setup", player.global_position, to, dmg, radius, kb_mult())
		b.set("crit_hit", crit)

## D47+D48: 投下点の決定。使用済み目標は除外して別目標を拾い、
## 目標が足りない分は第1目標の周囲にリング分散する。近すぎる目標は最低距離まで押し出す。
func _pick_target(dir: Vector2, idx: int, total: int, blast: float, used: Dictionary) -> Vector2:
	var tgt: Node2D = _find_unused(throw_range, used)
	if tgt == null:
		if used.is_empty():
			return player.global_position + dir.rotated((float(idx) - float(total - 1) / 2.0) * 0.3) * throw_range * 0.75
		var first_pos: Vector2 = used["first_pos"]
		var ang: float = TAU * float(idx) / float(total)
		return first_pos + Vector2.RIGHT.rotated(ang) * blast * 0.7
	used[tgt.get_instance_id()] = true
	if not used.has("first_pos"):
		used["first_pos"] = tgt.global_position
	var d: Vector2 = tgt.global_position - player.global_position
	var dist: float = d.length()
	if dist < MIN_THROW_DIST:
		var push: Vector2 = d / maxf(dist, 1.0) if dist > 1.0 else dir
		return player.global_position + push * MIN_THROW_DIST
	return tgt.global_position

## find_nearest_enemy (with_chests) の使用済み除外版。
func _find_unused(max_range: float, used: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	if player == null:
		return null
	for en: Node in get_tree().get_nodes_in_group("enemies"):
		if not (en is Node2D):
			continue
		if bool(en.get("dead")):
			continue
		if used.has((en as Node).get_instance_id()):
			continue
		var dd: float = ((en as Node2D).global_position - player.global_position).length()
		if dd < best_d:
			best_d = dd
			best = en as Node2D
	if best != null:
		return best
	for ch: Node in get_tree().get_nodes_in_group("chests"):
		if not (ch is Node2D):
			continue
		if bool(ch.get("dead")):
			continue
		if used.has((ch as Node).get_instance_id()):
			continue
		var dd2: float = ((ch as Node2D).global_position - player.global_position).length()
		if dd2 < best_d:
			best_d = dd2
			best = ch as Node2D
	return best
