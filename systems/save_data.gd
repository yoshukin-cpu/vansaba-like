extends RefCounted
## 難易度の解放状況と前回選択のみを保存する (SPEC §31.6、v1.6/案4)。
## キャラ成長・コイン持ち越し等のメタ成長は対象外のまま (SPEC §16)。

const DiffDB := preload("res://data/difficulty_db.gd")

const DEFAULT_PATH := "user://vansaba_save.json"

## 保存先。検証スクリプトは一時パスへ差し替える。
static var path: String = DEFAULT_PATH
## クリア済みの難易度キー (インセインN は含めない)。
static var cleared: Array = []
## クリア済みインセインN の最大 N (0 = インセイン1未クリア)。
static var insane_cleared: int = 0
## 前回選んだ難易度 (タイトルの初期カーソル)。
static var last: String = "normal"


static func reset() -> void:
	cleared = []
	insane_cleared = 0
	last = "normal"


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


static func save_now() -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1,
		"cleared": cleared,
		"insane_cleared": insane_cleared,
		"last": last,
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


## テスト用: 全難易度を解放した状態にする (保存はしない)。
static func unlock_all() -> void:
	cleared = DiffDB.KEYS.duplicate()
	insane_cleared = 3
