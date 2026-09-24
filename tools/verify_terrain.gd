extends SceneTree
## P8/P9 検証: 荒野パッチと障害物の見た目、Yソート、FPS を実機で確認する。
## 実行: godot --path <project> --script res://tools/verify_terrain.gd

const CG := preload("res://world/chunk_gen.gd")
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
	var world: Node = main.get_node("World")

	# 荒野の中心を探す (原点から 2,000〜5,000px の範囲)
	var target := Vector2.ZERO
	var found: bool = false
	for r: int in range(2000, 5000, 96):
		for k: int in range(16):
			var a: float = TAU * float(k) / 16.0
			var p := Vector2(cos(a), sin(a)) * float(r)
			if CG.is_wasteland(Vector2i(int(floor(p.x / 48.0)), int(floor(p.y / 48.0)))):
				target = p
				found = true
				break
		if found:
			break
	print("荒野の目標地点: ", target, " (found=", found, ")")

	# 荒野へ移動して撮影
	player.global_position = target
	for i: int in range(20):
		await process_frame
	await _shot("terrain_wasteland.png")

	# 障害物の密集地帯を探して撮影 (木の裏に隠れるかの確認用に真上へ移動)
	var ob_cell: Vector2i = _find_obstacle_near(target)
	var ob_pos := Vector2(float(ob_cell.x) * 48.0 + 24.0, float(ob_cell.y) * 48.0 + 24.0)
	player.global_position = ob_pos + Vector2(0.0, -72.0)   # 木の真上 (奥) に立つ
	for i: int in range(20):
		await process_frame
	await _shot("terrain_behind_tree.png")
	player.global_position = ob_pos + Vector2(0.0, 96.0)    # 木の下 (手前) に立つ
	for i: int in range(20):
		await process_frame
	await _shot("terrain_in_front_of_tree.png")

	# FPS 計測 (60フレーム後、120フレームぶん)
	for i: int in range(60):
		await process_frame
	var t0: int = Time.get_ticks_msec()
	var f0: int = Engine.get_frames_drawn()
	for i: int in range(120):
		await process_frame
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var df: int = Engine.get_frames_drawn() - f0
	print("FPS: %.1f (%.1f 秒で %d フレーム)" % [float(df) / dt, dt, df])
	var obstacles: TileMapLayer = world.get("obstacles") as TileMapLayer
	var ground: TileMapLayer = world.get("ground") as TileMapLayer
	print("配置セル: 地面 %d / 障害物 %d" % [ground.get_used_cells().size(), obstacles.get_used_cells().size()])
	print("terrain verify done")
	quit()


func _find_obstacle_near(center: Vector2) -> Vector2i:
	var c0 := Vector2i(int(floor(center.x / 48.0)), int(floor(center.y / 48.0)))
	var best: Vector2i = c0
	var best_d: float = 1e9
	for dy: int in range(-40, 41, 2):
		for dx: int in range(-40, 41, 2):
			var cell := c0 + Vector2i(dx, dy)
			var key: Vector2i = CG.chunk_key(int(floor(float(cell.x) / 32.0)), int(floor(float(cell.y) / 32.0)))
			var data: Dictionary = CG.generate_chunk(key.x, key.y)
			var ox: int = key.x * CG.CHUNK
			var oy: int = key.y * CG.CHUNK
			for ob: Dictionary in (data["obstacles"] as Array):
				var local: Vector2i = ob["cell"] as Vector2i
				if int(ob["tile"]) >= CG.O_ROCK:
					continue
				var pos := Vector2i(ox + local.x, oy + local.y)
				var d: float = Vector2(float(pos.x - c0.x), float(pos.y - c0.y)).length()
				if d < best_d:
					best_d = d
					best = pos
	return best


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
