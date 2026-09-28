extends Node
## BGM 3曲 (タイトル/ゲーム中/ボス) の再生とフェード切替 (SPEC §35.1、v1.8/案6)。
## - スタッフロールは既存の主題歌 (staff_roll_ui) が受け持つため、ここでは扱わない。
## - process_mode は ALWAYS (tscn で設定)。レベルアップ・ポーズの paused 中も鳴り続ける。
## - ボス判定は `bosses` グループの生存を毎フレーム見る (B01/B02 の区別はしない)。
## - game→boss のときは game の再生位置を保存し、boss→game で「フェードアウトしたところから」再開する。

const TRACKS := {
	"title": "res://audio/music/bgm_title.mp3",
	"game": "res://audio/music/bgm_game.mp3",
	"boss": "res://audio/music/bgm_boss.mp3",
}
## トラックの基準音量 (要件: ゲーム中は抑えめ。追補3/D80 で −14 → −10dB に上げた)。
const TRACK_DB := {"title": -8.0, "game": -10.0, "boss": -10.0}
## 無音とみなす下限 (フェードの開始・終了に使う)。
const SILENT_DB := -60.0

const FADE_IN := 0.8
const FADE_OUT := 1.0
const FADE_OUT_SILENT := 1.2
const BOSS_FADE_IN := 0.5
## 再開位置が曲尾からこの秒数以内なら頭 (= 0) に回す (web の再ループが offset 起点のため)。
const TAIL_GUARD := 0.5

enum State { SILENT, TITLE, GAME, BOSS }

var state: int = State.SILENT
## game 曲の再開位置 (フェードアウト開始時に保存)。常に 0 <= game_pos < 曲長。
var game_pos: float = 0.0
## game 曲の経過時間の自前計測 (秒・ループしても巻き戻さない生の値)。
## web の get_playback_position() はループで 0 に戻らず累積し (実測: 5分走ると
## 94.8秒の曲で 300 近くを返す)、実時間とも大きくずれる (位置 Worklet が
## 毎クオンタム処理されない) ため再開位置の根拠に使えない。
## 曲長以上の位置を play() に渡すと web では無音になる (WebAudio の仕様)。
var game_elapsed: float = 0.0
## 直近の boss→game 再開で使った位置 (検証用の観測値)。
var last_resume_pos: float = -1.0
## 進行中のフェード: player名 -> {"from", "to", "t", "dur", "stop"}。
var fades: Dictionary = {}

@onready var p_title: AudioStreamPlayer = $BgmTitle
@onready var p_game: AudioStreamPlayer = $BgmGame
@onready var p_boss: AudioStreamPlayer = $BgmBoss


func _ready() -> void:
	add_to_group("bgm")
	# フェードは paused (レベルアップ・ポーズ・リザルト) 中も進める必要がある。
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in TRACKS.keys():
		var pl: AudioStreamPlayer = _player_for(key)
		var s: AudioStream = load(str(TRACKS[key]))
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		pl.stream = s
		pl.bus = "BGM"
		pl.volume_db = SILENT_DB
		pl.process_mode = Node.PROCESS_MODE_ALWAYS


func _player_for(key: String) -> AudioStreamPlayer:
	match key:
		"title":
			return p_title
		"game":
			return p_game
		_:
			return p_boss


func _key_for(pl: AudioStreamPlayer) -> String:
	if pl == p_title:
		return "title"
	if pl == p_game:
		return "game"
	return "boss"


## main からの状態指示: "title" / "game" / "result" / "staff" / "silent" / "boss"。
func set_state(sname: String) -> void:
	match sname:
		"title":
			_to_title()
		"game":
			_to_game()
		"boss":
			_to_boss()
		_:
			_to_silent()


func _to_title() -> void:
	if state == State.TITLE:
		return
	_save_game_pos()
	_fade_all_out(FADE_IN)
	_start(p_title, FADE_IN)
	state = State.TITLE


func _to_game() -> void:
	if state == State.GAME:
		return
	if state == State.BOSS:
		# ボス撃破: boss をフェードアウトし、game を保存位置からフェードインで再開する。
		_fade(p_boss, SILENT_DB, FADE_OUT, true)
		last_resume_pos = game_pos
		# 自前計測も再開位置に合わせて継続する (以後の経過が保存位置と連続になる)。
		game_elapsed = game_pos
		p_game.play(game_pos)
		p_game.volume_db = SILENT_DB
		_fade(p_game, float(TRACK_DB["game"]), BOSS_FADE_IN)
		state = State.GAME
		return
	# 新規ラン (タイトル/無音から): 頭から。
	_save_game_pos()
	_fade_all_out(FADE_IN)
	game_elapsed = 0.0
	p_game.play(0.0)
	p_game.volume_db = SILENT_DB
	_fade(p_game, float(TRACK_DB["game"]), FADE_IN)
	state = State.GAME


func _to_boss() -> void:
	if state == State.BOSS:
		return
	_save_game_pos()
	_fade(p_title, SILENT_DB, FADE_OUT, true)
	_fade(p_game, SILENT_DB, FADE_OUT, true)
	p_boss.play(0.0)
	p_boss.volume_db = SILENT_DB
	_fade(p_boss, float(TRACK_DB["boss"]), BOSS_FADE_IN)
	state = State.BOSS


func _to_silent() -> void:
	if state == State.SILENT:
		return
	_save_game_pos()
	_fade_all_out(FADE_OUT_SILENT)
	state = State.SILENT


func _save_game_pos() -> void:
	if p_game != null and p_game.playing:
		game_pos = _wrap_pos(game_elapsed)


## game 曲の長さ (秒)。読めなければ 0。
func _game_len() -> float:
	if p_game != null and p_game.stream != null:
		return p_game.stream.get_length()
	return 0.0


## 再開位置を 0 <= 戻り値 < 曲長 に畳む。
## web (WebAudio) では曲長以上の offset を渡すと無音になり、さらに
## 「鳴らない→ended→再start」の空ループが走るため、範囲外は絶対に渡さない。
## 曲尾の直前 (最後の 0.5s) も頭に回す: web のループ再開は「渡した offset」から
## やり直すため、尾の余韻に居座ると実質無音のループになりうる。
## 曲長の判定ができなければ頭 (= 0) から鳴らす方を選ぶ。
func _wrap_pos(t: float) -> float:
	var l: float = _game_len()
	if l <= 0.0:
		return 0.0
	var p: float = fposmod(t, l)
	if p > l - TAIL_GUARD:
		return 0.0
	return p


func _start(pl: AudioStreamPlayer, fade_in: float) -> void:
	pl.play(0.0)
	pl.volume_db = SILENT_DB
	_fade(pl, float(TRACK_DB[_key_for(pl)]), fade_in)


func _fade_all_out(dur: float) -> void:
	for key: String in TRACKS.keys():
		var pl: AudioStreamPlayer = _player_for(key)
		if pl.playing:
			_fade(pl, SILENT_DB, dur, true)
		else:
			pl.volume_db = SILENT_DB


func _fade(pl: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool = false) -> void:
	if dur <= 0.0:
		pl.volume_db = to_db
		if stop_after:
			pl.stop()
		return
	var from_db: float = pl.volume_db
	if not pl.playing:
		# 停止中の player は下限から始める (以後のフェードは鳴っている前提)。
		from_db = to_db if to_db <= SILENT_DB else SILENT_DB
	fades[_key_for(pl)] = {"from": from_db, "to": to_db, "t": 0.0, "dur": dur, "stop": stop_after}


func _process(delta: float) -> void:
	# game 曲の経過を自前計測する (get_playback_position() は web で信用できない)。
	# paused 中も鳴り続けるため、ここ (PROCESS_MODE_ALWAYS) で毎フレーム進める。
	if p_game != null and p_game.playing:
		game_elapsed += delta
	_advance_fades(delta)
	if state == State.GAME and _boss_alive():
		_to_boss()
	elif state == State.BOSS and not _boss_alive():
		_to_game()


func _advance_fades(delta: float) -> void:
	if fades.is_empty():
		return
	for key: String in fades.keys().duplicate():
		var f: Dictionary = fades[key]
		var pl: AudioStreamPlayer = _player_for(key)
		f["t"] = float(f["t"]) + delta
		var k: float = clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		pl.volume_db = lerpf(float(f["from"]), float(f["to"]), k)
		if k >= 1.0:
			pl.volume_db = float(f["to"])
			if bool(f["stop"]):
				pl.stop()
			fades.erase(key)


func _boss_alive() -> bool:
	for b: Node in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not bool(b.get("dead")):
			return true
	return false
