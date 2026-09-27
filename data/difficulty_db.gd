extends RefCounted
## 難易度 (SPEC §31.4、v1.6/案4)。7段階 + インセインN。
## 値はすべて「+X%」で、倍率 ×(1+X/100) として各所に掛ける。
## ノーマルはすべて 0% (完全な no-op) とし、既存の回帰に影響させない。

const KEYS := ["normal", "hard", "expert", "nightmare", "inferno", "lunatic", "insane"]

const NAMES := {
	"normal": "ノーマル",
	"hard": "ハード",
	"expert": "エキスパート",
	"nightmare": "ナイトメア",
	"inferno": "インフェルノ",
	"lunatic": "ルナティック",
	"insane": "インセイン",
}

## [敵の硬さ, エリート・ボスの硬さ(加算), 弾の速さ, 敵の出現量, 敵・弾のダメージ, 敵の移動速度, エリートの出現頻度]
const TABLE := {
	"normal": [0, 0, 0, 0, 0, 0, 0],
	"hard": [25, 25, 10, 20, 20, 5, 25],
	"expert": [55, 55, 25, 45, 45, 10, 50],
	"nightmare": [95, 95, 40, 75, 75, 15, 75],
	"inferno": [145, 145, 60, 110, 110, 20, 100],
	"lunatic": [210, 210, 80, 150, 150, 25, 125],
	"insane": [300, 300, 105, 200, 200, 30, 150],
}

## インセインN の段階増分 (N を掛けて加算する)。
const INSANE_STEP := [30, 30, 10, 20, 25, 3, 15]

## 同時上限の絶対クランプ (高難易度で fps を守るため。P19 で実測して確定)。
const CAP_CLAMP := 400.0
## エリートの基本出現間隔 (秒)。
const ELITE_BASE_INTERVAL := 120.0
## 湧き間隔の下限 (秒)。
const MIN_INTERVAL := 0.05
## エリート/ボスの実効倍率 (v1.8・D71)。中ボス (B01) は据え置き・最終ボス (B02) は ×2。
const ELITE_SCALE := 2.0
const MID_BOSS_SCALE := 1.0
const FINAL_BOSS_SCALE := 2.0
## コイン倍率 (v1.8・D66)。インセインN は基底 + 0.2N。
const COIN_BASE := {
	"normal": 1.0, "hard": 1.2, "expert": 1.5, "nightmare": 1.8,
	"inferno": 2.2, "lunatic": 2.6, "insane": 3.0,
}
const COIN_INSANE_STEP := 0.2

## ランの開始時に確定する現在の難易度 ("hard"、"insane3" など)。
static var current_key: String = "normal"


## "insane3" → {"key": "insane", "insane": 3}。不正な文字列はノーマル扱い。
static func parse_key(key: String) -> Dictionary:
	var k: String = key.strip_edges()
	if k.begins_with("insane"):
		var suffix: String = k.substr(6)
		if suffix == "":
			return {"key": "insane", "insane": 0}
		if suffix.is_valid_int():
			return {"key": "insane", "insane": maxi(1, suffix.to_int())}
		return {"key": "normal", "insane": 0}
	if KEYS.has(k):
		return {"key": k, "insane": 0}
	return {"key": "normal", "insane": 0}


## parse_key の逆。正規化されたキー ("hard" / "insane" / "insane2") を返す。
static func key_for(parsed: Dictionary) -> String:
	if int(parsed.get("insane", 0)) > 0:
		return "insane%d" % int(parsed["insane"])
	return str(parsed.get("key", "normal"))


static func is_valid(key: String) -> bool:
	return key_for(parse_key(key)) == key.strip_edges()


## 7パラメータの % 配列 (インセインN は基底 + N×段階増分)。
static func values(key: String) -> Array:
	var p: Dictionary = parse_key(key)
	var base: Array = TABLE[str(p["key"])]
	var ins: int = int(p["insane"])
	if ins <= 0:
		return base.duplicate()
	var out: Array = []
	for i: int in range(base.size()):
		out.append(int(base[i]) + int(INSANE_STEP[i]) * ins)
	return out


static func display_name(key: String) -> String:
	var p: Dictionary = parse_key(key)
	var ins: int = int(p["insane"])
	if ins > 0:
		return "%s%d" % [str(NAMES["insane"]), ins]
	return str(NAMES[str(p["key"])])


## 表示用のパラメータ行 (タイトル右側パネル)。[[ラベル, %値], ...]
static func param_lines(key: String) -> Array:
	var v: Array = values(key)
	return [
		["敵の硬さ", int(v[0])],
		["エリート・ボス", int(v[1])],
		["弾の速さ", int(v[2])],
		["敵の出現量", int(v[3])],
		["敵・弾ダメージ", int(v[4])],
		["敵の移動速度", int(v[5])],
		["エリート頻度", int(v[6])],
	]


# --- 乗数 (key 指定) ---

static func hp_mult(key: String) -> float:
	return 1.0 + float(values(key)[0]) / 100.0


## エリート・ボスは「敵の硬さ + エリート・ボスの硬さ」の加算式 (SPEC §31.4)。
static func elite_boss_hp_mult(key: String) -> float:
	var v: Array = values(key)
	return 1.0 + (float(v[0]) + float(v[1])) / 100.0


## 通常敵に焼いた分との比。エリート側で追加適用すると「エリートの実効倍率 = 2×W」になる (v1.8・D71)。
static func elite_ratio(key: String) -> float:
	return ELITE_SCALE * elite_boss_hp_mult(key) / hp_mult(key)


## ボスに追加適用する比。中ボスは据え置き・最終ボスは ×2 (v1.8・D71)。
static func boss_ratio(key: String, is_final: bool) -> float:
	var sc: float = FINAL_BOSS_SCALE if is_final else MID_BOSS_SCALE
	return sc * elite_boss_hp_mult(key) / hp_mult(key)


## コイン倍率 (v1.8・D66)。インセインN は基底 + 0.2N。
static func coin_mult(key: String) -> float:
	var p: Dictionary = parse_key(key)
	return float(COIN_BASE[str(p["key"])]) + COIN_INSANE_STEP * float(p["insane"])


static func bullet_speed_mult(key: String) -> float:
	return 1.0 + float(values(key)[2]) / 100.0


static func spawn_mult(key: String) -> float:
	return 1.0 + float(values(key)[3]) / 100.0


static func damage_mult(key: String) -> float:
	return 1.0 + float(values(key)[4]) / 100.0


static func enemy_speed_mult(key: String) -> float:
	return 1.0 + float(values(key)[5]) / 100.0


static func elite_freq_mult(key: String) -> float:
	return 1.0 + float(values(key)[6]) / 100.0


static func interval_mult(key: String) -> float:
	return 1.0 / spawn_mult(key)


static func cap_mult(key: String) -> float:
	return 1.0 + float(values(key)[3]) / 200.0


static func cap_for(base_cap: int, key: String) -> int:
	return int(minf(float(base_cap) * cap_mult(key), CAP_CLAMP))


static func elite_interval(key: String) -> float:
	return ELITE_BASE_INTERVAL / elite_freq_mult(key)


# --- 現在の難易度 (current_key) を使うショートカット ---

static func cur_hp_mult() -> float:
	return hp_mult(current_key)


static func cur_elite_ratio() -> float:
	return elite_ratio(current_key)


static func cur_boss_ratio(is_final: bool) -> float:
	return boss_ratio(current_key, is_final)


static func cur_coin_mult() -> float:
	return coin_mult(current_key)


static func cur_damage_mult() -> float:
	return damage_mult(current_key)


static func cur_enemy_speed_mult() -> float:
	return enemy_speed_mult(current_key)


static func cur_bullet_speed_mult() -> float:
	return bullet_speed_mult(current_key)


static func cur_interval_mult() -> float:
	return interval_mult(current_key)


static func cur_cap(base_cap: int) -> int:
	return cap_for(base_cap, current_key)


static func cur_elite_interval() -> float:
	return elite_interval(current_key)


# --- 解放ルール (SPEC §31.6) ---

## その難易度を遊ぶのに必要なクリア済みキー ("" なら個別キー不要)。
static func requirement_key(key: String) -> String:
	var p: Dictionary = parse_key(key)
	var ins: int = int(p["insane"])
	if ins > 1:
		return "insane%d" % (ins - 1)
	if ins == 1:
		return "insane"
	match str(p["key"]):
		"normal":
			return ""
		"hard":
			return "" # セレクタ解放 (初回クリア) と同時に遊べる
		"expert":
			return "hard"
		"nightmare":
			return "expert"
		"inferno":
			return "nightmare"
		"lunatic":
			return "inferno"
		"insane":
			return "lunatic"
	return ""


static func is_unlocked(key: String, cleared: Array, insane_cleared: int) -> bool:
	var p: Dictionary = parse_key(key)
	var ins: int = int(p["insane"])
	if ins > 0:
		if ins == 1:
			return cleared.has("insane")
		return insane_cleared >= ins - 1
	var k: String = str(p["key"])
	if k == "normal":
		return true
	if k == "hard":
		return not cleared.is_empty() # 1度クリアするとセレクタと同時に解放
	return cleared.has(requirement_key(k))


## 表示リスト = 解放済み + 次の1件 (ロック)。[{"key": ..., "unlocked": bool}, ...]
static func selector_entries(cleared: Array, insane_cleared: int) -> Array:
	var entries: Array = []
	for k: String in KEYS:
		var unlocked: bool = is_unlocked(k, cleared, insane_cleared)
		entries.append({"key": k, "unlocked": unlocked})
		if not unlocked:
			return entries
	var n: int = 1
	while true:
		var k2: String = "insane%d" % n
		var unlocked2: bool = is_unlocked(k2, cleared, insane_cleared)
		entries.append({"key": k2, "unlocked": unlocked2})
		if not unlocked2:
			break
		n += 1
	return entries


## 次に解放される (ロック中の先頭) キー。無ければ ""。
static func first_locked_key(cleared: Array, insane_cleared: int) -> String:
	for e: Dictionary in selector_entries(cleared, insane_cleared):
		if not bool(e["unlocked"]):
			return str(e["key"])
	return ""


static func unlock_requirement_text(key: String) -> String:
	var p: Dictionary = parse_key(key)
	var ins: int = int(p["insane"])
	if ins > 0:
		var prev: String = "insane" if ins == 1 else "insane%d" % (ins - 1)
		return "解放条件: %s をクリア" % display_name(prev)
	var k: String = str(p["key"])
	if k == "hard":
		return "解放条件: ゲームをクリア (難易度選択の解放)"
	return "解放条件: %s をクリア" % display_name(requirement_key(k))
