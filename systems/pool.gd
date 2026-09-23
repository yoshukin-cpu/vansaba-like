extends Node

@export var scene_path: String = ""
@export var prewarm: int = 64
@export var pool_id: String = ""

var free_list: Array = []
var total: int = 0

func _ready() -> void:
	add_to_group("pool")
	if pool_id != "":
		add_to_group(pool_id)
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var scn: PackedScene = load(scene_path) as PackedScene
	for i: int in range(prewarm):
		_make(scn)

func _make(scn: PackedScene) -> void:
	var n: Node = scn.instantiate()
	add_child(n)
	n.set("home_pool", self)
	n.call("deactivate")
	free_list.append(n)
	total += 1

func acquire() -> Node:
	if free_list.is_empty():
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			return null
		var scn: PackedScene = load(scene_path) as PackedScene
		for i: int in range(16):
			_make(scn)
	var n: Node = free_list.pop_back()
	n.call("activate")
	return n

func release(n: Node) -> void:
	if not is_instance_valid(n):
		return
	n.call("deactivate")
	free_list.append(n)

func stats() -> Dictionary:
	return {"total": total, "free": free_list.size(), "active": total - free_list.size()}
