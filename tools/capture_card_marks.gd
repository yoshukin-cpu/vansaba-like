extends SceneTree
## カードマーク表示の実機キャプチャ。
## 実行: godot --path <project> --script res://tools/capture_card_marks.gd -- --seed 0
## 出力: res://tmp_shots/cards_levelup.png / res://tmp_shots/cards_history.png

const OUT_DIR := "res://tmp_shots/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	player.set("xp_next", 1000000000)
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame
	var card_manager: Node = main.get_node("CardManager")
	var levelup: CanvasLayer = main.get_node("LevelUpUI")
	var offers: Array = card_manager.call("get_offers")
	levelup.call("show_offers", offers)
	for i: int in range(5):
		await process_frame
	await _shot("cards_levelup.png")
	main.call("_on_card_chosen", str((offers[0] as Dictionary)["id"]))
	for i: int in range(3):
		await process_frame
	var offers2: Array = card_manager.call("get_offers")
	main.call("_on_card_chosen", str((offers2[0] as Dictionary)["id"]))
	for i: int in range(40):
		main.call("_record_acquired_card", "HEAL")
	for i: int in range(10):
		await process_frame
	await _shot("cards_history.png")
	print("capture done")
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
