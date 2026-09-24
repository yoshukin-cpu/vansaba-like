extends SceneTree
## 見た目確認: 放射状スピン + 飛び出すアイテム + T09ポップアップを撮影する。
## 実行: godot --path <project> --script res://tools/verify_feedback_look.gd

const MainScene: PackedScene = preload("res://main.tscn")
const OUT_DIR := "res://tmp_shots/"

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	await process_frame
	await process_frame
	var player: Node2D = main.get_node("Player")
	var director: Node = main.get_node("ChestDirector")
	var fx: Node = get_first_node_in_group("combat_fx")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	director.set("running", false)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame
	# スピン3本 (Lv8相当) にして放射を確認
	var w: Node = player.get_node("Weapons/Weapon_C01")
	for i: int in range(7):
		w.call("upgrade")
	_check("3 blades", (w.get("blades") as Array).size() == 3)
	# 刃の向きが放射状か (各刃の rotation が位置角度と一致)
	var radial := true
	for bl: Node in (w.get("blades") as Array):
		var b2 := bl as Node2D
		var want: float = b2.position.angle()
		var d: float = absf(wrapf(b2.rotation - want, -PI, PI))
		if d > 0.01:
			radial = false
	_check("blades radial", radial)
	for i: int in range(30):
		await process_frame
	# アイテムを飛ばして空中ショット
	director.call("spawn_item", "T06", player.global_position + Vector2(150, 0), false)
	for i: int in range(6):
		await process_frame
	var items: Array = get_nodes_in_group("items")
	_check("item flying mid-air", not items.is_empty() and bool(items[0].get("flying")))
	await _shot("fb_fly.png")
	for i: int in range(90):
		if not items.is_empty() and is_instance_valid(items[0]) and not bool(items[0].get("flying")):
			break
		await process_frame
	_check("item landed", not items.is_empty() and is_instance_valid(items[0]) and not bool(items[0].get("flying")))
	# T09ポップアップを出して撮影
	director.call("apply_item", "T09", player.global_position + Vector2(0, -60))
	for i: int in range(5):
		await process_frame
	_check("popupQueued", (fx.get("nums") as Array).size() > 0)
	await _shot("fb_popup.png")
	# 宝箱を開けて即時爆弾が出ることを撮影
	director.call("apply_item", "T03", player.global_position + Vector2(-150, 0))
	for i: int in range(10):
		await process_frame
	_check("bomb live", not get_nodes_in_group("item_bombs").is_empty())
	await _shot("fb_bomb.png")
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
