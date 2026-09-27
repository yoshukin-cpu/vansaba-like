extends Node2D

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_level: int = 1
@export var level: int = 1
@export var cooldown: float = 1.0
@export var damage: float = 10.0

var timer: float = 0.0
var player: Node2D = null
var _audio: Node = null

func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not ("aim_direction" in n):
		n = n.get_parent()
	player = n as Node2D
	timer = cooldown * 0.5

func _process(delta: float) -> void:
	if player != null and bool(player.get("dead")):
		return
	timer += delta
	if timer >= get_cooldown():
		timer = 0.0
		try_fire()

func try_fire() -> void:
	if weapon_id == "C02" or weapon_id == "C03" or weapon_id == "C06":
		_audio_play("shoot")
	fire()

func _audio_play(sname: String) -> void:
	if _audio == null or not is_instance_valid(_audio):
		_audio = get_tree().get_first_node_in_group("audio")
	if _audio != null:
		_audio.call("play", sname)

func fire() -> void:
	pass

func upgrade() -> void:
	weapon_level = mini(8, weapon_level + 1)

func get_effective_damage() -> float:
	if player != null:
		return damage * pstat("attack_mult", 1.0) * pstat("buff_attack", 1.0)
	return damage

func get_cooldown() -> float:
	if player != null:
		return cooldown * pstat("cooldown_mult", 1.0) * pstat("buff_cd", 1.0)
	return cooldown

func pstat(n: String, d: float) -> float:
	if player != null:
		return float(player.get(n))
	return d

func roll_damage() -> float:
	var dmg := get_effective_damage()
	if randf() < pstat("crit_chance", 0.0):
		return dmg * pstat("crit_mult", 2.0)
	return dmg

func roll_hit() -> Array:
	var crit: bool = randf() < pstat("crit_chance", 0.0)
	var dmg := get_effective_damage()
	if crit:
		dmg *= pstat("crit_mult", 2.0)
	return [dmg, crit]

func ammo_pool(group_name: String) -> Node:
	if player == null:
		return null
	var pool: Node = get_tree().get_first_node_in_group(group_name)
	return pool

func kb_mult() -> float:
	return pstat("knockback_mult", 1.0)

## オートエイムの探索射程 (D70)。C02/C03 は実効射程 (弾速×寿命) で上書きする。
## 射程外の敵を狙って必ず外す撃ち方をなくすため。
func aim_range() -> float:
	return 900.0

func get_fire_direction() -> Vector2:
	var joy: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if joy.length() > 0.2:
		return joy.normalized()
	if player != null and player.has_method("is_mouse_aim_fresh") and bool(player.call("is_mouse_aim_fresh")):
		return (player.get("aim_direction") as Vector2)
	var near: Node2D = find_nearest_enemy(aim_range(), true)
	if near != null and player != null:
		var d: Vector2 = near.global_position - player.global_position
		if d.length() > 1.0:
			return d.normalized()
	if player != null:
		return (player.get("aim_direction") as Vector2)
	return Vector2.RIGHT

## 射程内に敵がいない場合のみ、宝箱 (chests) を対象にする (SPEC §19.2)。
## チェインライトニングは敵専用のため with_chests=false のまま呼ぶ。
func find_nearest_enemy(max_range: float, with_chests: bool = false) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	if player == null:
		return null
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var d: float = ((n as Node2D).global_position - player.global_position).length()
		if d < best_d:
			best_d = d
			best = n as Node2D
	if best != null or not with_chests:
		return best
	for n: Node in get_tree().get_nodes_in_group("chests"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var d2: float = ((n as Node2D).global_position - player.global_position).length()
		if d2 < best_d:
			best_d = d2
			best = n as Node2D
	return best
