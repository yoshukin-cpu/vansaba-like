extends Node2D
## 宝箱から出る爆弾 (T03, SPEC §19.4)。武器 C06 の projectiles/bomb.gd とは別物。
## 取得できない。2.5秒のヒューズの後に爆発し、敵だけにダメージを与える。

const FUSE := 2.5
const BLAST_R := 140.0
const BLAST_DMG := 200.0
const SHARD_COUNT := 12
const SHARD_DMG := 40.0
const SHARD_RANGE := 400.0
const SHARD_SPEED := 520.0
const SHARD_HIT_R := 18.0

var age := 0.0
var exploded := false
var fade := 0.0
var shards: Array = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("item_bombs")

func _physics_process(delta: float) -> void:
	if not exploded:
		age += delta
		if sprite != null:
			var k: float = 4.0 + age * 6.0
			sprite.modulate.a = 0.4 + 0.6 * absf(sin(age * k))
		queue_redraw()
		if age >= FUSE:
			_explode()
		return
	_update_shards(delta)
	fade += delta
	queue_redraw()
	if shards.is_empty() and fade > 0.4:
		queue_free()

func _explode() -> void:
	exploded = true
	if sprite != null:
		sprite.visible = false
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var nn: Node2D = n as Node2D
		var away: Vector2 = nn.global_position - global_position
		if away.length() <= BLAST_R:
			if away.length() < 1.0:
				away = Vector2.RIGHT
			n.call("take_damage", BLAST_DMG, away.normalized() * 260.0, false)
	for i: int in range(SHARD_COUNT):
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(SHARD_COUNT))
		shards.append({"p": Vector2.ZERO, "d": d, "t": 0.0, "hit": {}})
	_audio().call("play", "explode")
	_fx().call("poof", global_position, Color(1.0, 0.6, 0.15), true)
	_fx().call("spark", global_position, Color(1, 1, 1, 1))

func _update_shards(delta: float) -> void:
	var step: float = SHARD_SPEED * delta
	for i: int in range(shards.size() - 1, -1, -1):
		var s: Dictionary = shards[i]
		s["p"] = (s["p"] as Vector2) + (s["d"] as Vector2) * step
		s["t"] = float(s["t"]) + step
		if float(s["t"]) >= SHARD_RANGE:
			shards.remove_at(i)
			continue
		var wp: Vector2 = global_position + (s["p"] as Vector2)
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			if not (n is Node2D):
				continue
			if bool(n.get("dead")):
				continue
			var nn: Node2D = n as Node2D
			if nn.global_position.distance_to(wp) > SHARD_HIT_R:
				continue
			var hit: Dictionary = s["hit"]
			var id: int = (n as Node).get_instance_id()
			if hit.has(id):
				continue
			hit[id] = true
			var away: Vector2 = nn.global_position - global_position
			if away.length() < 1.0:
				away = s["d"] as Vector2
			n.call("take_damage", SHARD_DMG, away.normalized() * 120.0, false)
		shards[i] = s

func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio")

func _fx() -> Node:
	return get_tree().get_first_node_in_group("combat_fx")

func _draw() -> void:
	if not exploded:
		# 警告円 (ヒューズが進むほど濃く)
		var k: float = clampf(age / FUSE, 0.0, 1.0)
		draw_arc(Vector2.ZERO, BLAST_R, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, 0.25 + 0.55 * k), 2.0, true)
	else:
		# 爆発フラッシュ
		var k2: float = clampf(fade / 0.4, 0.0, 1.0)
		draw_circle(Vector2.ZERO, BLAST_R * (0.4 + 0.6 * k2), Color(1.0, 0.6, 0.15, 0.5 * (1.0 - k2)))
		draw_circle(Vector2.ZERO, BLAST_R * k2, Color(1, 1, 1, 0.6 * (1.0 - k2)))
	for s: Dictionary in shards:
		draw_circle(s["p"] as Vector2, 4.0, Color(1.0, 0.7, 0.2, 1.0))
