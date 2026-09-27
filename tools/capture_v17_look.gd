extends SceneTree
## v1.7 (案5) の見た目系の撮影 (D53〜D57 + D45 タイトル)。
## 出力: res://tmp_shots/v17_*.png / title_diff_*.png (検証後に削除してよい)
## 実機表示が要るため headless 不可。
## 実行: Godot --path <proj> --script res://tools/capture_v17_look.gd

const MainScene: PackedScene = preload("res://main.tscn")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const ItemBombScene: PackedScene = preload("res://objects/bomb.tscn")
const SaveData := preload("res://systems/save_data.gd")
const OUT_DIR := "res://tmp_shots/"
const TEST_SAVE := "user://capture_v17_save.json"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveData.path = TEST_SAVE
	SaveData.reset()
	_remove_save()
	await _game_shots()
	await _title_shots()
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	_remove_save()
	print("capture v17 done")
	quit()


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _new_game() -> Node:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	for w: Node in player.get_node("Weapons").get_children():
		w.queue_free()
	for i: int in range(5):
		await process_frame
	return main


func _spawn_slime(player: Node2D, off: Vector2, hp: float = 100000.0) -> Node2D:
	var s: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(s)
	s.global_position = player.global_position + off
	s.set("max_hp", hp)
	s.set("hp", hp)
	s.set("contact_damage", 0.0)
	return s


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved " + OUT_DIR + file_name)


func _game_shots() -> void:
	var main: Node = await _new_game()
	var player: Node2D = main.get_node("Player")
	var cm: Node = main.get_node("CardManager")

	# 1) スピンLv8: 拡大刃+残像 (敵を周囲に置いて回転中を撮影)
	player.call("add_weapon", "C01")
	for i: int in range(5):
		await process_frame
	var spin: Node = cm.call("weapon_by_id", "C01")
	for i: int in range(7):
		spin.call("upgrade")
	_spawn_slime(player, Vector2(200, 60))
	_spawn_slime(player, Vector2(-180, 120))
	_spawn_slime(player, Vector2(60, -200))
	for i: int in range(90):
		await process_frame
	await _shot("v17_spin.png")

	# 2) ホーミングLv8: 特大弾+煙 (手動配置で確実に撮影)
	var hpool: Node = get_first_node_in_group("pool_homing")
	var hm: Node2D = hpool.call("acquire") as Node2D
	hm.global_position = player.global_position + Vector2(-150, -80)
	hm.call("setup", Vector2.RIGHT, 120.0, 10.0, 3.0, 1, 2.65)
	hm.set("trail_scale", 2.65)
	for i: int in range(18):
		await process_frame
	await _shot("v17_homing.png")

	# 3) チェイン: 連鎖+バースト
	player.call("add_weapon", "C04")
	for i: int in range(5):
		await process_frame
	var ch: Node = cm.call("weapon_by_id", "C04")
	_spawn_slime(player, Vector2(220, -40))
	_spawn_slime(player, Vector2(300, 30))
	_spawn_slime(player, Vector2(150, 80))
	for i: int in range(5):
		await process_frame
	ch.call("fire")
	for i: int in range(4):
		await process_frame
	await _shot("v17_chain.png")

	# 4) アイテム爆弾: 48破片 (速遅) の飛散
	var b: Node2D = ItemBombScene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	b.global_position = player.global_position + Vector2(-100, 150)
	for i: int in range(3):
		await process_frame
	b.call("_explode")
	for i: int in range(22):
		await process_frame
	await _shot("v17_bomb.png")

	# 5) ストレート大弾: 1.49倍弾を3発並べる
	var pool: Node = get_first_node_in_group("pool_shots")
	for k: int in range(3):
		var pr: Node2D = pool.call("acquire") as Node2D
		pr.global_position = player.global_position + Vector2(-200 + k * 60, -150)
		pr.call("setup", Vector2.RIGHT, 0.0, 10.0, 2.0, 9, 1.49)
	for i: int in range(2):
		await process_frame
	await _shot("v17_straight.png")

	main.queue_free()
	await process_frame


func _title_shots() -> void:
	# D45: 解放済み (hard・空行) と未クリア (案内行) でレイアウトが動かないことの目視用
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.last = "hard"
	SaveData.save_now()
	await _title_shot("v17_title_unlocked.png")
	SaveData.reset()
	SaveData.save_now()
	await _title_shot("v17_title_new.png")


func _title_shot(file_name: String) -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	await _shot(file_name)
	main.queue_free()
	await process_frame
