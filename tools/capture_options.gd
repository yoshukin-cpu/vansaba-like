extends SceneTree
## v1.8 目視用キャプチャ: タイトル (終了ボタンの左下配置)・オプション・強化画面・
## 4:3/16:10/4K の表示確認と 4K の fps 実測。
## 実行 (窓あり): godot --path <project> --script res://tools/capture_options.gd -- --coins 500 --unlock-all

const OptDB := preload("res://data/options_db.gd")
const OUT_DIR := "res://tmp_shots/"

var shots := 0


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	shots += 1
	print("saved ", name)


func _set_window(res: String) -> void:
	OptDB.apply_display(OptDB.MODE_WINDOW, res)
	for i: int in range(30):
		await process_frame


func _fps_sample(frames: int = 180) -> void:
	var mn := 9999
	var sum := 0.0
	for i: int in range(frames):
		await process_frame
		var f: int = int(Engine.get_frames_per_second())
		if f > 0 and f < mn:
			mn = f
		sum += float(f)
	print("fps_sample: min=%d avg=%.1f" % [mn, sum / float(frames)])


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	# 保存オプション (フルスクリーン等) の適用が落ち着くまで待ってから、既定解像度にする。
	for i: int in range(12):
		await process_frame
	await _set_window("1152x648")
	# 1) タイトル (デフォルト解像度)。終了ボタンが左下に全部見えること。
	await _shot("v18_title_default.png")
	# 2) オプション (解放済み: スタッフロール再演の行も出る)
	main.call("_on_options")
	for i: int in range(6):
		await process_frame
	await _shot("v18_options.png")
	# 2b) セーブデータ初期化の確認 (はい/いいえ) — D76
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var ids: Array = opts.call("row_ids")
	opts.set("idx", ids.find("reset"))
	opts.call("_activate")
	for i: int in range(4):
		await process_frame
	await _shot("v18_options_reset_confirm.png")
	opts.call("_confirm_answer", false)
	# 閉じるのは close() (closed シグナル経由で main が後処理する)。
	opts.call("close")
	# 3) 強化画面 (--coins 500 で所持コインを入れてある)
	main.call("_on_upgrade")
	for i: int in range(6):
		await process_frame
	await _shot("v18_upgrade.png")
	(main.get_node("UpgradeUI") as CanvasLayer).call("close")
	for i: int in range(3):
		await process_frame
	# 4) 4:3 (1024x768) / 5) 16:10 (1280x800) の黒帯確認
	await _set_window("1024x768")
	await _shot("v18_window_4x3.png")
	await _set_window("1280x800")
	await _shot("v18_window_16x10.png")
	# 6) 4K (3840x2160) の描画と fps 実測
	await _set_window("3840x2160")
	await _shot("v18_window_4k.png")
	await _fps_sample(180)
	# 元に戻す
	await _set_window("1152x648")
	# 7) 再演フロー: カウントダウン → リザルト (再演デモ) → D77
	main.call("_on_options")
	for i: int in range(6):
		await process_frame
	var opts3: CanvasLayer = main.get_node("OptionsUI")
	opts3.set("idx", (opts3.call("row_ids") as Array).find("replay"))
	opts3.call("_activate")
	for i: int in range(10):
		await process_frame
	await _shot("v18_replay_countdown.png")
	for i: int in range(190):
		await process_frame
	await _shot("v18_replay_result.png")
	print("RESULT: %d shots" % shots)
	quit(0)
