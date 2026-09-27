extends Node2D

const CG := preload("res://world/chunk_gen.gd")
const CardMarks := preload("res://data/card_marks.gd")
const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")

const MARK_CELL := 24.0
const MARK_GAP := 6.0
const MARK_SIDE := 16.0
const MARK_BOTTOM := 12.0

static var quick_start: bool = false

@onready var player: CharacterBody2D = $Player
@onready var info_label: Label = $HUD/InfoLabel
@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var lv_label: Label = $HUD/LvLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var warning_label: Label = $HUD/WarningLabel
@onready var boss_name: Label = $HUD/BossName
@onready var boss_bar: ProgressBar = $HUD/BossBar
@onready var gameover_label: Label = $HUD/GameOverLabel
@onready var card_manager: Node = $CardManager
@onready var levelup_ui: CanvasLayer = $LevelUpUI
@onready var director: Node = $SpawnDirector
@onready var title_ui: CanvasLayer = $TitleUI
@onready var pause_ui: CanvasLayer = $PauseUI
@onready var result_ui: CanvasLayer = $ResultUI
@onready var staff_roll: CanvasLayer = $StaffRollUI
@onready var audio: Node = $AudioManager
@onready var chest_director: Node = $ChestDirector
@onready var score_label: Label = $HUD/ScoreLabel
@onready var coin_label: Label = $HUD/CoinLabel
@onready var diff_label: Label = $HUD/DiffLabel
@onready var acquired_marks: GridContainer = $HUD/AcquiredMarks
@onready var bgm: Node = $BGM
@onready var options_ui: CanvasLayer = $OptionsUI
@onready var upgrade_ui: CanvasLayer = $UpgradeUI

var kills: int = 0
var score: int = 0
## ラン中の入手コイン (v1.8・D65)。金運 (M08) の倍率込みの実数で持ち、表示と確定で floor する。
var run_coins: float = 0.0
## 金運 (M08) の倍率 (start_game で確定)。
var run_coin_mult: float = 1.0
var acquired_cards: Array[String] = []
var warning_time: float = 0.0
var result_shown: bool = false
## B02撃破後のクリアカウントダウン (D25)。-1.0で非動作。
var clear_countdown: float = -1.0
var _last_count: int = -1
## CLI の --difficulty (テスト・計測用)。
var _cli_difficulty: String = ""

## ラン開始時に地形シードを決める。`_enter_tree` は子ノード (World) の `_ready` より
## 先に呼ばれるため、World が地形を生成する前にシードが確定する (§27.1)。
## セーブもここで読む: 子 (TitleUI) の `_ready` は親の `_ready` より先に走るため、
## `_ready` ではタイトルが未ロードの解放状況を表示してしまう (§31.6)。
func _enter_tree() -> void:
	SaveData.load_save()
	# 保存されたオプション (表示・音量) を起動時に適用する (v1.8・§35.9)。
	SaveData.apply_options()
	var map_seed: int = CG.begin_run(_pick_map_seed())
	print("[world] map seed = %d" % map_seed)

## マップ生成のシード。既定は毎回異なる値 (マップが毎回変わる)。
## `-- --seed 12345` を付けると固定できる (デバッグ・回帰テスト用)。
func _pick_map_seed() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--seed" and args[i + 1].is_valid_int():
			return args[i + 1].to_int()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()

func _ready() -> void:
	add_to_group("game")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--autostart" in args:
		quick_start = true
	_parse_cli_args(args)
	# CLI (--unlock-all 等) の適用後にタイトルの解放表示を再計算する (§31.6)。
	title_ui.call("refresh_difficulty")
	# CLI の難易度は常に反映する (テスト・計測用)。未指定なら前回の難易度を維持する。
	if _cli_difficulty != "":
		_set_difficulty(_cli_difficulty, false)
	card_manager.call("setup", player)
	player.connect("level_up", _on_player_level_up)
	levelup_ui.connect("choice_selected", _on_card_chosen)
	title_ui.connect("start_pressed", _on_start)
	title_ui.connect("quit_pressed", _on_desktop_quit)
	title_ui.connect("upgrade_pressed", _on_upgrade)
	title_ui.connect("options_pressed", _on_options)
	options_ui.connect("closed", _on_options_closed)
	options_ui.connect("staff_replay_pressed", _on_staff_replay)
	upgrade_ui.connect("closed", _on_upgrade_closed)
	pause_ui.connect("resume_pressed", _on_resume)
	pause_ui.connect("quit_pressed", _on_quit_to_title)
	result_ui.connect("retry_pressed", _on_retry)
	result_ui.connect("title_pressed", _on_quit_to_title)
	result_ui.connect("staff_pressed", _on_staff_roll)
	staff_roll.connect("title_pressed", _on_quit_to_title)
	_setup_acquired_marks()
	director.set("running", false)
	chest_director.set("running", false)
	if quick_start:
		# --autostart / リトライ: そのまま開始 (リトライは同じ難易度で再開する。D37)。
		start_game()
	else:
		get_tree().paused = true
		# タイトルBGM (v1.8・D61)。
		bgm.call("set_state", "title")

## CLI: `--difficulty <key|insaneN>` (例: --difficulty hard・--difficulty insane3) と
## `--unlock-all` (全難易度を解放表示。保存はしない)・`--coins <N>` (所持コインを与える。保存はしない)。
func _parse_cli_args(args: PackedStringArray) -> void:
	for i: int in range(args.size() - 1):
		if args[i] == "--difficulty" and DiffDB.is_valid(args[i + 1]):
			_cli_difficulty = args[i + 1]
		if args[i] == "--coins" and args[i + 1].is_valid_int():
			SaveData.coins = maxi(0, args[i + 1].to_int())
	if "--unlock-all" in args:
		SaveData.unlock_all()

## ランの難易度を確定する。タイトル経由では前回選択 (last) として保存する。
func _set_difficulty(key: String, save_last: bool) -> void:
	if not DiffDB.is_valid(key):
		key = "normal"
	DiffDB.current_key = key
	if save_last:
		SaveData.set_last(key)

func start_game() -> void:
	title_ui.hide()
	get_tree().paused = false
	director.set("running", true)
	chest_director.set("running", true)
	# 恒久パワーアップを反映する (v1.8・D67)。Lv0 は完全 no-op。
	MetaDB.apply_to(player, SaveData.upgrades)
	run_coin_mult = MetaDB.coin_mult(SaveData.upgrades)
	run_coins = 0.0
	if coin_label != null:
		coin_label.text = "COIN 0"
	if diff_label != null:
		diff_label.text = DiffDB.display_name(DiffDB.current_key)
	# ゲーム中BGM (v1.8・D61)。
	bgm.call("set_state", "game")

func _process(_delta: float) -> void:
	_tick_clear(_delta)
	if player != null and info_label != null:
		var fps: int = int(Engine.get_frames_per_second())
		var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
		var shot_count: int = 0
		for pr: Node in get_tree().get_nodes_in_group("projectiles"):
			if pr.get("active") == true:
				shot_count += 1
		info_label.text = "HP %d/%d XP %d/%d 撃破 %d FPS %d 敵 %d 弾 %d\nWASD/左スティック:移動 マウス/右スティック:照準" % [
			int(player.get("hp")),
			int(player.get("max_hp")),
			int(player.get("xp")),
			int(player.get("xp_next")),
			kills,
			fps,
			enemy_count,
			shot_count,
		]
	if player != null and hp_bar != null:
		hp_bar.max_value = float(player.get("max_hp"))
		hp_bar.value = float(player.get("hp"))
	if player != null and xp_bar != null:
		xp_bar.max_value = float(player.get("xp_next"))
		xp_bar.value = float(player.get("xp"))
	if player != null and lv_label != null:
		lv_label.text = "Lv %d" % int(player.get("level"))
	if score_label != null:
		score_label.text = "SCORE %d" % score
	if coin_label != null:
		coin_label.text = "COIN %d" % int(floor(run_coins))
	if timer_label != null and director != null:
		timer_label.text = _fmt_time(float(director.get("elapsed")))
	if warning_label != null:
		if warning_time > 0.0:
			warning_time -= _delta
			if warning_time <= 0.0:
				warning_label.hide()
	_update_boss_bar()
	if player != null and gameover_label != null:
		gameover_label.visible = bool(player.get("dead")) and result_shown
	if player != null and bool(player.get("dead")) and not result_shown:
		show_result(false)

func _update_boss_bar() -> void:
	var bosses: Array[Node] = get_tree().get_nodes_in_group("bosses")
	var alive: Node = null
	for b: Node in bosses:
		if not bool(b.get("dead")):
			alive = b
			break
	if alive != null:
		boss_name.text = str(alive.get("boss_name"))
		boss_name.show()
		boss_bar.max_value = float(alive.get("max_hp"))
		boss_bar.value = float(alive.get("hp"))
		boss_bar.show()
	else:
		boss_name.hide()
		boss_bar.hide()

func add_kill() -> void:
	kills += 1

func add_score(v: int) -> void:
	score += v

## コインの入手 (v1.8・D65)。金運 (M08) の倍率を掛けて加算する。確定はリザルト時 (D66)。
func add_coins(n: float) -> void:
	run_coins += n * run_coin_mult

## 取得カードの履歴表示。デバッグ文は左上の InfoLabel に集約し、
## ここは画面下部に取得順のマークだけを並べる。行数は表示幅から求め、
## パネル自体を下端基準で伸ばすことで複数行に対応する。
func _setup_acquired_marks() -> void:
	for c: Node in acquired_marks.get_children():
		c.queue_free()
	acquired_cards.clear()
	if not get_viewport().size_changed.is_connected(_layout_acquired_marks):
		get_viewport().size_changed.connect(_layout_acquired_marks)
	_layout_acquired_marks()

func _record_acquired_card(card_id: String) -> void:
	acquired_cards.append(card_id)
	var mark := TextureRect.new()
	mark.custom_minimum_size = Vector2(MARK_CELL, MARK_CELL)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.texture = CardMarks.texture_for(card_id)
	mark.tooltip_text = CardMarks.label_for(card_id)
	mark.set_meta("card_id", card_id)
	acquired_marks.add_child(mark)
	_layout_acquired_marks()

func _layout_acquired_marks() -> void:
	if acquired_marks == null:
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var avail: float = maxf(160.0, width - MARK_SIDE * 2.0)
	var columns: int = maxi(1, int(floor((avail + MARK_GAP) / (MARK_CELL + MARK_GAP))))
	acquired_marks.columns = columns
	var count := 0
	for c: Node in acquired_marks.get_children():
		if c is TextureRect and not c.is_queued_for_deletion():
			count += 1
	var rows: int = maxi(1, int(ceil(float(maxi(count, 1)) / float(columns))))
	var height: float = float(rows) * MARK_CELL + float(rows - 1) * MARK_GAP
	acquired_marks.offset_left = MARK_SIDE
	acquired_marks.offset_right = -MARK_SIDE
	acquired_marks.offset_top = -MARK_BOTTOM - height
	acquired_marks.offset_bottom = -MARK_BOTTOM
	# デバッグ文は右下・履歴の上に置く (他のUIと重ねない)。
	if info_label != null:
		info_label.offset_left = -516.0
		info_label.offset_right = -MARK_SIDE
		info_label.offset_bottom = acquired_marks.offset_top - MARK_GAP
		info_label.offset_top = info_label.offset_bottom - 44.0

func show_warning(text: String) -> void:
	if warning_label == null:
		return
	warning_label.text = text
	warning_label.show()
	warning_time = 3.0
	audio.call("play", "warn")

func on_boss2_killed() -> void:
	if result_shown or clear_countdown >= 0.0:
		return
	clear_countdown = 3.0
	_last_count = -1

func _tick_clear(delta: float) -> void:
	if clear_countdown < 0.0 or result_shown:
		return
	clear_countdown -= delta
	var n: int = int(ceil(clear_countdown))
	if n >= 1 and n != _last_count:
		_last_count = n
		if warning_label != null:
			warning_label.text = str(n)
			warning_label.show()
			warning_time = 1.2
		audio.call("play", "beep")
	if clear_countdown < 0.0:
		show_result(true)

func show_result(clear: bool) -> void:
	if result_shown:
		return
	result_shown = true
	director.set("running", false)
	chest_director.set("running", false)
	get_tree().paused = true
	if warning_label != null:
		warning_label.hide()
	audio.call("play", "clear" if clear else "death")
	# BGM はフェードアウト (v1.8・D61)。
	bgm.call("set_state", "silent")
	var unlock_text := ""
	if clear:
		unlock_text = SaveData.record_clear(DiffDB.current_key)
	# コインはリザルト表示時に確定する (v1.8・D66): floor(入手 × 難易度倍率)。
	var mult: float = DiffDB.cur_coin_mult()
	var gained: int = int(floor(run_coins * mult))
	var coin_text := ""
	if run_coins >= 1.0 or gained > 0:
		SaveData.add_coins(gained)
		coin_text = "コイン %d ×%.1f = %d (所持 %d)" % [int(floor(run_coins)), mult, gained, SaveData.coins]
	result_ui.call("show_result", clear, _fmt_time(float(director.get("elapsed"))), int(player.get("level")), kills, score, DiffDB.display_name(DiffDB.current_key), unlock_text, coin_text)

func _on_player_level_up() -> void:
	if result_shown or levelup_ui.visible:
		return
	_show_levelup()

func _show_levelup() -> void:
	player.set("pending_levels", int(player.get("pending_levels")) - 1)
	get_tree().paused = true
	audio.call("play", "levelup")
	levelup_ui.call("show_offers", card_manager.call("get_offers"))

func _on_card_chosen(card_id: String) -> void:
	card_manager.call("apply_card", card_id)
	_record_acquired_card(card_id)
	audio.call("play", "ui")
	if int(player.get("pending_levels")) > 0:
		_show_levelup()
	else:
		levelup_ui.hide()
		if not result_shown:
			get_tree().paused = false

func _on_start() -> void:
	audio.call("play", "ui")
	var key: String = str(title_ui.call("selected_key"))
	# ロック中の難易度が選ばれていたら開始しない (ボタン経由では起きないが保険)。
	if not DiffDB.is_unlocked(key, SaveData.cleared, SaveData.insane_cleared):
		key = "normal"
	_set_difficulty(key, true)
	start_game()

## タイトル「終了」→ デスクトップに戻る (D29)。
func _on_desktop_quit() -> void:
	get_tree().quit()

func _on_resume() -> void:
	pause_ui.call("close")
	get_tree().paused = false

func _on_retry() -> void:
	quick_start = true
	get_tree().paused = false
	get_tree().reload_current_scene()

## リザルト (クリア時のみ) → スタッフロール。リザルトは表示したまま渡し、
## その CLEAR!/戦績ノードをスタッフロール側がそのままスクロールさせる。
func _on_staff_roll() -> void:
	audio.call("play", "ui")
	staff_roll.call("start_roll", result_ui)

## タイトル「強化」(v1.8・D68)。
func _on_upgrade() -> void:
	audio.call("play", "ui")
	upgrade_ui.call("open")

func _on_upgrade_closed() -> void:
	# 購入の反映 (所持コイン表示)。
	title_ui.call("refresh_coins")

## タイトル「オプション」(v1.8・D63)。
func _on_options() -> void:
	audio.call("play", "ui")
	options_ui.call("open")

func _on_options_closed() -> void:
	title_ui.call("refresh_coins")

## オプションの「スタッフロール再演」(v1.8・D64)。何も保存せず再生するだけ。
func _on_staff_replay() -> void:
	audio.call("play", "ui")
	options_ui.call("close")
	title_ui.hide()
	bgm.call("set_state", "silent")
	staff_roll.call("start_roll", null)

func _on_quit_to_title() -> void:
	quick_start = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if title_ui.visible or levelup_ui.visible or result_ui.visible or staff_roll.visible:
			return
		if options_ui.visible or upgrade_ui.visible:
			return
		if get_tree().paused:
			pause_ui.call("close")
			get_tree().paused = false
		else:
			get_tree().paused = true
			pause_ui.call("open")

func _fmt_time(t: float) -> String:
	var m: int = int(t / 60.0)
	var s: int = int(t) % 60
	return "%d:%02d" % [m, s]
