extends SceneTree
## P23 検証: スタッフロール再演のフロー (SPEC §35.13・D77) —
## カウントダウン → リザルト (再演デモ) → ボタン → フェード → ロール・保存なし。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_replay_flow.gd

const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")
const BgmScript := preload("res://systems/bgm_manager.gd")

const TEST_SAVE := "user://test_replay_flow_save.json"

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


func _read_save() -> String:
	if not FileAccess.file_exists(TEST_SAVE):
		return ""
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


func _key_ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	return ev


func _action_ev(name: String, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	return ev


func _inject(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _init() -> void:
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.coins = 77
	SaveData.last = "normal"
	SaveData.save_now()
	var before: String = _read_save()
	await _t_flow(before)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _t_flow(save_before: String) -> void:
	print("\n=== 1) 再演: カウントダウン → リザルト → ボタン → ロール (D77) ===")
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(6)
	var title: CanvasLayer = main.get_node("TitleUI")
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var result: CanvasLayer = main.get_node("ResultUI")
	var roll: CanvasLayer = main.get_node("StaffRollUI")
	var countdown: CanvasLayer = main.get_node("ReplayCountdownUI")
	_check("前提: タイトル表示・ロールは非表示", bool(title.visible) and not bool(roll.visible))
	# オプションの「スタッフロール再演」を実行
	main.call("_on_options")
	await _frames(3)
	_check("解放済みなら再演の行がある", (opts.call("row_ids") as Array).has("replay"))
	opts.set("idx", (opts.call("row_ids") as Array).find("replay"))
	opts.call("_activate")
	await _frames(3)
	# 1) カウントダウン
	_check("オプションは閉じる", not bool(opts.visible))
	_check("タイトルは隠れる", not bool(title.visible))
	_check("再演が進行中 (replay_active)", bool(main.get("replay_active")))
	_check("カウントダウンが始まる", bool(countdown.visible) and float(countdown.get("remaining")) > 0.0)
	_check("リザルトはまだ出ない (カウントダウン中)", not bool(result.visible))
	await _frames(6)
	_check("カウントダウンは 3 から", str((countdown.get_node("Count") as Label).text) == "3")
	await _frames(64)
	_check("カウントダウンは 2 に進む", str((countdown.get_node("Count") as Label).text) == "2")
	# 再演中はポーズしない
	await _inject(_action_ev("pause_game", true))
	await _inject(_action_ev("pause_game", false))
	_check("再演中はポーズしない", paused and not (main.get_node("PauseUI") as CanvasLayer).visible)
	await _frames(70)
	_check("カウントダウンは 1 に進む", str((countdown.get_node("Count") as Label).text) == "1")
	await _frames(60)
	# 2) リザルト (再演デモ)
	_check("カウントダウンが終わる", not bool(countdown.visible))
	_check("リザルト (再演デモ) が出る", bool(result.visible) and bool(result.get("replay_mode")))
	_check("再演デモはクリア扱いの見た目 (CLEAR!)", bool(result.get("is_clear")) and str((result.get_node("Center/VBox/Title") as Label).text) == "CLEAR!")
	var staff_btn: Button = result.get_node("Center/VBox/StaffBtn")
	_check("「スタッフロールを見る」が出てフォーカスされる", staff_btn.visible and staff_btn.has_focus())
	_check("リトライ/タイトルは出ない", not (result.get_node("Center/VBox/RetryBtn") as Button).visible and not (result.get_node("Center/VBox/TitleBtn") as Button).visible)
	var stats: String = str((result.get_node("Center/VBox/Stats") as Label).text)
	var note: String = str((result.get_node("Center/VBox/UnlockLabel") as Label).text)
	_check("戦績は見本 (10:00) + 注記", "10:00" in stats and "再演のため戦績は見本" in note)
	_check("ボタンを押すまでロールは始まらない", not bool(roll.visible))
	# 3) ボタン → フェード → ロール
	await _inject(_key_ev(KEY_ENTER, true))
	await _inject(_key_ev(KEY_ENTER, false))
	await _frames(2)
	_check("ボタンで暗転フェードが始まる", bool(result.get("_leaving")))
	_check("フェード中もロールはまだ出ない", not bool(roll.visible))
	await _frames(45)
	_check("ロールが始まる", bool(roll.visible) and bool(roll.get("rolling")))
	_check("ロールは再演モード", bool(roll.get("replay_mode")))
	_check("リザルトのノードをそのまま流す (実クリアと同じ見え方)", roll.get("_res") == result)
	_check("内蔵ヘッダーは使わない (リザルトの見出しが流れる)", not bool((roll.get_node("Scroller/ScrollVBox/HeaderRoll") as RichTextLabel).visible))
	_check("BGM は止まったまま (タイトル曲を鳴らさない)", int((main.get_node("BGM") as Node).get("state")) == BgmScript.State.SILENT)
	_check("何も保存しない (D77)", _read_save() == save_before and SaveData.cleared == ["normal"] and int(SaveData.coins) == 77)
