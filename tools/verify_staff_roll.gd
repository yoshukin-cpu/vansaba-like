extends SceneTree
## スタッフロール検証: リザルトのメニューなし出し分け・スクロール・曲長同期・
## スキップ即最終画面・Thanks 終了・配線を確認する。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_staff_roll.gd

const StaffRollScene: PackedScene = preload("res://ui/staff_roll_ui.tscn")
const ResultScene: PackedScene = preload("res://ui/result_ui.tscn")
const MainScene: PackedScene = preload("res://main.tscn")
const ThemeLyrics := preload("res://data/theme_lyrics.gd")
const SaveData := preload("res://systems/save_data.gd")

const TEST_SAVE := "user://test_staff_roll_save.json"

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
	# クリア記録が実セーブを汚さないよう、一時パスを使う (v1.6)。
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	SaveData.reset()
	# 1. リザルト: クリア時はメニューなし+ヒント、GAME OVER時は従来メニュー。
	var r: CanvasLayer = ResultScene.instantiate()
	root.add_child(r)
	for i: int in range(3):
		await process_frame
	_check("result has staff_pressed signal", r.has_signal("staff_pressed"))
	r.call("show_result", true, "10:00", 20, 300, 1000)
	_check("no menu on clear",
		not (r.get_node("Center/VBox/RetryBtn") as Button).visible
		and not (r.get_node("Center/VBox/TitleBtn") as Button).visible)
	_check("press hint removed", r.get_node_or_null("Center/VBox/PressHint") == null)
	r.call("show_result", false, "5:41", 10, 100, 200)
	_check("menu buttons on gameover",
		(r.get_node("Center/VBox/RetryBtn") as Button).visible
		and (r.get_node("Center/VBox/TitleBtn") as Button).visible)
	# ボタン押下→Dim のみ不透明化 (CLEAR!/戦績は残る)→staff_pressed。
	r.call("show_result", true, "10:00", 20, 300, 1000)
	var fired := [false]
	r.connect("staff_pressed", func() -> void: fired[0] = true)
	r.call("_on_staff_button")
	for i: int in range(50):
		await process_frame
	_check("fade fires staff_pressed", fired[0])
	_check("dim reaches black", absf((r.get_node("Dim") as ColorRect).color.a - 1.0) < 0.01)
	_check("CLEAR!/stats stay", (r.get_node("Center/VBox/Title") as Label).text == "CLEAR!")
	r.queue_free()


	# 2. 単体: リザルト実ノード (CLEAR!/戦績) を引き継いでスクロールする。
	var r2: CanvasLayer = ResultScene.instantiate()
	root.add_child(r2)
	var s: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s)
	for i: int in range(3):
		await process_frame
	_check("pages fill the song (>=15)", (s.get("PAGES") as Array).size() >= 15)
	var body: String = _full_text(s)
	for needle: String in ["yoshuki", "Hermes Agent", "Google Image", "ElevenLabs", "Suno",
			"じゅっぷんかん", "BGM", "コイン", "Thank you so much for playing."]:
		_check("credit mentions " + needle, needle in body)
	r2.call("show_result", true, "10:00", 20, 300, 1000)
	for i: int in range(3):
		await process_frame
	s.call("start_roll", r2)
	for i: int in range(5):
		await process_frame
	_check("rolling after start", bool(s.get("rolling")))
	# 背景は「画面トップ = 画像トップ」・横中央・画面を覆う (D43)。
	var art: TextureRect = s.get_node("ArtFade") as TextureRect
	var vp: Vector2 = s.get_viewport().get_visible_rect().size
	_check("art top-aligned (y=%.1f)" % art.position.y, absf(art.position.y) < 0.5)
	_check("art centered horizontally", absf(art.position.x - (vp.x - art.size.x) * 0.5) < 0.5)
	_check("art covers screen", art.size.x >= vp.x - 0.5 and art.size.y >= vp.y - 0.5)
	var song_len: float = float(s.get("song_len"))
	_check("song_len syncs theme (240-262s)", song_len >= 240.0 and song_len <= 262.0)
	_check("uses real header", s.get("_rc") != null)
	_check("inner header unused", not (s.get_node("Scroller/ScrollVBox/HeaderRoll") as RichTextLabel).visible)
	_check("scroll fills song", absf(float(s.get("scroll_time")) - (song_len - 6.0)) < 0.01)
	# フェード (1.2秒) を越えて: 実ヘッダーと本文が一緒に上がる。
	s.set("elapsed", 1.2 + 5.0)
	for i: int in range(3):
		await process_frame
	_check("real header scrolls", (r2.get_node("Center") as Control).position.y < 0.0)
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
	# 実ヘッダー抜け切りで交換 (リザルト非表示+背景黒、Thanks はまだ)。
	s.set("elapsed", 1.2 + float(s.get("scroll_time")) * 0.5)
	for i: int in range(3):
		await process_frame
	_check("swap hides result", not r2.visible)
	_check("bg opaque after swap", absf((s.get_node("Bg") as ColorRect).modulate.a - 1.0) < 0.01)
	_check("thanks not yet", not bool(s.get("finale")))
	# 歌詞バー: 時刻付き歌詞の読み込みと追従 (アウトロ以降は非表示)。
	var entries: Array = ThemeLyrics.load_timed()
	_check("lyrics 41 entries", entries.size() == 41)
	var l12: Dictionary = ThemeLyrics.line_at(entries, 12.0)
	_check("lyric at 12s",
		str(l12["cur"]) == "風が叫ぶ 開戦の鐘" and str(l12["next"]) == "【テーマソング：じゅっぷんかんの王国】")
	_check("lyric hidden before start", str(ThemeLyrics.line_at(entries, 0.0)["cur"]) == "")
	_check("outro hides lyrics", str(ThemeLyrics.line_at(entries, 240.0)["cur"]) == "")
	s.set("elapsed", 1.2 + 2.0 + 12.0)
	for i: int in range(3):
		await process_frame
	_check("lyric bar follows song",
		(s.get_node("LyricBar") as PanelContainer).visible
		and (s.get_node("LyricBar/LyricCur") as Label).text == "風が叫ぶ 開戦の鐘")
	s.set("elapsed", 1.2 + 2.0 + 240.0)
	for i: int in range(3):
		await process_frame
	_check("lyric bar hidden at outro", not (s.get_node("LyricBar") as PanelContainer).visible)
	# スキップ1回で最終画面 (Thanks + ボタン)。
	s.call("_skip")
	for i: int in range(3):
		await process_frame
	_check("skip ends roll at final screen", bool(s.get("ended")))
	_check("thanks visible after skip", (s.get_node("ThanksCenter") as CenterContainer).visible)
	_check("end buttons shown after skip", (s.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	_check("thanks text stays centered",
		(s.get_node("ThanksCenter/Thanks") as Label).text == "Thank you so much for playing.")
	_check("art opaque after skip",
		absf((s.get_node("ArtFade") as TextureRect).modulate.a - 1.0) < 0.01)
	r2.queue_free()
	s.queue_free()


	# 3. 自然終了: スクロール→Thanks→曲終わりでボタン (早送りで再現)。
	var r3: CanvasLayer = ResultScene.instantiate()
	root.add_child(r3)
	var s2: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s2)
	for i: int in range(3):
		await process_frame
	r3.call("show_result", true, "10:00", 20, 300, 1000)
	for i: int in range(3):
		await process_frame
	s2.call("start_roll", r3)
	for i: int in range(5):
		await process_frame
	s2.set("elapsed", 1.2 + float(s2.get("scroll_time")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("scroll end shows thanks only",
		bool(s2.get("finale")) and (s2.get_node("ThanksCenter") as CenterContainer).visible
		and not (s2.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	# Thanks 文字は即表示、タイトル背景だけ2秒かけてフェードインする。
	for i: int in range(150):
		await process_frame
	_check("title art fades in",
		absf((s2.get_node("ArtFade") as TextureRect).modulate.a - 1.0) < 0.02)
	s2.set("elapsed", 1.2 + 2.0 + float(s2.get("song_len")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("natural finish ends roll", bool(s2.get("ended")))
	_check("thanks visible at natural finish", (s2.get_node("ThanksCenter") as CenterContainer).visible)
	_check("end buttons at natural finish", (s2.get_node("BottomBox/EndRow") as HBoxContainer).visible)
	r3.queue_free()
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
	_check("staff retry removed", not ss.has_signal("retry_pressed") and not ss.has_node("BottomBox/EndRow/RetryBtn"))
	_check("staff end row is title only", (ss.get_node("BottomBox/EndRow") as HBoxContainer).get_child_count() == 1)
	_check("staff title wired", ss.is_connected("title_pressed", Callable(m, "_on_quit_to_title")))

	# 5. クリア時はリザルトのボタン押下経路でスタッフロールへ (戦績つき)。
	m.call("show_result", true)
	for i: int in range(5):
		await process_frame
	_check("clear shows result", (m.get_node("ResultUI") as CanvasLayer).visible)
	_check("result shows difficulty row",
		"難易度:" in str((m.get_node("ResultUI/Center/VBox/Stats") as Label).text))
	_check("unlock notice on first clear",
		(m.get_node("ResultUI/Center/VBox/UnlockLabel") as Label).visible
		and str((m.get_node("ResultUI/Center/VBox/UnlockLabel") as Label).text) == "解放: 難易度選択!")
	(m.get_node("ResultUI") as CanvasLayer).call("_on_staff_button")
	for i: int in range(60):
		await process_frame
		if bool((m.get_node("StaffRollUI") as CanvasLayer).get("rolling")):
			break
	var sr: Node = m.get_node("StaffRollUI")
	_check("staff roll starts", (sr as CanvasLayer).visible and bool(sr.get("rolling")))
	# 実ヘッダーはしばらく残る (背景は透明)。抜け切り後に交換される。
	_check("result stays for header", (m.get_node("ResultUI") as CanvasLayer).visible)
	_check("bg transparent early", absf((sr.get_node("Bg") as ColorRect).modulate.a) < 0.01)
	sr.set("elapsed", 1.2 + float(sr.get("scroll_time")) + 0.05)
	for i: int in range(3):
		await process_frame
	_check("result hidden after scroll", not (m.get_node("ResultUI") as CanvasLayer).visible)
	_check("unlock notice stays in roll (D44)",
		(m.get_node("ResultUI/Center/VBox/UnlockLabel") as Label).visible)
	m.queue_free()

	# 6. 再演モード (オプションの「スタッフロール再演」・D64): 実ノード無しで流れ、何も保存しない。
	SaveData.reset()
	var s3: CanvasLayer = StaffRollScene.instantiate()
	root.add_child(s3)
	for i: int in range(3):
		await process_frame
	var cleared_before: Array = SaveData.cleared.duplicate()
	var coins_before: int = SaveData.coins
	s3.call("start_roll", null)
	for i: int in range(5):
		await process_frame
	_check("replay: rolling", bool(s3.get("rolling")))
	_check("replay: replay_mode が立つ", bool(s3.get("replay_mode")))
	_check("replay: 実ノード無し (_rc == null)", s3.get("_rc") == null)
	var hdr: RichTextLabel = s3.get_node("Scroller/ScrollVBox/HeaderRoll") as RichTextLabel
	_check("replay: 内蔵ヘッダーを使う (実ノード版は隠す)", hdr.visible and "再演" in hdr.text)
	_check("replay: 背景は最初から黒", absf((s3.get_node("Bg") as ColorRect).modulate.a - 1.0) < 0.01)
	_check("replay: 何も保存しない (cleared/coins 不変)",
		SaveData.cleared == cleared_before and SaveData.coins == coins_before)
	s3.call("_skip")
	for i: int in range(3):
		await process_frame
	_check("replay: スキップで最終画面", bool(s3.get("ended")) and (s3.get_node("ThanksCenter") as CenterContainer).visible)
	_check("replay: 終了ボタンはタイトルのみ", (s3.get_node("BottomBox/EndRow") as HBoxContainer).get_child_count() == 1)
	_check("replay: クリア扱いにならない (cleared 空のまま)", SaveData.cleared.is_empty())
	s3.queue_free()

	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)
