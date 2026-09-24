extends RefCounted
## 宝箱の中身の抽選テーブル (SPEC §19.3)。
## 5% でレア枠、95% は通常の重み抽選。

const RARE_CHANCE := 0.05

const WEIGHTS := [
	["T01", 22], ["T02", 20], ["T03", 14], ["T04", 12], ["T05", 12],
	["T06", 10], ["T07", 5], ["T08", 3], ["T09", 2], ["T10", 4],
]

const RARE := ["R_HEAL", "R_COIN", "R_WEAPON"]

static func roll() -> String:
	if randf() < RARE_CHANCE:
		return str(RARE[randi() % RARE.size()])
	var total := 0
	for w: Array in WEIGHTS:
		total += int(w[1])
	var r: float = randf() * float(total)
	for w: Array in WEIGHTS:
		r -= float(int(w[1]))
		if r <= 0.0:
			return str(w[0])
	return "T02"
