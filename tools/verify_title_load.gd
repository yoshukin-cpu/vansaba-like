extends SceneTree
## 回帰: 起動時の user:// セーブ読み込みがタイトル表示へ反映されること。
## 不具合 (cleared 済みでも起動直後に「1度クリアすると…」表示・ハードがロック) の再現テスト。
## cleared=["normal"], last="hard" のセーブを置いて起動 → カーソルはハード・ロック文言なし・開始可。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_title_load.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")
const MainScene: PackedScene = preload("res://main.tscn")

const TEST_SAVE := "user://test_title_load_save.json"
const SAVE_JSON := "{\"cleared\":[\"normal\"],\"insane_cleared\":0,\"last\":\"hard\",\"version\":1}"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _read_saved() -> Dictionary:
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data as Dictionary
	return {}


func _init() -> void:
	# 実プレイと同じ順序: ファイルを置き、静的状態は「未ロード」のままシーンを起動する。
	SaveData.path = TEST_SAVE
	SaveData.reset()
	_remove_save()
	var fw: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	fw.store_string(SAVE_JSON)
	fw.close()
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	var title: Node = main.get_node("TitleUI")
	var lock: Label = title.get_node("Center/VBox/DiffLock")
	var diff_name: Label = title.get_node("Center/VBox/DiffRow/DiffName")
	var start_btn: Button = title.get_node("Center/VBox/StartBtn")

	print("\n=== 1) 起動直後の表示 (症状1: 解放済みなのに解放案内が出る) ===")
	_check("ロック文言なし (実際: '%s')" % str(lock.get("text")), str(lock.get("text")) == "")
	_check("前回選択 last=hard にカーソル (実際: '%s')" % str(diff_name.get("text")), str(diff_name.get("text")) == "ハード")
	_check("ハードで開始可能 (disabled=%s)" % str(start_btn.disabled), not start_btn.disabled)

	print("\n=== 2) セレクタ (症状2: 解放済みのハードがロック扱い) ===")
	title.call("_cycle", 1)
	_check("▶: エキスパートはロック (実際: '%s' / disabled=%s)" % [str(lock.get("text")), str(start_btn.disabled)],
		str(lock.get("text")).contains("解放条件") and start_btn.disabled)
	title.call("_cycle", -1)
	_check("◀: ハードへ戻ると解放 (実際: '%s')" % str(diff_name.get("text")), str(diff_name.get("text")) == "ハード")
	_check("ハードへ戻ると開始可能", not start_btn.disabled)

	print("\n=== 3) 開始フロー (ハードが実際に適用される) ===")
	title.call("confirm_focused")
	for i: int in range(3):
		await process_frame
	_check("難易度 hard が適用 (実際: '%s')" % DiffDB.current_key, DiffDB.current_key == "hard")
	var saved: Dictionary = _read_saved()
	_check("セーブに last=hard が書かれる (実際: '%s')" % str(saved.get("last", "")), str(saved.get("last", "")) == "hard")
	_check("セーブの cleared=[normal] が保たれる (実際: %s)" % str(saved.get("cleared", [])),
		saved.get("cleared", []) == ["normal"])

	# 後始末 (テストが実セーブを汚さない)
	main.queue_free()
	await process_frame
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	DiffDB.current_key = "normal"
	_remove_save()
	print("\nRESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)
