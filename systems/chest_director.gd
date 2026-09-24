extends Node
## 宝箱の出現・開封・中身の適用を管理する (SPEC §19)。
## 出現: 15秒間隔 (初回30秒、ラッシュ中5秒)。位置はプレイヤーから
## 320〜540px のリング上かつ画面内 (|dx|≤520, |dy|≤300)。障害物は避ける。
## 寿命30秒・同時上限4個 (超えたら最古を静かに消す)。

const ItemsDB := preload("res://data/items_db.gd")
const CardsDB := preload("res://data/cards_db.gd")
const ChestScene: PackedScene = preload("res://objects/chest.tscn")
const ItemBombScene: PackedScene = preload("res://objects/bomb.tscn")
const GEM_SCENE: PackedScene = preload("res://pickups/xp_gem.tscn")

const NORMAL_INTERVAL := 15.0
const RUSH_INTERVAL := 5.0
const FIRST_DELAY := 30.0
const RING_MIN := 320.0
const RING_MAX := 540.0
const MAX_DX := 520.0
const MAX_DY := 300.0
const MAX_CHESTS := 4
const VACUUM_RANGE := 1500.0
const RUSH_TIME := 15.0
const BUFF_TIME := 10.0
const GUARD_TIME := 3.0

var running := false
var timer := FIRST_DELAY
var rush_time := 0.0
var chests: Array = []

func _ready() -> void:
	add_to_group("chest_director")

func _process(delta: float) -> void:
	if not running:
		return
	if rush_time > 0.0:
		rush_time -= delta
	timer -= delta
	if timer > 0.0:
		return
	timer = RUSH_INTERVAL if rush_time > 0.0 else NORMAL_INTERVAL
	if _player_alive():
		spawn_chest()

func spawn_chest() -> Node:
	_prune()
	while chests.size() >= MAX_CHESTS:
		var oldest: Node = chests.pop_front()
		if is_instance_valid(oldest):
			oldest.call("expire_silent")
	return spawn_chest_at(_pick_pos())

func spawn_chest_at(pos: Vector2) -> Node:
	var c: Node = ChestScene.instantiate()
	var scene: Node = get_tree().current_scene
	scene.add_child(c)
	(c as Node2D).global_position = pos
	c.call("setup", self)
	chests.append(c)
	_audio().call("play", "pop")
	return c

## 宝箱が開かれたときに呼ばれる。抽選して適用する。
func open_chest(chest: Node) -> void:
	var pos: Vector2 = (chest as Node2D).global_position
	apply_item(ItemsDB.roll(), pos)

func apply_item(item_id: String, pos: Vector2) -> String:
	var p: Node = _player()
	match item_id:
		"T01":
			if p != null:
				if float(p.get("hp")) >= float(p.get("max_hp")):
					_spawn_gem(pos, 1)
				else:
					p.call("heal", 35.0)
					_fx().call("damage_number", pos, 35.0, false)
			_fx().call("spark", pos, Color(0.3, 1.0, 0.4, 1.0))
			_audio().call("play", "heal")
		"T02":
			_game().call("add_score", 100)
			_fx().call("damage_number", pos, 100.0, false)
			_fx().call("spark", pos, Color(1.0, 0.85, 0.2, 1.0))
			_audio().call("play", "coin")
		"R_COIN":
			_game().call("add_score", 1000)
			_fx().call("damage_number", pos, 1000.0, false)
			_fx().call("spark", pos, Color(1.0, 0.85, 0.2, 1.0))
			_audio().call("play", "coin")
		"T03":
			var b: Node = ItemBombScene.instantiate()
			get_tree().current_scene.add_child(b)
			(b as Node2D).global_position = pos
			_audio().call("play", "pop")
		"T04":
			var sp: Node = _spawner()
			if sp != null:
				sp.call("spawn_around", pos, randi_range(6, 10))
			_game().call("show_warning", "敵の奇襲!")
		"T05":
			for i: int in range(3):
				_spawn_gem(pos + _ring(30.0, 70.0), 5)
			for i: int in range(5):
				_spawn_gem(pos + _ring(30.0, 70.0), 1)
			_fx().call("spark", pos, Color(0.4, 0.8, 1.0, 1.0))
			_audio().call("play", "coin")
		"T06":
			if p != null:
				var kinds := ["attack", "haste", "swift", "guard"]
				p.call("apply_buff", str(kinds[randi() % kinds.size()]))
			_fx().call("spark", pos, Color(0.5, 1.0, 1.0, 1.0))
			_audio().call("play", "buff")
		"T07":
			for n: Node in get_tree().get_nodes_in_group("gems"):
				if not (n is Node2D):
					continue
				if not bool(n.get("active")):
					continue
				if (n as Node2D).global_position.distance_to(pos) <= VACUUM_RANGE:
					n.call("attract")
			_audio().call("play", "pop")
		"T08":
			rush_time = RUSH_TIME
			_game().call("show_warning", "宝箱ラッシュ!")
		"T09", "R_WEAPON":
			if not _upgrade_weapon():
				return apply_item("T02", pos)
			_fx().call("spark", pos, Color(1.0, 0.6, 0.2, 1.0))
			_audio().call("play", "buff")
		"R_HEAL":
			if p != null:
				p.call("heal", float(p.get("max_hp")))
				_fx().call("damage_number", pos, float(p.get("max_hp")), false)
			_fx().call("spark", pos, Color(0.3, 1.0, 0.4, 1.0))
			_audio().call("play", "heal")
	_audio().call("play", "chest")
	return item_id

## 取得済み武器からランダムに1つ強化する。対象がなければ false。
func _upgrade_weapon() -> bool:
	var cards: Node = _cards()
	var p: Node = _player()
	if cards == null or p == null:
		return false
	var cands: Array = []
	for cid: String in CardsDB.WEAPON_IDS:
		var w: Node = cards.call("weapon_by_id", cid)
		if w != null and int(w.get("weapon_level")) < CardsDB.WEAPON_MAX_LEVEL:
			cands.append(w)
	if cands.is_empty():
		return false
	var w2: Node = cands[randi() % cands.size()]
	w2.call("upgrade")
	return true

func _spawn_gem(pos: Vector2, value: int) -> void:
	var pool: Node = get_tree().get_first_node_in_group("pool_gems")
	var g: Area2D
	if pool != null:
		g = pool.call("acquire") as Area2D
		if g == null:
			return
	else:
		g = GEM_SCENE.instantiate() as Area2D
		get_tree().current_scene.add_child(g)
	g.global_position = pos
	g.set("value", value)

func _ring(rmin: float, rmax: float) -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(rmin, rmax)

func _pick_pos() -> Vector2:
	var pp: Vector2 = _player_pos()
	var fallback: Vector2 = pp + Vector2(RING_MIN, 0.0)
	var w: Node = get_tree().get_first_node_in_group("world")
	for i: int in range(8):
		var p: Vector2 = pp + _ring(RING_MIN, RING_MAX)
		var d: Vector2 = p - pp
		d.x = clampf(d.x, -MAX_DX, MAX_DX)
		d.y = clampf(d.y, -MAX_DY, MAX_DY)
		p = pp + d
		if w != null and w.has_method("is_blocked"):
			if bool(w.call("is_blocked", p)):
				continue
		return p if w == null else w.call("find_free", p)
	return fallback

func _prune() -> void:
	var alive: Array = []
	for c: Node in chests:
		if is_instance_valid(c):
			alive.append(c)
	chests = alive

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _player_alive() -> bool:
	var p: Node = _player()
	return p != null and not bool(p.get("dead"))

func _player_pos() -> Vector2:
	var p: Node = _player()
	if p != null and p is Node2D:
		return (p as Node2D).global_position
	return Vector2.ZERO

func _game() -> Node:
	return get_tree().get_first_node_in_group("game")

func _cards() -> Node:
	var sc: Node = get_tree().current_scene
	if sc != null and sc.has_node("CardManager"):
		return sc.get_node("CardManager")
	return null

func _spawner() -> Node:
	var sc: Node = get_tree().current_scene
	if sc != null and sc.has_node("SpawnDirector"):
		return sc.get_node("SpawnDirector")
	return null

func _fx() -> Node:
	return get_tree().get_first_node_in_group("combat_fx")

func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio")
