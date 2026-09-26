extends SceneTree
## スタッフロール検証: リザルトのボタン出し分け・曲長同期・Thanks 終了・配線を確認する。
## 実行: godot --headless --path <project> --script res://tools/verify_staff_roll.gd

const StaffRollScene: PackedScene = preload("res://ui/staff_roll_ui.tscn")
const ResultScene: PackedScene = preload("res://ui/result_ui.tscn")
const MainScene: PackedScene = preload("res://main.tscn")

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _full_text(s: Node) -> String:
	var t := ""
	for p: String in (s.get("PAGES") as Array):
		t += p
	return t


func _initialize() -> void:
	# 1. リザルト: スタッフボタンはクリア時のみ表示。
	var r: CanvasLayer = ResultScene.instantiate()
	root.add_child(r)
	for i: int in range(3):
		await process_frame
	_check("result has staff_pressed signal", r.has_signal("staff_pressed"))
	r.call("show_result", true, "10:00", 20, 300, 1000)
	_check("staff btn visible on clear", (r.get_node("Center/VBox/StaffBtn") as Button).visible)
	r.call("show_result", false, "5:41", 10, 100, 200)
	_check("staff btn hidden on gameover", not (r.get_node("Center/VBox/StaffBtn") as Button).visible)
	r.queue_free()

	# 2. スタッフロール単体: 内容・曲長・ページ送り・Thanks 終了。
	var s: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s)
	for i: int in range(3):
		await process_frame
	_check("pages fill the song (>=15)", (s.get("PAGES") as Array).size() >= 15)
	var body: String = _full_text(s)
	for needle: String in ["yoshuki", "Hermes Agent", "Google Image", "ElevenLabs", "Suno",
			"じゅっぷんかん", "Thank you so much for playing."]:
		_check("credit mentions " + needle, needle in body)
	s.call("start_roll")
	for i: int in range(5):
		await process_frame
	_check("rolling after start", bool(s.get("rolling")))
	var song_len: float = float(s.get("song_len"))
	_check("song_len syncs theme (240-262s)", song_len >= 240.0 and song_len <= 262.0)
	_check("first page shown", (s.get_node("Center/Page") as RichTextLabel).text != "")
	# スキップ1回目 → Thanks 直前 (finale)、2回目 → 終了。
	s.call("_skip")
	for i: int in range(3):
		await process_frame
	_check("skip leads to finale thanks", bool(s.get("finale")) and (s.get_node("ThanksCenter") as CenterContainer).visible)
	_check("end buttons hidden during finale", not (s.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	s.call("_skip")
	for i: int in range(3):
		await process_frame
	_check("second skip ends roll", bool(s.get("ended")))
	_check("end buttons shown at end", (s.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	_check("thanks text stays centered",
		(s.get_node("ThanksCenter/Thanks") as Label).text == "Thank you so much for playing.")
	s.queue_free()

	# 3. 自然終了: 曲の終わりと同時に Thanks + ボタン (早送りで再現)。
	var s2: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s2)
	for i: int in range(3):
		await process_frame
	s2.call("start_roll")
	for i: int in range(5):
		await process_frame
	s2.set("elapsed", float(s2.get("song_len")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("natural finish ends roll", bool(s2.get("ended")))
	_check("thanks visible at natural finish", (s2.get_node("ThanksCenter") as CenterContainer).visible)
	s2.queue_free()

	# 4. main 配線: StaffRollUI ノード・シグナル・ハンドラ。
	var m: Node = MainScene.instantiate()
	root.add_child(m)
	for i: int in range(5):
		await process_frame
	_check("main has StaffRollUI", m.has_node("StaffRollUI"))
	_check("main handles staff roll", m.has_method("_on_staff_roll"))
	var rr: Node = m.get_node("ResultUI")
	_check("result wired to main",
		rr.is_connected("staff_pressed", Callable(m, "_on_staff_roll")))
	var ss: Node = m.get_node("StaffRollUI")
	_check("staff retry wired", ss.is_connected("retry_pressed", Callable(m, "_on_retry")))
	_check("staff title wired", ss.is_connected("title_pressed", Callable(m, "_on_quit_to_title")))
	m.queue_free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)
