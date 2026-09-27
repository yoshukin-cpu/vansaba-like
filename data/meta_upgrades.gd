extends RefCounted
## 恒久パワーアップ 8項目 (SPEC §35.7、v1.8/案6)。
## コスト = 基準 + 増分 × 現在Lv (同じ項目を買うほど逓増)。1回の購入 = 1Lv。
## 未強化 (Lv0) は完全 no-op (既存の回帰に影響させない)。

const ITEMS: Array = [
	{"id": "M01", "name": "体力", "desc": "最大HP +4", "max": 10, "base": 10, "step": 5},
	{"id": "M02", "name": "攻撃", "desc": "与ダメージ +3%", "max": 10, "base": 15, "step": 10},
	{"id": "M03", "name": "俊足", "desc": "移動速度 +2%", "max": 5, "base": 12, "step": 8},
	{"id": "M04", "name": "磁力", "desc": "回収範囲 +6%", "max": 5, "base": 12, "step": 8},
	{"id": "M05", "name": "学び", "desc": "XP獲得 +3%", "max": 5, "base": 15, "step": 10},
	{"id": "M06", "name": "守り", "desc": "アーマー +1", "max": 5, "base": 20, "step": 15},
	{"id": "M07", "name": "再生", "desc": "リジェネ +0.15/s", "max": 5, "base": 20, "step": 15},
	{"id": "M08", "name": "金運", "desc": "コイン獲得 +5%", "max": 5, "base": 25, "step": 20},
]


static func has_id(id: String) -> bool:
	return def(id) != null


static func def(id: String) -> Variant:
	for it: Dictionary in ITEMS:
		if str(it["id"]) == id:
			return it
	return null


static func max_level(id: String) -> int:
	var d: Variant = def(id)
	return int((d as Dictionary)["max"]) if d != null else 0


static func level_of(levels: Dictionary, id: String) -> int:
	return clampi(int(levels.get(id, 0)), 0, max_level(id))


## 次に購入するコスト (現在Lv を渡す)。
static func cost(id: String, level: int) -> int:
	var d: Variant = def(id)
	if d == null:
		return 0
	var it: Dictionary = d
	return int(it["base"]) + int(it["step"]) * clampi(level, 0, int(it["max"]))


static func is_max(levels: Dictionary, id: String) -> bool:
	return level_of(levels, id) >= max_level(id)


## 全項目を MAX にする合計コスト (仕様・検証の基準値 = 2205)。
static func total_cost_all() -> int:
	var t: int = 0
	for it: Dictionary in ITEMS:
		var m: int = int(it["max"])
		for lv: int in range(m):
			t += cost(str(it["id"]), lv)
	return t


## 金運 (M08) の倍率。
static func coin_mult(levels: Dictionary) -> float:
	return 1.0 + 0.05 * float(level_of(levels, "M08"))


## ランの開始時にプレイヤーへ適用する (Lv0 は no-op。最後に hp = max_hp)。
static func apply_to(player: Node, levels: Dictionary) -> void:
	if player == null:
		return
	player.set("max_hp", float(player.get("max_hp")) + 4.0 * float(level_of(levels, "M01")))
	player.set("attack_mult", float(player.get("attack_mult")) * (1.0 + 0.03 * float(level_of(levels, "M02"))))
	player.set("speed", float(player.get("speed")) * (1.0 + 0.02 * float(level_of(levels, "M03"))))
	player.set("magnet_mult", float(player.get("magnet_mult")) * (1.0 + 0.06 * float(level_of(levels, "M04"))))
	player.set("xp_mult", float(player.get("xp_mult")) * (1.0 + 0.03 * float(level_of(levels, "M05"))))
	player.set("armor", float(player.get("armor")) + 1.0 * float(level_of(levels, "M06")))
	player.set("regen", float(player.get("regen")) + 0.15 * float(level_of(levels, "M07")))
	player.set("hp", float(player.get("max_hp")))
