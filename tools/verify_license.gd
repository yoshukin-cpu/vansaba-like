extends SceneTree
## ライセンス・商標表示 (v1.9・P26・D87/SPEC §37.5) の検証:
## 必須文字列 (MIT/OFL/帰属/商標)・「1min-image」「Google Image」不在・
## スクロール (先頭/末尾クランプ)・開閉 (closed シグナル)・main の配線。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_license.gd

const LicenseScene: PackedScene = preload("res://ui/license_ui.tscn")
const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")

const TEST_SAVE := "user://test_license_save.json"

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


## 実入力の注入 (test_title_input.gd と同じ方式。headless でもキー/アクション/パッドは届く)。
func _key_ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	return ev


func _event(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _action(name: String) -> void:
	var down := InputEventAction.new()
	down.action = name
	down.pressed = true
	await _event(down)
	var up := InputEventAction.new()
	up.action = name
	up.pressed = false
	await _event(up)


func _joy(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	await _event(ev)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	await _event(up)


func _initialize() -> void:
	# レイアウト依存の検証は設計サイズにする (headless のルート viewport は 100×100)。
	root.size = Vector2i(1152, 648)
	var lic: CanvasLayer = LicenseScene.instantiate()
	root.add_child(lic)
	for i: int in range(3):
		await process_frame

	print("\n=== 1) 内容 ===")
	var body: RichTextLabel = lic.get_node("Panel/Scroll/Body")
	var text: String = body.text
	_check("本文が内蔵されている (>7000 文字)", text.length() > 7000)
	for needle: String in ["MIT License", "SIL OPEN FONT LICENSE Version 1.1", "Godot Engine", "godotengine.org/license",
			"Noto Sans Mono CJK JP", "Noto Color Emoji", "openfontlicense.org", "godot_mcp", "Youichi Uda",
			"Suno", "ElevenLabs", "gpt-image-2", "1min.ai", "Godot Foundation", "商標"]:
		_check("記載あり: " + needle, needle in text)
	_check("旧表記 1min-image が無い", not ("1min-image" in text))
	_check("旧表記 Google Image が無い", not ("Google Image" in text))

	print("\n=== 2) 開閉 ===")
	var closed_fired := [false]
	lic.connect("closed", func() -> void: closed_fired[0] = true)
	_check("開始時は非表示", not lic.visible)
	lic.call("open")
	_check("open で表示", lic.visible)
	var scroll: ScrollContainer = lic.get_node("Panel/Scroll")
	_check("open で先頭に戻る", scroll.scroll_vertical == 0)

	print("\n=== 3) スクロール ===")
	lic.call("scroll_by", -100)
	_check("上端でクランプ", scroll.scroll_vertical == 0)
	var maxv: int = int(lic.call("max_scroll"))
	_check("末尾は先頭より下 (max_scroll > 0)", maxv > 0)
	lic.call("scroll_by", 100)
	_check("100px 下がる", scroll.scroll_vertical == mini(100, maxv))
	lic.call("scroll_by", 999999)
	_check("末尾でクランプ", scroll.scroll_vertical == maxv)
	lic.call("open")
	_check("開き直すと先頭に戻る", scroll.scroll_vertical == 0)

	print("\n=== 4) 閉じる ===")
	lic.call("close")
	_check("close で非表示", not lic.visible)
	_check("closed シグナルが発火", closed_fired[0])
	_check("modal_ui グループに入る", lic.is_in_group("modal_ui"))
	lic.free()

	print("\n=== 5) main の配線 (ソース確認) ===")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_check("license_pressed を配線", "options_ui.connect(\"license_pressed\", _on_options_license)" in main_src)
	_check("閉じたらオプションへ戻す", "func _on_license_closed" in main_src and "options_ui.call(\"open\")" in main_src)
	_check("ポーズガードに license_ui", "license_ui.visible" in main_src)
	var tscn_src: String = FileAccess.get_file_as_string("res://main.tscn")
	_check("main.tscn に LicenseUI", "LicenseUI" in tscn_src and "res://ui/license_ui.tscn" in tscn_src)

	print("\n=== 6) 実入力経路 (タイトルは paused = true。この状態で全入力が効く必要がある) ===")
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	SaveData.reset()
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	_check("タイトルは paused = true (仕様・main.gd:121)", paused)
	main.call("_on_options")
	for i: int in range(6):
		await process_frame
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var lic2: CanvasLayer = main.get_node("LicenseUI")
	var rows2: Array = opts.get("rows")
	var lic_i: int = -1
	for i2: int in range(rows2.size()):
		if str((rows2[i2] as Dictionary)["id"]) == "license":
			lic_i = i2
	opts.set("idx", lic_i)
	opts.call("_activate")
	for i3: int in range(6):
		await process_frame
	_check("オプション → ライセンスが開く (paused 中)", lic2.visible and not opts.visible)
	var scroll2: ScrollContainer = lic2.get_node("Panel/Scroll")
	var before: int = scroll2.scroll_vertical
	await _action("ui_down")
	_check("↓ でスクロールする (paused 中)", scroll2.scroll_vertical > before)
	await _joy(JOY_BUTTON_B)
	_check("パッド B で閉じてオプションへ戻る", not lic2.visible and opts.visible)
	opts.call("_activate")
	for i4: int in range(6):
		await process_frame
	_check("再オープンできる", lic2.visible and not opts.visible)
	await _event(_key_ev(KEY_ESCAPE, true))
	await _event(_key_ev(KEY_ESCAPE, false))
	_check("Esc で閉じてオプションへ戻る", not lic2.visible and opts.visible)
	opts.call("_activate")
	for i5: int in range(6):
		await process_frame
	await _joy(JOY_BUTTON_A)
	_check("パッド A でも閉じる (v1.9 追補)", not lic2.visible and opts.visible)

	print("\nRESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit()
