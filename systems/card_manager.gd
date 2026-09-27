extends Node

const CardsDB := preload("res://data/cards_db.gd")
const CardMarks := preload("res://data/card_marks.gd")

## プール枯渇時のフォールバック3種 (D34)。カード20種 (C01〜C20) には数えない。
const FALLBACK_IDS := ["HEAL", "CXP", "CNOVA"]
const FALLBACK_DEFS := {
	"HEAL": {"name": "応急手当", "detail": "HPを30回復する\n(満タンなら小XP宝石に変換)", "level_text": ""},
	"CXP": {"name": "修練の書", "detail": "経験値を+100獲得する", "level_text": ""},
	"CNOVA": {"name": "ノヴァ", "detail": "画面内の敵にダメージ\n敵弾をすべて消す", "level_text": "即時発動"},
}
## 修練の書の獲得経験値と応急手当の回復量 (初版。P19 の計測で調整可)。
const CXP_XP := 100
const HEAL_AMOUNT := 30.0

var player: Node2D = null
var stat_levels := {"C07": 0, "C08": 0, "C09": 0, "C10": 0, "C11": 0, "C12": 0, "C13": 0, "C14": 0, "C15": 0, "C16": 0, "C17": 0, "C18": 0, "C19": 0, "C20": 0}

func setup(p: Node2D) -> void:
	player = p

func weapon_by_id(card_id: String) -> Node:
	if player == null:
		return null
	for w: Node in player.get_node("Weapons").get_children():
		if w.is_queued_for_deletion():
			continue
		if str(w.get("weapon_id")) == card_id:
			return w
	return null

func weapon_count() -> int:
	if player == null:
		return 99
	return player.get_node("Weapons").get_child_count()

## 提示する3枚を組む。MAX到達カードは入れない (D33)。プールが3未満なら
## フォールバック3種 (応急手当/修練の書/ノヴァ) から重複なしで補充する (D34)。
func get_offers() -> Array:
	var pool: Array = []
	for cid: String in CardsDB.WEAPON_IDS:
		var w: Node = weapon_by_id(cid)
		if w == null:
			if weapon_count() < 6:
				pool.append(_entry(cid, true, 0, CardsDB.WEAPON_MAX_LEVEL))
		elif int(w.get("weapon_level")) < CardsDB.WEAPON_MAX_LEVEL:
			pool.append(_entry(cid, false, int(w.get("weapon_level")), CardsDB.WEAPON_MAX_LEVEL))
	for cid: String in CardsDB.STAT_IDS:
		var sl: int = int(stat_levels.get(cid, 0))
		if sl < int(CardsDB.DEFS[cid]["max"]):
			pool.append(_entry(cid, sl == 0, sl, int(CardsDB.DEFS[cid]["max"])))
	pool.shuffle()
	var offers: Array = pool.slice(0, 3)
	var fb: Array = FALLBACK_IDS.duplicate()
	fb.shuffle()
	var fi: int = 0
	while offers.size() < 3 and fi < fb.size():
		offers.append(_fallback_entry(str(fb[fi])))
		fi += 1
	return offers

func _entry(card_id: String, is_new: bool, lv: int, max_lv: int) -> Dictionary:
	# 表示は「実際の遷移」に合わせる (D33)。武器の weapon_level は1始まり、
	# ステータスの stat_levels は0始まりのため、どちらも lv→lv+1 が正しい。
	# 取得後に MAX 到達する場合は数字ではなく "MAX" と表示する (D52)。
	var d: Dictionary = CardsDB.get_def(card_id)
	var text: String = "新規取得!" if is_new else ("MAX" if lv + 1 >= max_lv else ("Lv%d→%d" % [lv, lv + 1]))
	return {"id": card_id, "name": str(d["name"]), "detail": str(d["detail"]), "level_text": text, "icon": CardMarks.texture_for(card_id)}

func _fallback_entry(card_id: String) -> Dictionary:
	var d: Dictionary = FALLBACK_DEFS[card_id]
	return {"id": card_id, "name": str(d["name"]), "detail": str(d["detail"]), "level_text": str(d["level_text"]), "icon": CardMarks.texture_for(card_id)}

func apply_card(card_id: String) -> void:
	if player == null:
		return
	match card_id:
		"C01", "C02", "C03", "C04", "C05", "C06":
			var w: Node = weapon_by_id(card_id)
			if w == null:
				player.call("add_weapon", card_id)
			else:
				w.call("upgrade")
		"C07":
			_bump(card_id)
			player.set("attack_mult", float(player.get("attack_mult")) + 0.2)
		"C08":
			_bump(card_id)
			player.set("cooldown_mult", maxf(0.5, float(player.get("cooldown_mult")) - 0.12))
		"C09":
			_bump(card_id)
			player.set("bonus_projectiles", int(player.get("bonus_projectiles")) + 1)
		"C10":
			_bump(card_id)
			player.set("area_mult", float(player.get("area_mult")) + 0.25)
		"C11":
			_bump(card_id)
			player.set("duration_mult", float(player.get("duration_mult")) + 0.3)
		"C12":
			_bump(card_id)
			player.set("crit_chance", float(player.get("crit_chance")) + 0.1)
		"C13":
			_bump(card_id)
			player.set("bullet_speed_mult", float(player.get("bullet_speed_mult")) + 0.3)
		"C14":
			_bump(card_id)
			player.set("knockback_mult", float(player.get("knockback_mult")) + 0.4)
		"C15":
			_bump(card_id)
			player.set("speed", float(player.get("speed")) * 1.15)
		"C16":
			_bump(card_id)
			player.set("max_hp", float(player.get("max_hp")) + 20.0)
			player.call("heal", 20.0)
		"C17":
			_bump(card_id)
			player.set("regen", float(player.get("regen")) + 1.0)
		"C18":
			_bump(card_id)
			player.set("armor", float(player.get("armor")) + 3.0)
		"C19":
			_bump(card_id)
			player.set("magnet_mult", float(player.get("magnet_mult")) + 0.5)
			var m: Node2D = player.get_node("Magnet") as Node2D
			if m != null:
				var mm: float = float(player.get("magnet_mult"))
				m.scale = Vector2(mm, mm)
		"C20":
			_bump(card_id)
			player.set("xp_mult", float(player.get("xp_mult")) + 0.25)
		"HEAL":
			_heal_or_gem(HEAL_AMOUNT)
		"CXP":
			player.call("add_xp", CXP_XP)
		"CNOVA":
			# ノヴァは取得と同時に発動する (T10 と同効果。D34・§31.2)。
			var cd: Node = get_tree().get_first_node_in_group("chest_director")
			if cd != null:
				cd.call("apply_item", "T10", player.global_position)

## HP満タンなら小XP宝石 (+1) に変換する (T01 と同じ規則、D34)。
func _heal_or_gem(amount: float) -> void:
	if float(player.get("hp")) >= float(player.get("max_hp")):
		var pool: Node = get_tree().get_first_node_in_group("pool_gems")
		if pool != null:
			var g: Area2D = pool.call("acquire") as Area2D
			if g != null:
				g.global_position = player.global_position
				g.set("value", 1)
	else:
		player.call("heal", amount)

func _bump(card_id: String) -> void:
	stat_levels[card_id] = int(stat_levels.get(card_id, 0)) + 1
