extends SceneTree
## P23 検証 (窓あり): オプション画面のマウス操作 (SPEC §35.13・D74/D75)。
## headless ではマウスイベントが GUI に届かないため、実クリック (ヒットテスト) はこの窓あり版で確認する。
## 実行 (窓あり): godot --fixed-fps 60 --path <project> --script res://tools/verify_options_mouse.gd
##   - ◀ / ▶ ボタンのクリックで値が変わる
##   - 「セーブデータ初期化」の はい / いいえ をクリックできる (いいえ→何も消えない・はい→消える)
##   - モーダル越しにタイトルのボタンは押せない (Dim が遮る)
## 終了コード: 0 = ALL PASS / 1 = 失敗あり

const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")
const OptDB := preload("res://data/options_db.gd")

const TEST_SAVE := "user://test_options_mouse_save.json"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


## キャンバス座標 (1152x648 の設計座標) → ウィンドウ座標。
## stretch keep では等比 + 中央 (余りは黒帯) なので、クリックはこの変換が要る
## (窓サイズが 1152x648 のときは恒等)。
func _to_window(p_canvas: Vector2) -> Vector2:
	var vp: Vector2 = root.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vp.x <= 0.0 or vp.y <= 0.0:
		return p_canvas
	var s: float = minf(win.x / vp.x, win.y / vp.y)
	return p_canvas * s + (win - vp * s) * 0.5


func _click_at(pos_canvas: Vector2) -> void:
	var pos: Vector2 = _to_window(pos_canvas)
	for pressed: bool in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		Input.parse_input_event(mb)
		await process_frame
		await process_frame


func _init() -> void:
	SaveData.path = TEST_SAVE
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.coins = 30
	SaveData.options = {"mode": OptDB.MODE_WINDOW, "resolution": "1152x648", "bgm": 0.8, "se": 1.0}
	SaveData.save_now()
	# レイアウトを本番と同じにする (既定の窓サイズ)。
	OptDB.apply_display(OptDB.MODE_WINDOW, "1152x648")
	await _t_mouse()
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _t_mouse() -> void:
	print("\n=== オプションのマウス操作 (D74/D75) ===")
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(12)
	var title: CanvasLayer = main.get_node("TitleUI")
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var start_btn: Button = title.get_node("Center/VBox/StartBtn")
	print("viewport=", root.get_visible_rect(), " start_btn=", start_btn.get_global_rect())
	main.call("_on_options")
	await _frames(6)
	var rows: Array = opts.get("rows")
	var res_i: int = 1
	var rb: Button = (rows[res_i] as Dictionary)["right_btn"]
	var lb: Button = (rows[res_i] as Dictionary)["left_btn"]
	var before: String = str(SaveData.options["resolution"])
	_check("▶ ボタンが画面内にある (レイアウト前提)", root.get_visible_rect().has_point(rb.get_global_rect().get_center()))
	var presses := [0, 0]
	rb.pressed.connect(func() -> void: presses[0] += 1)
	lb.pressed.connect(func() -> void: presses[1] += 1)
	await _click_at(rb.get_global_rect().get_center())
	_check("▶ クリックで解像度が進む (D75: %s → %s)" % [before, str(SaveData.options["resolution"])], str(SaveData.options["resolution"]) != before)
	_check("クリックがボタンに届いている", int(presses[0]) == 1)
	_check("クリックで行も選択される (D75)", int(opts.get("idx")) == res_i)
	# 窓サイズが変わったのでレイアウトを待ってから ◀ を押す
	await _frames(30)
	lb = (opts.get("rows") as Array)[res_i]["left_btn"]
	await _click_at(lb.get_global_rect().get_center())
	_check("◀ クリックで戻る (D75)", str(SaveData.options["resolution"]) == before)
	_check("◀ のクリックも届いている", int(presses[1]) == 1)
	# 解像度が戻って窓が再リサイズされるため、落ち着くまで待つ (座標変換のため)。
	await _frames(30)
	# 音量行の ◀ クリック
	var bgm_i: int = 2
	var bgm_before: float = float(SaveData.options["bgm"])
	var bgm_l: Button = (opts.get("rows") as Array)[bgm_i]["left_btn"]
	await _click_at(bgm_l.get_global_rect().get_center())
	_check("BGM 音量の ◀ クリックで下がる (D75: %.2f → %.2f)" % [bgm_before, float(SaveData.options["bgm"])], float(SaveData.options["bgm"]) < bgm_before)
	# モーダル越しのタイトルは押せない (D74)
	var starts := 0
	title.connect("start_pressed", func() -> void: starts += 1)
	await _click_at(start_btn.get_global_rect().get_center())
	_check("モーダル越しにタイトルは押せない (D74)", starts == 0 and bool(title.visible))
	_check("タイトルは表示のまま (開始していない)", bool(title.visible))
	# セーブデータ初期化: いいえ → 何も消えない / はい → 消える
	var ids: Array = opts.call("row_ids")
	opts.set("idx", ids.find("reset"))
	opts.call("_activate")
	await _frames(4)
	var yes: Button = opts.get_node("Panel/Confirm/ConfirmRow/YesBtn")
	var no: Button = opts.get_node("Panel/Confirm/ConfirmRow/NoBtn")
	await _click_at(no.get_global_rect().get_center())
	await _frames(2)
	_check("「いいえ」クリックで消えない", SaveData.cleared == ["normal"] and int(SaveData.coins) == 30)
	opts.set("idx", (opts.call("row_ids") as Array).find("reset"))
	opts.call("_activate")
	await _frames(4)
	yes = opts.get_node("Panel/Confirm/ConfirmRow/YesBtn")
	await _click_at(yes.get_global_rect().get_center())
	await _frames(2)
	_check("「はい」クリックで進行状況が消える (D76)", SaveData.cleared.is_empty() and int(SaveData.coins) == 0)
	_check("オプション設定は保持 (D76)", str(SaveData.options["resolution"]) == before and float(SaveData.options["bgm"]) > 0.0)
	# 戻る行の実行ボタンで閉じる (D75)
	var back_exec: Button = (opts.get("rows") as Array)[(opts.get("rows") as Array).size() - 1]["exec_btn"]
	await _frames(6)
	await _click_at(back_exec.get_global_rect().get_center())
	await _frames(3)
	_check("戻るボタンのクリックで閉じる (D75)", not bool(opts.visible))
	main.free()
