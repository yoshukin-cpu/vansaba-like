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

## シーン構築中の事前生成。直接追加で安全 (フラッシュ中ではない)。
func _make(scn: PackedScene) -> void:
	var n: Node = scn.instantiate()
	add_child(n)
	n.set("home_pool", self)
	n.call("deactivate")
	free_list.append(n)
	total += 1

func acquire() -> Node:
	if free_list.is_empty():
		_grow()
		if free_list.is_empty():
			# 成長分は遅延追加のため次のフレーム以降に利用可能。
			# 呼び出し側は null を許容する (その発射・出現を1回見送る)。
			return null
	var n: Node = free_list.pop_back()
	n.call("activate")
	return n

## 実行時の成長。キル経路 (物理フラッシュ中) から呼ばれるため、
## add_child は直接できず遅延する ("Can't change this state while flushing queries")。
func _grow() -> void:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var scn: PackedScene = load(scene_path) as PackedScene
	for i: int in range(16):
		var n: Node = scn.instantiate()
		n.set("home_pool", self)
		_finish_make.call_deferred(n)

func _finish_make(n: Node) -> void:
	add_child(n)
	n.call("deactivate")
	free_list.append(n)
	total += 1

func release(n: Node) -> void:
	if not is_instance_valid(n):
		return
	n.call("deactivate")
	free_list.append(n)

func stats() -> Dictionary:
	return {"total": total, "free": free_list.size(), "active": total - free_list.size()}
