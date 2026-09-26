extends SceneTree
## 鑑賞用デモ: ボス撃破→カウントダウン→スタッフロールを最後まで自動再生する。
## スタッフロール改変時の再確認用に再利用できる。撮影はしない。
## 実機表示が要るため headless 不可。音あり既定 (末尾に `-- --mute` で無音)。
## 終了後は最終画面 (Thanks + もう一度/タイトルへ) で待機する。閉じれば終わり。
## 実行: Godot --path <proj> --script res://tools/demo_staff_roll.gd [-- --mute]

const MainScene: PackedScene = preload("res://main.tscn")


func _initialize() -> void:
	if "--mute" in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, true)
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
	print("staff roll playing (full length). window stays open at the finale.")
	# 最後まで再生し、最終画面で待機する (閉じるのはユーザー)。
	while not bool(staff.get("ended")):
		await process_frame
	print("FINALE reached. Close the window, or press a button to continue.")
