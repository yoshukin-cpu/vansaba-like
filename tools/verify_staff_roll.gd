extends SceneTree
## スタッフロール検証: リザルトのメニューなし出し分け・スクロール・曲長同期・
## スキップ即最終画面・Thanks 終了・配線を確認する。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_staff_roll.gd

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
	# 1. リザルト: クリア時のみスタッフボタン、GAME OVER時は従来メニュー。
	var r: CanvasLayer = ResultScene.instantiate()
	root.add_child(r)
	for i: int in range(3):
		await process_frame
	_check("result has staff_pressed signal", r.has_signal("staff_pressed"))
	r.call("show_result", true, "10:00", 20, 300, 1000)
	_check("staff btn visible on clear", (r.get_node("Center/VBox/StaffBtn") as Button).visible)
	r.call("show_result", false, "5:41", 10, 100, 200)
	_check("staff btn hidden on gameover", not (r.get_node("Center/VBox/StaffBtn") as Button).visible)
	_check("menu buttons on gameover",
		(r.get_node("Center/VBox/RetryBtn") as Button).visible
		and (r.get_node("Center/VBox/TitleBtn") as Button).visible)
	# ボタン押下→0.6秒の暗転フェード→staff_pressed。
	r.call("show_result", true, "10:00", 20, 300, 1000)
	var fired := [false]
	r.connect("staff_pressed", func() -> void: fired[0] = true)
	r.call("_on_staff_button")
	for i: int in range(50):
		await process_frame
	_check("fade fires staff_pressed", fired[0])
	_check("fade reaches black", absf((r.get_node("Fade") as ColorRect).color.a - 1.0) < 0.01)
	r.queue_free()


	# 2. スタッフロール単体: 内容・スクロール・曲長同期・スキップ即最終画面。
	var s: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s)
	for i: int in range(3):
		await process_frame
	_check("pages fill the song (>=15)", (s.get("PAGES") as Array).size() >= 15)
	var body: String = _full_text(s)
	for needle: String in ["yoshuki", "Hermes Agent", "Google Image", "ElevenLabs", "Suno",
			"じゅっぷんかん", "Thank you so much for playing."]:
		_check("credit mentions " + needle, needle in body)
	s.call("start_roll", "生存時間 10:00 / Lv 20 / 撃破 300 / スコア 1000")
	for i: int in range(5):
		await process_frame
	_check("rolling after start", bool(s.get("rolling")))
	var song_len: float = float(s.get("song_len"))
	_check("song_len syncs theme (240-262s)", song_len >= 240.0 and song_len <= 262.0)
	_check("header keeps CLEAR", "CLEAR!" in (s.get_node("Scroller/ScrollVBox/HeaderRoll") as RichTextLabel).text)
	_check("stats handed over",
		"生存時間" in (s.get_node("Scroller/ScrollVBox/HeaderRoll") as RichTextLabel).text)
	_check("scroll fills song", absf(float(s.get("scroll_time")) - (song_len - 6.0)) < 0.01)
	# フェード (1.2秒) を越えてスクロール区間で移動を測る。
	s.set("elapsed", 1.2 + 5.0)
	for i: int in range(3):
		await process_frame
	var y0: float = (s.get_node("Scroller") as Control).position.y
	for i: int in range(10):
		await process_frame
	var y1: float = (s.get_node("Scroller") as Control).position.y
	_check("roll scrolls upward (%.1f -> %.1f)" % [y0, y1], y1 < y0)
	# 音楽はスクロール開始の2秒後に始まる。
	s.set("elapsed", 1.2 + 2.5)
	for i: int in range(3):
		await process_frame
	_check("music delayed 2s after scroll", bool(s.get("music_started")))
	# スキップ1回で最終画面 (Thanks + ボタン)。
	s.call("_skip")
	for i: int in range(3):
		await process_frame
	_check("skip ends roll at final screen", bool(s.get("ended")))
	_check("thanks visible after skip", (s.get_node("ThanksCenter") as CenterContainer).visible)
	_check("end buttons shown after skip", (s.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	_check("thanks text stays centered",
		(s.get_node("ThanksCenter/Thanks") as Label).text == "Thank you so much for playing.")
	s.queue_free()


	# 3. 自然終了: スクロール→Thanks→曲終わりでボタン (早送りで再現)。
	var s2: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s2)
	for i: int in range(3):
		await process_frame
	s2.call("start_roll", "stats")
	for i: int in range(5):
		await process_frame
	s2.set("elapsed", 1.2 + float(s2.get("scroll_time")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("scroll end shows thanks only",
		bool(s2.get("finale")) and (s2.get_node("ThanksCenter") as CenterContainer).visible
		and not (s2.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	s2.set("elapsed", 1.2 + 2.0 + float(s2.get("song_len")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("natural finish ends roll", bool(s2.get("ended")))
	_check("thanks visible at natural finish", (s2.get_node("ThanksCenter") as CenterContainer).visible)
	_check("end buttons at natural finish", (s2.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	s2.queue_free()


	# 4. main 配線: StaffRollUI ノード・シグナル・ハンドラ。
	var m: Node = MainScene.instantiate()
	root.add_child(m)
	for i: int in range(5):
		await process_frame
	_check("main has StaffRollUI", m.has_node("StaffRollUI"))
	_check("main routes clear to result", m.has_method("_on_staff_roll"))
	var rr: Node = m.get_node("ResultUI")
	_check("result wired to main",
		rr.is_connected("staff_pressed", Callable(m, "_on_staff_roll")))
	var ss: Node = m.get_node("StaffRollUI")
	_check("staff retry wired", ss.is_connected("retry_pressed", Callable(m, "_on_retry")))
	_check("staff title wired", ss.is_connected("title_pressed", Callable(m, "_on_quit_to_title")))

	# 5. クリア時はリザルト経由でスタッフロールへ (戦績つき)。
	m.call("show_result", true)
	for i: int in range(5):
		await process_frame
	_check("clear shows result", (m.get_node("ResultUI") as CanvasLayer).visible)
	_check("staff btn on clear",
		(m.get_node("ResultUI/Center/VBox/StaffBtn") as Button).visible)
	m.call("_on_staff_roll")
	for i: int in range(5):
		await process_frame
	var sr: Node = m.get_node("StaffRollUI")
	_check("staff roll starts", (sr as CanvasLayer).visible and bool(sr.get("rolling")))
	_check("result hidden behind roll", not (m.get_node("ResultUI") as CanvasLayer).visible)
	_check("bg stays black from fade", absf((sr.get_node("Bg") as ColorRect).modulate.a - 1.0) < 0.01)
	m.queue_free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)
