extends SceneTree
## タイトル画面の確定入力 (キー/パッド) の回帰テスト。
## 「終了」にフォーカスがある状態で確定しても、ゲームが始まらず終了すること。
## ロック中の難易度を選んでいるときも、パッドのAで「終了」できること (不具合修正)。
## 実行: godot --path <project> --headless --script res://tools/test_title_input.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")

const TEST_SAVE := "user://test_title_input_save.json"

var fails := 0
var starts := 0
var quits := 0
var btn_pressed := 0
var cur: Node = null


func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	# 開始時の last 保存が実セーブを汚さないよう、一時パスを使う (v1.6)。
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	SaveData.reset()
	await _case("1) はじめる + Enter", "start", "key", true)
	await _case("2) 終了 (直接フォーカス) + Enter", "quit", "key", false)
	await _case("3) 終了 (直接フォーカス) + Space", "quit", "space", false)
	await _case("4) 終了 (直接フォーカス) + パッドA", "quit", "pad", false)
	await _case("5) はじめる + パッドA", "start", "pad", true)
	await _case("6) ui_down で 終了 に移動 + Enter", "nav_key", "key", false)
	await _case("7) パッド十字↓で 終了 に移動 + パッドA", "nav_pad", "pad", false)
	await _case("8) はじめる (直接フォーカス) + Space", "start", "space", true)
	await _case9_locked_quit()
	await _case10_locked_start()
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)


## sel: start = はじめる にフォーカス / quit = 終了 に直接フォーカス /
##      nav_key・nav_pad = はじめる から下へ移動して 終了 を選ぶ
func _case(tag: String, sel: String, how: String, expect_start: bool) -> void:
	print("\n=== %s ===" % tag)
	if cur != null and is_instance_valid(cur):
		cur.queue_free()
		await process_frame
	var m: Node = MainScene.instantiate()
	root.add_child(m)
	current_scene = m
	for i: int in range(20):
		await process_frame
	cur = m
	var title: CanvasLayer = m.get_node("TitleUI")
	starts = 0
	quits = 0
	btn_pressed = 0
	# 本物の quit はプロセスを終了させるため、接続を張り替えて数える
	_check("%s: quit -> _on_desktop_quit 接続あり" % tag,
		title.is_connected("quit_pressed", Callable(m, "_on_desktop_quit")))
	title.disconnect("quit_pressed", Callable(m, "_on_desktop_quit"))
	title.connect("quit_pressed", func() -> void: quits += 1)
	title.connect("start_pressed", func() -> void: starts += 1)
	var sbtn: Button = title.get_node("Center/VBox/StartBtn")
	var qbtn: Button = title.get_node("QuitBtn")
	sbtn.pressed.connect(func() -> void: btn_pressed += 1)
	qbtn.pressed.connect(func() -> void: btn_pressed += 1)
	if sel == "quit":
		qbtn.grab_focus()
		await process_frame
		await process_frame
	if sel == "nav_key" or sel == "nav_pad":
		# v1.8: タイトルに「強化」「オプション」が入り、終了までは↓3回
		# (はじめる → 強化 → オプション → 終了)。
		for i: int in range(3):
			await _nav_down(sel == "nav_pad")
	var focus: Control = root.gui_get_focus_owner()
	var want: Button = qbtn if sel != "start" else sbtn
	_check("%s: フォーカスが %s (%s)" % [tag, want.name, str(focus != null and focus.name)], focus == want)
	if how == "pad":
		await _pad_a()
	else:
		await _key(KEY_ENTER if how == "key" else KEY_SPACE)
	var playing: bool = not title.visible
	_check("%s: ゲームが始まる = %s" % [tag, str(expect_start)], playing == expect_start)
	_check("%s: start_pressed=%d quit_pressed=%d" % [tag, starts, quits],
		(starts == 1 and quits == 0) if expect_start else (quits == 1 and starts == 0))
	_check("%s: 押されたボタンは1回だけ" % tag, btn_pressed == 1)


func _nav_down(pad: bool) -> void:
	if pad:
		# 既定の ui_down には十字キー下 (button 12) が入っている
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_DPAD_DOWN
		ev.pressed = true
		await _event(ev)
		var up := InputEventJoypadButton.new()
		up.button_index = JOY_BUTTON_DPAD_DOWN
		up.pressed = false
		await _event(up)
		return
	await _action("ui_down")


func _key(code: Key) -> void:
	await _event(_key_ev(code, true))
	var up: InputEventKey = _key_ev(code, false)
	await _event(up)


func _key_ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	return ev


func _pad_a() -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	await _event(ev)
	var up := InputEventJoypadButton.new()
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	await _event(up)


func _action(name: String) -> void:
	var down := InputEventAction.new()
	down.action = name
	down.pressed = true
	await _event(down)
	var up := InputEventAction.new()
	up.action = name
	up.pressed = false
	await _event(up)


func _event(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


## ロック中の難易度 (エキスパート) を選択した状態のタイトルを作る (セーブは cleared=["normal"])。
func _setup_locked() -> Node:
	if cur != null and is_instance_valid(cur):
		cur.queue_free()
		await process_frame
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.insane_cleared = 0
	SaveData.last = "normal"
	SaveData.save_now()
	var m: Node = MainScene.instantiate()
	root.add_child(m)
	current_scene = m
	for i: int in range(20):
		await process_frame
	cur = m
	var title: CanvasLayer = m.get_node("TitleUI")
	# セレクタ解放済み → ノーマルから▶2回で エキスパート (ロック中) へ。
	title.call("_cycle", 1)
	title.call("_cycle", 1)
	await process_frame
	return m


## 9) ロック中の難易度を選んだまま 終了 (パッドA) → 終われること (修正の回帰)。
func _case9_locked_quit() -> void:
	print("\n=== 9) ロック中の難易度 + 終了 (直接フォーカス) + パッドA ===")
	var m: Node = await _setup_locked()
	var title: CanvasLayer = m.get_node("TitleUI")
	starts = 0
	quits = 0
	btn_pressed = 0
	title.disconnect("quit_pressed", Callable(m, "_on_desktop_quit"))
	title.connect("quit_pressed", func() -> void: quits += 1)
	title.connect("start_pressed", func() -> void: starts += 1)
	var sbtn: Button = title.get_node("Center/VBox/StartBtn")
	var qbtn: Button = title.get_node("QuitBtn")
	sbtn.pressed.connect(func() -> void: btn_pressed += 1)
	qbtn.pressed.connect(func() -> void: btn_pressed += 1)
	_check("9: ロック中の選択で開始ボタンが無効", sbtn.disabled)
	qbtn.grab_focus()
	await process_frame
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	_check("9: フォーカスが 終了 (%s)" % str(focus != null and focus.name), focus == qbtn)
	await _pad_a()
	_check("9: ゲームが始まらない (title visible=%s)" % str(title.visible), title.visible)
	_check("9: パッドで終了できた (quit_pressed=%d)" % quits, quits == 1 and starts == 0)
	_check("9: 押されたボタンは1回だけ", btn_pressed == 1)


## 10) ロック中の難易度 + はじめる (パッドA) → 何も起きないこと (D40 の維持)。
func _case10_locked_start() -> void:
	print("\n=== 10) ロック中の難易度 + はじめる (直接フォーカス) + パッドA ===")
	var m: Node = await _setup_locked()
	var title: CanvasLayer = m.get_node("TitleUI")
	starts = 0
	quits = 0
	btn_pressed = 0
	title.disconnect("quit_pressed", Callable(m, "_on_desktop_quit"))
	title.connect("quit_pressed", func() -> void: quits += 1)
	title.connect("start_pressed", func() -> void: starts += 1)
	var sbtn: Button = title.get_node("Center/VBox/StartBtn")
	var qbtn: Button = title.get_node("QuitBtn")
	sbtn.pressed.connect(func() -> void: btn_pressed += 1)
	qbtn.pressed.connect(func() -> void: btn_pressed += 1)
	_check("10: ロック中の選択で開始ボタンが無効", sbtn.disabled)
	sbtn.grab_focus()
	await process_frame
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	_check("10: フォーカスが はじめる (%s)" % str(focus != null and focus.name), focus == sbtn)
	await _pad_a()
	_check("10: ゲームが始まらない (title visible=%s)" % str(title.visible), title.visible)
	_check("10: start=0 quit=0 (何も起きない)", starts == 0 and quits == 0)
	_check("10: 押されたボタンは0回", btn_pressed == 0)
