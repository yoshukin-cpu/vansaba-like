extends CanvasLayer
## クリア後のスタッフロール。テーマソング (約4分10秒) の長さに合わせて
## 1ページずつ切り替え、曲の終わりと同時に Thanks を中央に残す。
## ツリーが paused でも動くよう process_mode は ALWAYS (tscn 側で設定)。

signal retry_pressed
signal title_pressed

const THEME_PATH := "res://audio/music/vansaba_theme_1.mp3"
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
var page_dur: float = 12.0
var elapsed: float = 0.0
var rolling: bool = false
var finale: bool = false
var ended: bool = false
var _last_idx: int = -1
var _focus_idx: int = 0

@onready var center: CenterContainer = $Center
@onready var page: RichTextLabel = $Center/Page
@onready var thanks_center: CenterContainer = $ThanksCenter
@onready var skip_hint: Label = $BottomBox/SkipHint
@onready var end_hint: Label = $BottomBox/EndHint
@onready var end_row: HBoxContainer = $BottomBox/EndRow
@onready var retry_btn: Button = $BottomBox/EndRow/RetryBtn
@onready var title_btn: Button = $BottomBox/EndRow/TitleBtn
@onready var player: AudioStreamPlayer = $ThemePlayer


func _ready() -> void:
	visible = false
	retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	title_btn.pressed.connect(func() -> void: title_pressed.emit())
	retry_btn.focus_entered.connect(_on_focus.bind(0))
	title_btn.focus_entered.connect(_on_focus.bind(1))


func _on_focus(i: int) -> void:
	_focus_idx = i


func start_roll() -> void:
	song_len = FALLBACK_LEN
	if player.stream != null:
		var l: float = player.stream.get_length()
		if l > 30.0:
			song_len = l
	page_dur = (song_len - THANKS_LEAD) / float(PAGES.size())
	elapsed = 0.0
	rolling = true
	finale = false
	ended = false
	_last_idx = -1
	center.show()
	page.text = ""
	thanks_center.hide()
	end_row.hide()
	end_hint.hide()
	skip_hint.show()
	visible = true
	player.play()


func _process(delta: float) -> void:
	if not rolling:
		return
	elapsed += delta
	if not finale:
		if elapsed >= song_len - THANKS_LEAD:
			_enter_finale()
		else:
			var idx: int = mini(int(elapsed / page_dur), PAGES.size() - 1)
			if idx != _last_idx:
				_last_idx = idx
				page.text = PAGES[idx]
	if not ended and elapsed >= song_len:
		_finish()


## スクロール終了。Thanks のみを中央に残す (曲はまだ鳴っている)。
func _enter_finale() -> void:
	finale = true
	center.hide()
	thanks_center.show()
	skip_hint.hide()


## 曲の終わりと同時。ボタンと締めの文言を出す。
func _finish() -> void:
	if ended:
		return
	ended = true
	rolling = false
	if player.playing:
		player.stop()
	end_hint.show()
	end_row.show()
	_focus_idx = 0
	retry_btn.grab_focus()


## スキップ: スクロール中は Thanks 直前へ、Thanks 中は即終了。
func _skip() -> void:
	if ended or not rolling:
		return
	if finale:
		elapsed = song_len
		_finish()
	else:
		elapsed = song_len - THANKS_LEAD
		_enter_finale()


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
