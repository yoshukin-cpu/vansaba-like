extends SceneTree
## ライセンス・商標表示 (v1.9・P26・D87/SPEC §37.5) の検証:
## 必須文字列 (MIT/OFL/帰属/商標)・「1min-image」「Google Image」不在・
## スクロール (先頭/末尾クランプ)・開閉 (closed シグナル)・main の配線。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_license.gd

const LicenseScene: PackedScene = preload("res://ui/license_ui.tscn")

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


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

	print("\nRESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit()
