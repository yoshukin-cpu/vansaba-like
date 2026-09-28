extends CanvasLayer
## ライセンス・商標表示 (v1.9・P26・SPEC §37.5)。
## オプションの「ライセンス・商標表示」から開く全画面ページ。
## 本文はテキスト定数として内蔵する (全プラットフォーム同一。Web でもファイル不要)。
## 操作: ↑↓ / スティック: スクロール (0.5s 押しっぱなしで連続)　←→: 1 ページ　
## 　　　ホイール: スクロール　Esc / A・B / 戻るボタン: 閉じる。
## モーダル方式は D74 を踏襲 (group "modal_ui"・フォーカスを使わず _unhandled_input で操作)。
## process_mode は tscn 側で ALWAYS (3)。タイトルは paused = true のため、これが無いと
## 描画はされても入力が一切届かない (v1.9 修正)。

signal closed

const SCROLL_STEP := 48
## 押しっぱなしで連続スクロールに移るまでの時間 / 連続スクロールの間隔 (秒。v1.9 追補・D94)。
const HOLD_DELAY := 0.5
const REPEAT_STEP := 0.06

const LICENSES := """[font_size=17][color=#8892a8]「Vansaba Like!」に同梱のライセンス・商標表示です。[/color][/font_size]

[font_size=24][color=#ffd75e]■ 本ゲーム — Vansaba Like![/color][/font_size]
ライセンス: MIT License
Copyright (c) 2026 yoshuki

MIT License

Copyright (c) 2026 yoshuki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[font_size=24][color=#ffd75e]■ Godot Engine 4.7.2[/color][/font_size]
ライセンス: MIT License (Copyright (c) 2014-present Godot Engine contributors / 2007-2014 Juan Linietsky, Ariel Manzur)

MIT License

Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md)
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

ライセンス全文: [url=https://godotengine.org/license]https://godotengine.org/license[/url]
サードパーティコンポーネントの一覧 (GODOT_COPYRIGHT.txt) は配布物に同梱しています。

[font_size=24][color=#ffd75e]■ フォント (SIL Open Font License 1.1)[/color][/font_size]
・Noto Sans Mono CJK JP — © 2014-2021 Adobe (http://www.adobe.com/).
・Noto Color Emoji — Copyright 2022 Google Inc.
フォント単体での販売は行いません (本ゲームへの同梱のみ)。

-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font
creation efforts of academic and linguistic communities, and to
provide a free and open framework in which fonts may be shared and
improved in partnership with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply to
any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software
components as distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to,
deleting, or substituting -- in part or in whole -- any of the
components of the Original Version, by changing formats or by porting
the Font Software to a new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed,
modify, redistribute, and sell modified and unmodified copies of the
Font Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components, in
Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the
corresponding Copyright Holder. This restriction only applies to the
primary font name as presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created using
the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.

ライセンス全文: [url=https://openfontlicense.org]https://openfontlicense.org[/url] (font/LICENSE.txt・font/OFL.txt にも同梱)

[font_size=24][color=#ffd75e]■ Godot MCP Pro アドオン (addons/godot_mcp)[/color][/font_size]
ライセンス: MIT License (アドオン部分。有料の TypeScript サーバ部分は同梱していません)
Copyright (c) 2026 Youichi Uda (y1uda)

MIT License

Copyright (c) 2026 Youichi Uda (y1uda)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[font_size=24][color=#ffd75e]■ 生成 AI 素材[/color][/font_size]
本ゲームの画像・音声の一部は生成 AI で作成しています (いずれも 1min.ai の有料プラン経由)。
・画像: gpt-image-2 (OpenAI)　・楽曲: Suno　・効果音・音声: ElevenLabs
AI 生成物には人間の著作権が及ばない可能性があるため、当方はこれらについて独占権を主張しません。

[font_size=24][color=#ffd75e]■ 商標[/color][/font_size]
「Godot Engine」は Godot Foundation の、「Noto」は Google Inc. の、「Suno」「ElevenLabs」「OpenAI」「1min.ai」は各社の商標または登録商標です。
本ページは帰属と情報提供のために記載しており、本ゲームと各社に提携・推奨関係はありません。
"""

@onready var scroll: ScrollContainer = $Panel/Scroll
@onready var body: RichTextLabel = $Panel/Scroll/Body
@onready var back_btn: Button = $Panel/BackRow/BackBtn

## スティックの上下ラッチ (倒しっぱなしで連続スクロールしない。D82 と同じ方式)。
var _axis_armed_v: bool = true
## 左右 (ページ送り) のスティックラッチ (倒しっぱなしでページが連射されない)。
var _axis_armed_h: bool = true
## 押しっぱなし連続スクロール: -1 = 上 / +1 = 下 / 0 = なし (D94)。
var _hold_dir: int = 0
var _hold_t: float = 0.0
var _repeat_t: float = 0.0


func _ready() -> void:
	visible = false
	add_to_group("modal_ui")
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(close)
	body.text = LICENSES
	body.meta_clicked.connect(_on_meta_clicked)


func open() -> void:
	visible = true
	_axis_armed_v = true
	_axis_armed_h = true
	_hold_dir = 0
	_hold_t = 0.0
	_repeat_t = 0.0
	scroll.scroll_vertical = 0
	get_viewport().gui_release_focus()


func close() -> void:
	visible = false
	closed.emit()


## リンク ([url]) はブラウザで開く (Web でも新しいタブになる)。
func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


## スクロール範囲 (末尾クランプ用・検証からも使う)。
func max_scroll() -> int:
	return maxi(0, int(body.get_combined_minimum_size().y - scroll.size.y))


func scroll_by(dy: int) -> void:
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + dy, 0, max_scroll())


## ←→ の 1 ページぶんの量 (ビューポート高 − 1 段。読み位置を見失わないよう 1 段重ねる。D94)。
func page_amount() -> int:
	return maxi(SCROLL_STEP, int(scroll.size.y) - SCROLL_STEP)


func page_by(dir: int) -> void:
	scroll_by(dir * page_amount())


## ↑↓ の押下: まず 1 段動かし、押しっぱなし (HOLD_DELAY) で連続スクロールへ (D94)。
func start_hold(dir: int) -> void:
	_hold_dir = dir
	_hold_t = 0.0
	_repeat_t = 0.0
	scroll_by(dir * SCROLL_STEP)


func _dir_pressed(dir: int) -> bool:
	if dir < 0:
		return Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_up")
	return Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_down")


func _process(delta: float) -> void:
	if not visible:
		return
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) < 0.2:
		_axis_armed_v = true
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) < 0.2:
		_axis_armed_h = true
	# 押しっぱなしの連続スクロール (離したら即停止。D94)。
	if _hold_dir == 0:
		return
	if not _dir_pressed(_hold_dir):
		_hold_dir = 0
		return
	_hold_t += delta
	if _hold_t < HOLD_DELAY:
		return
	_repeat_t += delta
	while _repeat_t >= REPEAT_STEP:
		_repeat_t -= REPEAT_STEP
		scroll_by(_hold_dir * SCROLL_STEP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	var motion: bool = event is InputEventJoypadMotion
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		if motion and not _axis_armed_v:
			return
		if motion:
			_axis_armed_v = false
		get_viewport().set_input_as_handled()
		start_hold(-1)
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		if motion and not _axis_armed_v:
			return
		if motion:
			_axis_armed_v = false
		get_viewport().set_input_as_handled()
		start_hold(1)
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if motion and not _axis_armed_h:
			return
		if motion:
			_axis_armed_h = false
		get_viewport().set_input_as_handled()
		page_by(1)
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if motion and not _axis_armed_h:
			return
		if motion:
			_axis_armed_h = false
		get_viewport().set_input_as_handled()
		page_by(-1)
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			scroll_by(-SCROLL_STEP)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			scroll_by(SCROLL_STEP)
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bi: int = (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_A or bi == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			close()
