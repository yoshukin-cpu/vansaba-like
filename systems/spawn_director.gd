extends Node

const WavesDB := preload("res://data/waves_db.gd")

@export var spawn_radius: float = 780.0

var elapsed: float = 0.0
var timer: float = 1.0
var next_elite_at: float = 120.0
var running: bool = true
var boss1_spawned: bool = false
var boss2_spawned: bool = false

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if not boss1_spawned and elapsed >= 300.0:
		boss1_spawned = true
		_spawn_boss("res://enemies/boss_golem_king.tscn", "WARNING: Golem King")
		return
	if not boss2_spawned and elapsed >= 600.0:
		boss2_spawned = true
		_spawn_boss("res://enemies/boss_void_emperor.tscn", "WARNING: Void Emperor")
		return
	var b: Dictionary = WavesDB.band(elapsed)
	timer -= delta
	if timer > 0.0:
		return
	timer = float(b["interval"])
	if get_tree().get_nodes_in_group("enemies").size() >= int(b["cap"]):
		return
	if elapsed >= next_elite_at:
		while elapsed >= next_elite_at:
			next_elite_at += 120.0
		_spawn_elite()
		return
	var batch: Array = b["batch"] as Array
	var n: int = randi_range(int(batch[0]), int(batch[1]))
	for i: int in range(n):
		_spawn_one(str(WavesDB.pick(b["weights"] as Array)), false)

func _player_pos() -> Vector2:
	var ps: Array[Node] = get_tree().get_nodes_in_group("player")
	if ps.size() > 0 and ps[0] is Node2D:
		return (ps[0] as Node2D).global_position
	return Vector2.ZERO

func _spawn_pos() -> Vector2:
	var p: Vector2 = _player_pos() + Vector2.RIGHT.rotated(randf() * TAU) * spawn_radius
	# 障害物の上には湧かせない (SPEC §18.4)
	var w: Node = get_tree().get_first_node_in_group("world")
	if w != null and w.has_method("find_free"):
		return w.call("find_free", p) as Vector2
	return p

func _spawn_one(path: String, elite: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var scn: PackedScene = load(path) as PackedScene
	if scn == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var e: Node = scn.instantiate()
	scene.add_child(e)
	(e as Node2D).global_position = _spawn_pos()
	if elapsed >= 480.0:
		e.call("apply_scaling", 2.0, 1.2)
	elif elapsed >= 300.0:
		e.call("apply_scaling", 1.5, 1.0)
	if elite:
		e.call("make_elite")

func _spawn_elite() -> void:
	_spawn_one(str(WavesDB.pick((WavesDB.band(elapsed)["weights"]) as Array)), true)

func _spawn_boss(path: String, warn_text: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var scn: PackedScene = load(path) as PackedScene
	if scn == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var boss: Node = scn.instantiate()
	scene.add_child(boss)
	(boss as Node2D).global_position = _spawn_pos()
	var game: Node = get_tree().get_first_node_in_group("game")
	if game != null:
		game.call("show_warning", warn_text)
