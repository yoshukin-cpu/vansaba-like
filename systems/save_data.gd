extends RefCounted
## セーブ (`user://vansaba_save.json`)。v1.8 で v2 に拡張 (SPEC §35.9)。
## v2: 難易度の解放状況+前回選択 (v1) + コイン / 恒久パワーアップ / オプション。
## v1 ファイル (coins/upgrades/options なし) も読める (欠けている項目は既定値)。

const DiffDB := preload("res://data/difficulty_db.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")
const OptDB := preload("res://data/options_db.gd")

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://vansaba_save.json"

## 保存先。検証スクリプトは一時パスへ差し替える。
static var path: String = DEFAULT_PATH
## クリア済みの難易度キー (インセインN は含めない)。
static var cleared: Array = []
## クリア済みインセインN の最大 N (0 = インセイン1未クリア)。
static var insane_cleared: int = 0
## 前回選んだ難易度 (タイトルの初期カーソル)。
static var last: String = "normal"
## 所持コイン (v1.8・D65/D66)。
static var coins: int = 0
## 恒久パワーアップのレベル {"M01": 2, ...} (v1.8・D67)。
static var upgrades: Dictionary = {}
## オプション (表示・音量) (v1.8・D62/D63/D69)。
static var options: Dictionary = {}


static func default_options() -> Dictionary:
	return {
		"mode": OptDB.MODE_WINDOW,
		"resolution": "1152x648",
		"bgm": OptDB.DEFAULT_BGM,
		"se": OptDB.DEFAULT_SE,
	}


static func reset() -> void:
	cleared = []
	insane_cleared = 0
	last = "normal"
	coins = 0
	upgrades = {}
	options = default_options()


## 進行状況だけを初期化して保存する (v1.8・D76)。オプション設定 (表示・音量) は保持する。
static func reset_progress() -> void:
	cleared = []
	insane_cleared = 0
	last = "normal"
	coins = 0
	upgrades = {}
	save_now()


## 起動時の読み込み。壊れていれば初期状態 (ノーマルのみ) に戻す。
static func load_save() -> void:
	reset()
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return
	var d: Dictionary = data as Dictionary
	var cl: Variant = d.get("cleared", [])
	if cl is Array:
		for k: Variant in cl as Array:
			var key: String = str(k)
			if DiffDB.KEYS.has(key):
				cleared.append(key)
	var ic: Variant = d.get("insane_cleared", 0)
	if ic is float or ic is int:
		insane_cleared = maxi(0, int(ic))
	var l: Variant = d.get("last", "normal")
	if l is String and DiffDB.is_valid(str(l)):
		last = str(l)
	# --- v1.8 で追加 (v1 ファイルでは既定値のまま) ---
	var c: Variant = d.get("coins", 0)
	if c is float or c is int:
		coins = maxi(0, int(c))
	var up: Variant = d.get("upgrades", {})
	if up is Dictionary:
		for k: Variant in (up as Dictionary).keys():
			var id: String = str(k)
			if MetaDB.has_id(id):
				var lv: Variant = (up as Dictionary)[k]
				if lv is float or lv is int:
					upgrades[id] = clampi(int(lv), 0, MetaDB.max_level(id))
	var op: Variant = d.get("options", {})
	if op is Dictionary:
		_merge_options(op as Dictionary)


static func _merge_options(op: Dictionary) -> void:
	var m: String = str(op.get("mode", options["mode"]))
	if m == OptDB.MODE_WINDOW or m == OptDB.MODE_FULLSCREEN:
		options["mode"] = m
	var r: String = str(op.get("resolution", options["resolution"]))
	if OptDB.is_valid_resolution(r):
		options["resolution"] = r
	if op.has("bgm"):
		options["bgm"] = OptDB.clamp_volume(float(op["bgm"]))
	if op.has("se"):
		options["se"] = OptDB.clamp_volume(float(op["se"]))


static func save_now() -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"cleared": cleared,
		"insane_cleared": insane_cleared,
		"last": last,
		"coins": coins,
		"upgrades": upgrades,
		"options": options,
	}))
	f.close()


## クリアを記録して保存し、新しく解放されたものの通知文を返す ("" = 通知なし)。
static func record_clear(key: String) -> String:
	var first: bool = cleared.is_empty() and insane_cleared == 0
	var before: String = DiffDB.first_locked_key(cleared, insane_cleared)
	var p: Dictionary = DiffDB.parse_key(key)
	var base: String = str(p["key"])
	var ins: int = int(p["insane"])
	if base == "insane" and ins > 0:
		insane_cleared = maxi(insane_cleared, ins)
	else:
		if not cleared.has(base):
			cleared.append(base)
	save_now()
	if first:
		return "解放: 難易度選択!"
	var after: String = DiffDB.first_locked_key(cleared, insane_cleared)
	if before != "" and before != after:
		return "解放: %s!" % DiffDB.display_name(before)
	return ""


## 前回選択の保存 (タイトルで難易度を決めて開始した時)。
static func set_last(key: String) -> void:
	last = key
	save_now()


# --- コイン (v1.8・D65/D66) ---

static func add_coins(n: int) -> void:
	coins = maxi(0, coins + n)
	save_now()


## コインを消費する (保存は呼び出し側に任せる。purchase() は内部で保存する)。
static func spend_coins(n: int) -> bool:
	if n < 0 or coins < n:
		return false
	coins -= n
	return true


# --- 恒久パワーアップ (v1.8・D67) ---

## 1回購入して保存する。成功したら true。
static func purchase(id: String) -> bool:
	if not MetaDB.has_id(id):
		return false
	var lv: int = MetaDB.level_of(upgrades, id)
	if lv >= MetaDB.max_level(id):
		return false
	var cost: int = MetaDB.cost(id, lv)
	if not spend_coins(cost):
		return false
	upgrades[id] = lv + 1
	save_now()
	return true


# --- オプション (v1.8・D62/D63/D69) ---

static func set_option(key: String, value: Variant) -> void:
	options[key] = value
	save_now()


## 保存されたオプションを実際の表示・音量へ適用する (起動時と変更時に呼ぶ)。
static func apply_options() -> void:
	OptDB.apply_volume(float(options.get("bgm", OptDB.DEFAULT_BGM)), float(options.get("se", OptDB.DEFAULT_SE)))
	OptDB.apply_display(str(options.get("mode", OptDB.MODE_WINDOW)), str(options.get("resolution", "1152x648")))


## テスト用: 全難易度を解放した状態にする (保存はしない)。
static func unlock_all() -> void:
	cleared = DiffDB.KEYS.duplicate()
	insane_cleared = 3
