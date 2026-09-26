extends CanvasLayer
## クリア後のスタッフロール。テーマソング (約4分10秒) の長さに合わせて
## 全文を下から上へスクロールし、曲の終わりと同時に Thanks を中央に残す。
## ツリーが paused でも動くよう process_mode は ALWAYS (tscn 側で設定)。

signal retry_pressed
signal title_pressed

const THEME_PATH := "res://audio/music/vansaba_theme_1.mp3"
const LyricDB := preload("res://data/theme_lyrics.gd")
## フェード時間 / スクロール開始後の音楽開始遅延。
const FADE_DUR := 1.2
const MUSIC_DELAY := 2.0
## 段落間の空行数。曲の終わりに Thanks が来るよう、全体は曲尺いっぱいに引き延ばす。
const GAP_LINES := 6
## 曲の残りがこの秒数になったらスクロールを終え、Thanks のみ表示する。
const THANKS_LEAD := 6.0
const FALLBACK_LEN := 250.0

const PAGES: Array[String] = [
"""[center][font_size=48][color=#ffd75e]クリアおめでとう![/color][/font_size]

[font_size=26]10分間生き残った勇者に、この約4分間を贈ります。
テーマソングとともに、スタッフロールをお楽しみください。

[color=#888888]※ トイレは今のうちにどうぞ[/color][/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]総合プロデューサー[/color][/font_size]

[font_size=30]yoshuki[/font_size]

[font_size=24]原案 / 世界観設定 / 難易度最終調整
「もっと歯ごたえが欲しい」の一言で敵が1.5倍になりました。
好きな言葉:「あと1分だけ」(10回目)[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]監督・進行[/color][/font_size]

[font_size=30]Hermes Agent (AI)[/font_size]

[font_size=24]進捗管理 / 実装 / デバッグ / 深夜作業担当
カフェイン不要・睡眠不要・愚痴も言わない。
たまに暴走するのが玉にきず。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]ゲームデザイン[/color][/font_size]

[font_size=24]10分サバイブ / レベルアップ3択 / 武器6種・カード20種
「運が悪い」と言わせない設計 (※ 言う人は言う)

[color=#ffd75e]デザイン[/color]: yoshuki / Hermes Agent
[color=#ffd75e]バランス調整[/color]: yoshuki (鬼) / 不死11分走行の男[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]メインプログラマー[/color][/font_size]

[font_size=30]Hermes Agent[/font_size]

[font_size=24]武器・敵・無限マップ・宝箱・演出のすべてを担当。
バグ取りはモグラ叩き。直した数より生まれた数が多い (諸説あり)。

[color=#ffd75e]自動ツッコミ[/color]: Hermes Agent
[color=#ffd75e]深夜テンション[/color]: Hermes Agent (常時)[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]キャラクターデザイン[/color][/font_size]

[font_size=30]Google Image (1min-image)[/font_size]

[font_size=24]主人公4方向・歩くたび2フレームのドット絵職人。
足の速さ 230px/s を「速そう」に見せるのが仕事です。

[color=#ffd75e]タイトル画[/color]: Google Image (ピクセルアート)
[color=#ffd75e]ドット監修[/color]: Google Image (本人)[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]敵デザイン[/color][/font_size]

[font_size=30]Google Image (1min-image)[/font_size]

[font_size=24]スライムのつぶらな瞳、コウモリの羽ばたき、ゴーレムのカタさ。
「倒されるために生まれた」哀しみを瞳に込めました。
敵なのに、ちょっとだけ愛着が湧くのは仕様です。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]サウンド・効果音[/color][/font_size]

[font_size=30]ElevenLabs (1min-image)[/font_size]

[font_size=24]宝石のキラーン / 爆発のドーン / レベルアップのジャーン
[color=#ffd75e]声の出演[/color]: スライム役・スライム (本人)
[color=#ffd75e]断末魔の演技指導[/color]: ElevenLabs (スパルタ)[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]テーマソング[/color][/font_size]

[font_size=30]Suno (1min-image)[/font_size]

[font_size=24]「vansaba_theme_1」4分10秒
作詞・作曲・編曲・ギターソロ (架空): Suno
♪ じゅっぷんかんの王国は 終わらない ♪
このロールはこの曲の長さに合わせて引き延ばされています。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]出演 : 主人公[/color][/font_size]

[font_size=24]HP120 / 移動230px/s / 特技:自動で弾を撃つ (意思とは無関係)
好物: XP宝石。嫌いなもの: スナイパーの弾。
10分間、走って、拾って、選んで、生き残った。
主演男優賞ノミネート (自薦)。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]出演 : 敵キャスト (前半)[/color][/font_size]

[font_size=24]スライム (新人・ぷにぷに) / バット (夜行性・昼も出る)
ゴブリン (中堅・安定感) / アーチャー (遠距離恋愛中)
ウルフ (足が速い。それだけじゃない。速い。)
若手の登竜門は、主人公に轢かれることです。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]出演 : 敵キャスト (後半)[/color][/font_size]

[font_size=24]ゴーレム (カタイ) / スプリッター (分裂する人)
スナイパー (目がいい・性格は悪い) / スウォーム (群れる・群れる)
ナイト (騎士道とは無関係)
後半の給料 (難易度倍率1.5倍) でモチベーションは最高です。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]出演 : ボス[/color][/font_size]

[font_size=24]5:00 — Golem King (王なのに中ボス・複雑な心境)
10:00 — Void Emperor (ラスボス・虚無の帝王・有給消化中)
出演料: XP大宝石 (取りに来い)。
倒された瞬間、クリア画面へ直行する潔さが持ち味です。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]カード紹介 : 武器編[/color][/font_size]

[font_size=24]スピンソード / ストレートショット / ホーミングミサイル
チェインライトニング / フレイムスロワー / オービットボム
「全部欲しい」が合言葉。スロットは6つ (大人の事情)。
強化のたびに輝くエフェクトは、プログラマーの涙でできています。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]カード紹介 : ステータス編[/color][/font_size]

[font_size=24]アタックUP / クイックキャスト / マルチショット / エリアUP
持続UP / クリティカル / 弾速UP / ノックバックUP
スニーカー / ハート / リジェネ / アーマー / マグネット / 学習装置
ハートは最大HP+20 (優しさではありません)。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]宝箱・アイテム紹介[/color][/font_size]

[font_size=24]回復 / コイン / 爆弾 / 奇襲 / 経験値散布 / 一時強化
全ジェム回収 / 宝箱ラッシュ / 武器Lv+1 / ノヴァ (画面一掃)
ハズレ枠のコインは「開けたのにハズレという小さな失望」(仕様です)。
レア枠: 全回復・大金貨・武器強化 (5%の奇跡)。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]世界・美術[/color][/font_size]

[font_size=24]無限ループ世界 13,824px (約1分で一周)
「同じ景色を 何度も巡る♪」(歌詞参照)
荒野パッチ / 木と岩 (衝突あり・愛情なし) / 草原のさわやかさ
迷子になっても、世界がループするので安心です。[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]特殊スタッフ[/color][/font_size]

[font_size=24][color=#ffd75e]バグ管理部[/color]: バグ (現在も在籍・駆除は継続中)
[color=#ffd75e]テストプレイ部長[/color]: yoshuki (不死11分・297体撃破)
[color=#ffd75e]おやつ調達主任[/color]: yoshuki
[color=#ffd75e]ケータリング[/color]: 深夜のコンビニ (いつもありがとう)[/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]スペシャルサンクス[/color][/font_size]

[font_size=24]Godot Engine 4.7.2 (舞台提供)
プレイ動画を観てくれた人 (未来のあなたを含む)
このゲームを最後まで遊んでくれた………

[font_size=32][color=#ffd75e]あなたです![/color][/font_size][/font_size][/center]""",
"""[center][font_size=40][color=#ffd75e]二周目のご案内[/color][/font_size]

[font_size=24]二周目は、もっと速く・もっと強く。
宝箱は開ける。スライムは許す。コインは愛でる。
それでは最後に、あの言葉をもう一度——[/font_size][/center]""",
"""[center][font_size=56][color=#ffd75e]Thank you so much for playing.[/color][/font_size][/center]""",
]

var song_len: float = FALLBACK_LEN
var scroll_time: float = 60.0
var elapsed: float = 0.0
var rolling: bool = false
var finale: bool = false
var ended: bool = false
var music_started: bool = false
var _start_y: float = 0.0
var _end_y: float = 0.0
var _focus_idx: int = 0
## 時刻付き歌詞と表示中行のキー (無駄な書き換え防止)。
var _lyrics: Array = []
var _lyric_key := ""
## リザルト側の実ノード (CLEAR!/戦績をそのままスクロールさせる)。
var _res: CanvasLayer = null
var _rc: Control = null
var _header_h: float = 0.0

@onready var bg: ColorRect = $Bg
@onready var scroller: Control = $Scroller
@onready var vbox: VBoxContainer = $Scroller/ScrollVBox
@onready var header: RichTextLabel = $Scroller/ScrollVBox/HeaderRoll
@onready var spacer: Control = $Scroller/ScrollVBox/Spacer
@onready var roll: RichTextLabel = $Scroller/ScrollVBox/MainRoll
@onready var thanks_center: CenterContainer = $ThanksCenter
@onready var skip_hint: Label = $SkipHint
@onready var end_hint: Label = $BottomBox/EndHint
@onready var end_row: HBoxContainer = $BottomBox/EndRow
@onready var retry_btn: Button = $BottomBox/EndRow/RetryBtn
@onready var title_btn: Button = $BottomBox/EndRow/TitleBtn
@onready var player: AudioStreamPlayer = $ThemePlayer
@onready var lyric_bar: PanelContainer = $LyricBar
@onready var lyric_cur: Label = $LyricBar/LyricCur


func _ready() -> void:
	visible = false
	retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	title_btn.pressed.connect(func() -> void: title_pressed.emit())
	retry_btn.focus_entered.connect(_on_focus.bind(0))
	title_btn.focus_entered.connect(_on_focus.bind(1))


func _on_focus(i: int) -> void:
	_focus_idx = i


## res: リザルト UI。その CLEAR!/戦績ノードをそのままスクロールさせる
## (位置・大きさ・色が完全に一致する)。背景はリザルトの Dim が黒くする。
func start_roll(res: CanvasLayer) -> void:
	song_len = FALLBACK_LEN
	if player.stream != null:
		var l: float = player.stream.get_length()
		if l > 30.0:
			song_len = l
	# 曲の尺 (Thanks 分を除く) いっぱいに引き延ばし、Thanks が曲終わりに来るようにする。
	scroll_time = song_len - THANKS_LEAD
	_res = res
	_rc = res.get_node("Center") as Control
	_header_h = (res.get_node("Center/VBox") as Control).size.y
	# 内蔵ヘッダーは使わない (実ノードが先頭になる)。
	header.hide()
	_lyrics = LyricDB.load_timed()
	_lyric_key = ""
	lyric_bar.hide()
	# 段落間を広めに空けて結合する (空行で時間も稼ぐ)。
	roll.text = "\n".repeat(GAP_LINES).join(PackedStringArray(PAGES))
	var vh: float = get_viewport().get_visible_rect().size.y
	# ヘッダーがスクロールアウトした直後に最初の文言が入るよう、1画面ぶん空ける。
	spacer.custom_minimum_size = Vector2(0, vh)
	elapsed = 0.0
	rolling = true
	finale = false
	ended = false
	music_started = false
	# 背景は透明のまま (リザルトの Dim が黒)。交換時に不透明化する。
	bg.modulate.a = 0.0
	scroller.show()
	thanks_center.hide()
	end_row.hide()
	end_hint.hide()
	skip_hint.show()
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if not rolling:
		return
	var total_h: float = vbox.get_combined_minimum_size().y
	# 本文先頭が実ヘッダーの下端から1画面ぶん下に来るよう配置し、末端が消えるまで流す。
	_start_y = snappedf((vh + _header_h) * 0.5, 1.0)
	_end_y = snappedf(-(total_h + 64.0), 1.0)
	scroller.position.y = _start_y
	_rc.position.y = 0.0
	elapsed = 0.0


func _process(delta: float) -> void:
	if not rolling:
		return
	elapsed += delta
	var st: float = elapsed - FADE_DUR
	if st < 0.0:
		return
	# 音楽はスクロール開始の2秒後に開始する。
	if not music_started and st >= MUSIC_DELAY:
		music_started = true
		player.play()
	if not finale:
		if st >= scroll_time:
			_enter_finale()
		else:
			var t: float = clampf(st / scroll_time, 0.0, 1.0)
			var y: float = snappedf(lerpf(_start_y, _end_y, t), 1.0)
			scroller.position.y = y
			# 実ヘッダー (リザルトの文字) を同じ量だけ上げ、完全一致でスクロールさせる。
			if _rc != null:
				_rc.position.y = snappedf(y - _start_y, 1.0)
			# 実ヘッダーが抜け切ったらリザルトを隠し、背景を不透明化する。
			if y <= 0.0:
				_swap_to_black()
		# 曲位置に合わせて歌詞バーを更新する (クレジットとは独立の下部固定表示)。
		_update_lyrics(st - MUSIC_DELAY)
	# 曲の終わりと同時に最終画面へ。
	if not ended and elapsed >= FADE_DUR + MUSIC_DELAY + song_len:
		_finish()


## 実ヘッダー抜け切り: リザルトを隠し、背景を黒にする (同フレームで違和感なし)。
func _swap_to_black() -> void:
	bg.modulate.a = 1.0
	if _res != null:
		_res.hide()
		_res = null
	_rc = null


## 曲位置 (曲頭からの秒) に合わせて歌詞バーを更新する。空行は非表示。
func _update_lyrics(song_pos: float) -> void:
	if song_pos < 0.0:
		lyric_bar.hide()
		_lyric_key = ""
		return
	var line: Dictionary = LyricDB.line_at(_lyrics, song_pos)
	var cur: String = str(line["cur"])
	if cur == "":
		lyric_bar.hide()
		_lyric_key = ""
		return
	var key: String = cur
	if key == _lyric_key:
		return
	_lyric_key = key
	lyric_cur.text = cur
	lyric_bar.show()


## スクロール終了。Thanks のみを中央に残す (曲はまだ鳴っている)。
func _enter_finale() -> void:
	finale = true
	_swap_to_black()
	lyric_bar.hide()
	scroller.hide()
	thanks_center.show()
	skip_hint.hide()


## 曲の終わりと同時。Thanks + ボタンの最終画面を出す。
func _finish() -> void:
	if ended:
		return
	ended = true
	rolling = false
	if player.playing:
		player.stop()
	_swap_to_black()
	lyric_bar.hide()
	scroller.hide()
	skip_hint.hide()
	thanks_center.show()
	end_hint.show()
	end_row.show()
	_focus_idx = 0
	retry_btn.grab_focus()


## スキップ: 即座に最終画面 (Thanks + ボタン) を出す。
func _skip() -> void:
	if ended or not rolling:
		return
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 終了後のパッド A はフォーカス中のボタンへ振り分ける
	# (ボタンは A を自動処理しないため。title_ui.gd と同じ方式)。
	if ended:
		if event is InputEventJoypadButton and event.pressed:
			if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
				if _focus_idx == 0:
					retry_pressed.emit()
				else:
					title_pressed.emit()
		return
	if not rolling:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_skip()
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_skip()
			return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_skip()
		return
