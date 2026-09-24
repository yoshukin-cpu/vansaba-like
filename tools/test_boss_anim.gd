extends SceneTree
## ボスのアニメーション確認 (Sprite2D/AnimatedSprite2D の型エラー回帰テスト)
## 実行: godot --path <project> --script res://tools/test_boss_anim.gd

func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	var player: Node2D = main.get_node("Player")

	var paths: Array[String] = ["boss_golem_king", "boss_void_emperor"]
	var bosses: Array[Node2D] = []
	for p: String in paths:
		var scn: PackedScene = load("res://enemies/%s.tscn" % p) as PackedScene
		if scn == null:
			push_error("load failed: " + p)
			continue
		var b: Node2D = scn.instantiate() as Node2D
		main.add_child(b)
		b.global_position = player.global_position + Vector2(0, -220 + bosses.size() * 120)
		b.set("max_hp", 99999.0)
		b.set("hp", 99999.0)
		bosses.append(b)

	for i in 40:
		await process_frame
	for i: int in bosses.size():
		var body: AnimatedSprite2D = bosses[i].get_node("Body")
		print("%s: type=%s anim=%s frame=%d speed_scale=%.2f frames=%d/%d" % [
			paths[i], body.get_class(), body.animation, body.frame, body.speed_scale,
			body.sprite_frames.get_frame_count("down"), body.sprite_frames.get_frame_count("up")])

	# 方向別 (上に置いたボスは下向き=正面、下に置いたボスは上向き=背面)
	for i: int in bosses.size():
		var body2: AnimatedSprite2D = bosses[i].get_node("Body")
		print("  %s facing: anim=%s flip_h=%s" % [paths[i], body2.animation, str(body2.flip_h)])

	# 報告されたスタックトレース経路 (spawn_director._spawn_boss) を直接叩く
	var director: Node = main.get_node("SpawnDirector")
	print("--- _spawn_boss 経由 ---")
	director.call("_spawn_boss", "res://enemies/boss_golem_king.tscn", "WARNING: Golem King")
	for i in 20:
		await process_frame
	print("bosses in group: ", get_nodes_in_group("bosses").size())
	for b: Node in get_nodes_in_group("bosses"):
		var bb: AnimatedSprite2D = (b as Node2D).get_node("Body")
		print("  ", b.name, " anim=", bb.animation, " frame=", bb.frame)

	print("done (型エラーが出ていなければOK)")
	quit()
