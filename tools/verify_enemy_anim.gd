extends SceneTree
## 敵の2フレームアニメ + 方向別の前後/反転を検証する
## 実行: godot --path <project> --script res://tools/verify_enemy_anim.gd

const OUT_DIR := "res://tmp_shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	var player: Node2D = main.get_node("Player")

	# 1) 種類ごとのアニメ速度 (speed_scale) を確認
	var types: Array[String] = ["slime", "bat", "goblin", "archer", "wolf", "golem",
		"splitter", "sniper", "swarm", "knight", "splitmini"]
	print("--- 種類ごとのアニメ速度 ---")
	var y := -260.0
	for t: String in types:
		var scn: PackedScene = load("res://enemies/%s.tscn" % t) as PackedScene
		var e: Node2D = scn.instantiate() as Node2D
		main.add_child(e)
		e.global_position = player.global_position + Vector2(-320 + types.find(t) * 60, y)
		e.set("max_hp", 99999.0)
		e.set("hp", 99999.0)
		e.set("speed", 0.0)
		var b: AnimatedSprite2D = e.get_node("Body")
		print("  %-9s anim_fps=%.1f -> speed_scale=%.2f  frames(down)=%d frames(up)=%d" % [
			t, float(e.get("anim_fps")), b.speed_scale,
			b.sprite_frames.get_frame_count("down"), b.sprite_frames.get_frame_count("up")])

	# 2) 方向別の前後/反転 (プレイヤーの上下左右に置き、逆方向へ動かす)
	print("--- 方向別 ---")
	var offsets := [
		["above -> down ", Vector2(0, -170)],
		["below -> up   ", Vector2(0, 170)],
		["left  -> right", Vector2(-200, 0)],
		["right -> left ", Vector2(200, 0)],
	]
	var enemies: Array[Node2D] = []
	for o: Array in offsets:
		var e2: Node2D = (load("res://enemies/slime.tscn") as PackedScene).instantiate() as Node2D
		main.add_child(e2)
		e2.global_position = player.global_position + (o[1] as Vector2)
		e2.set("max_hp", 99999.0)
		e2.set("hp", 99999.0)
		e2.set("speed", 120.0)
		enemies.append(e2)

	for i in 18:
		await process_frame
	for i: int in offsets.size():
		var b2: AnimatedSprite2D = enemies[i].get_node("Body")
		print("  %s : anim=%s frame=%d flip_h=%s" % [
			offsets[i][0], b2.animation, b2.frame, str(b2.flip_h)])
	await _shot("enemy_facing_1.png")
	for i in 10:
		await process_frame
	var frames_now: Array = []
	for e3: Node2D in enemies:
		frames_now.append((e3.get_node("Body") as AnimatedSprite2D).frame)
	print("  (10フレーム後) frame=", frames_now)
	await _shot("enemy_facing_2.png")
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
