extends SceneTree
## 追加確認: 飛行中の爆弾スプライトと、エリート個体(金色tint)
## 実行: godot --path <project> --script res://tools/verify_extras.gd

const OUT_DIR := "res://tmp_shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	var player: Node2D = main.get_node("Player")
	main.get_node("SpawnDirector").set("running", false)

	# エリートのスライム (金色tint) と通常スライムを並べる
	var slime_scn: PackedScene = load("res://enemies/slime.tscn") as PackedScene
	var s1: Node2D = slime_scn.instantiate() as Node2D
	main.add_child(s1)
	s1.global_position = player.global_position + Vector2(-70, -70)
	s1.set("max_hp", 99999.0)
	s1.set("hp", 99999.0)
	s1.set("speed", 0.0)
	var s2: Node2D = slime_scn.instantiate() as Node2D
	main.add_child(s2)
	s2.global_position = player.global_position + Vector2(0, -70)
	s2.set("max_hp", 99999.0)
	s2.set("hp", 99999.0)
	s2.set("speed", 0.0)
	s2.call("make_elite")

	# 爆弾を 300px 先まで飛ばして飛行中に撮影
	var bomb := Area2D.new()
	bomb.set_script(load("res://projectiles/bomb.gd"))
	main.add_child(bomb)
	bomb.call("setup", player.global_position + Vector2(-60, 60),
		player.global_position + Vector2(240, 60), 30.0, 90.0, 1.0)

	# 飛行時間 0.45s の途中で撮影
	for k in 12:
		await process_frame
	await _shot("extras_bomb_flying.png")
	for k in 30:
		await process_frame
	await _shot("extras_after_explosion.png")
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
