extends SceneTree
## v1.9 目視用キャプチャ: オプション (ライセンス・商標表示の行)・ライセンス画面 (上/中/下)・
## 閉じるとオプションへ戻る、の4+1枚。
## 実行 (窓あり): godot --path <project> --script res://tools/capture_license.gd

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


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(12):
		await process_frame
	OptDB.apply_display(OptDB.MODE_WINDOW, "1152x648")
	for i: int in range(30):
		await process_frame
	# 1) オプション: ライセンス行 (SE の直後) にカーソルを合わせて撮る。
	main.call("_on_options")
	for i: int in range(6):
		await process_frame
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var rows: Array = opts.get("rows")
	for i2: int in range(rows.size()):
		if str((rows[i2] as Dictionary)["id"]) == "license":
			opts.set("idx", i2)
	opts.call("_draw")
	for i3: int in range(4):
		await process_frame
	await _shot("v19_options_license_row.png")
	# 2) ライセンス画面 (オプション → ライセンス)。
	opts.call("_activate")
	for i4: int in range(6):
		await process_frame
	await _shot("v19_license_top.png")
	var lic: CanvasLayer = main.get_node("LicenseUI")
	var scrolls := [1500, 350, 500]
	var si := 0
	for amount: int in scrolls:
		lic.call("scroll_by", amount)
		for i5: int in range(4):
			await process_frame
		si += 1
		await _shot("v19_license_scroll%d.png" % si)
	lic.call("scroll_by", 999999)
	for i6: int in range(4):
		await process_frame
	await _shot("v19_license_bottom.png")
	# 3) 閉じるとオプションへ戻る。
	lic.call("close")
	for i7: int in range(6):
		await process_frame
	await _shot("v19_license_closed_back_to_options.png")
	print("shots=", shots)
	quit()
