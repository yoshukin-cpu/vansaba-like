extends SceneTree
## デモ: ボス撃破→カウントダウン→スタッフロールを自動再生し、連番で撮影する。
## 実機表示が要るため headless 不可。既定はミュート (映像のみ確認)。
## 末尾に `-- --sound` を付けると音ありで再生する。
## 実行: Godot --path <proj> --script res://tools/demo_staff_roll.gd [-- --sound]

const MainScene: PackedScene = preload("res://main.tscn")
const OUT_DIR := "res://tmp_shots/"
const SHOT_AT := [1.0, 20.0, 40.0, 60.0]


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("shot failed: ", file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)


func _initialize() -> void:
	if "--sound" not in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(5):
		await process_frame
	main.call("start_game")
	for i: int in range(5):
		await process_frame
	var player: Node2D = main.get_node("Player") as Node2D
	# ボス撃破相当: カウントダウン開始。3秒間は不死身にしてクリアへ運ぶ。
	main.call("on_boss2_killed")
	var t0: int = Time.get_ticks_msec()
	while not bool(main.get("result_shown")) and Time.get_ticks_msec() - t0 < 10000:
		player.set("hp", player.get("max_hp"))
		await process_frame
	var staff: Node = main.get_node("StaffRollUI")
	print("staff visible: ", (staff as CanvasLayer).visible)
	var base: int = Time.get_ticks_msec()
	var next := 0
	while next < SHOT_AT.size():
		if float(Time.get_ticks_msec() - base) / 1000.0 >= float(SHOT_AT[next]):
			await _shot("demo_staff_%02d.png" % next)
			next += 1
		await process_frame
	staff.call("_skip")
	for i: int in range(10):
		await process_frame
	await _shot("demo_staff_finale.png")
	print("DEMO DONE")
	quit()
