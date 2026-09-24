extends SceneTree
## 敵・弾スプライトの実機確認: 全種類を並べて撮影する
## 実行: godot --path <project> --script res://tools/verify_enemies.gd

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
	var director: Node = main.get_node("SpawnDirector")
	director.set("running", false)   # 自前の敵だけにする

	var paths: Array[String] = [
		"slime", "bat", "goblin", "archer", "wolf", "golem",
		"splitter", "sniper", "swarm", "knight", "splitmini",
	]
	var i: int = 0
	for p: String in paths:
		var scn: PackedScene = load("res://enemies/%s.tscn" % p) as PackedScene
		if scn == null:
			print("load failed: ", p)
			continue
		var e: Node2D = scn.instantiate() as Node2D
		main.add_child(e)
		var col: int = i % 6
		var row: int = i / 6
		e.global_position = player.global_position + Vector2(-160 + col * 64, -180 + row * 64)
		e.set("max_hp", 99999.0)
		e.set("hp", 99999.0)
		e.set("speed", 0.0)
		i += 1

	# ボス2体 (下の行に大きめに配置)
	var bosses: Array[String] = ["boss_golem_king", "boss_void_emperor"]
	var j: int = 0
	for p: String in bosses:
		var scn2: PackedScene = load("res://enemies/%s.tscn" % p) as PackedScene
		if scn2 == null:
			continue
		var b: Node2D = scn2.instantiate() as Node2D
		main.add_child(b)
		b.global_position = player.global_position + Vector2(-110 + j * 220, 190)
		b.set("max_hp", 99999.0)
		b.set("hp", 99999.0)
		b.set("speed", 0.0)
		j += 1

	# 弾4種
	var shot_pool: Node = main.get_node("PoolShots")
	var homing_pool: Node = main.get_node("PoolHoming")
	var eshot_pool: Node = main.get_node("PoolEnemyShots")
	var p1: Node2D = shot_pool.call("acquire") as Node2D
	p1.global_position = player.global_position + Vector2(-200, 250)
	p1.call("setup", Vector2.RIGHT, 20.0, 10.0, 5.0, 1)
	var p2: Node2D = homing_pool.call("acquire") as Node2D
	p2.global_position = player.global_position + Vector2(-100, 250)
	p2.call("setup", Vector2.RIGHT, 20.0, 10.0, 5.0, 1)
	var p3: Node2D = eshot_pool.call("acquire") as Node2D
	p3.global_position = player.global_position + Vector2(0, 250)
	p3.call("setup", Vector2.RIGHT, 20.0, 10.0)
	var bomb := Area2D.new()
	bomb.set_script(load("res://projectiles/bomb.gd"))
	main.add_child(bomb)
	bomb.call("setup", player.global_position + Vector2(120, 250), player.global_position + Vector2(120, 250), 30.0, 90.0, 1.0)

	for k in 30:
		await process_frame
	await _shot("enemies_all.png")
	print("enemies spawned: ", i, " bosses: ", j)
	print("anim/tex check: ", (main.get_node("Player") != null))
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
