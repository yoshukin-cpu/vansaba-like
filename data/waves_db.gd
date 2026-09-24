extends RefCounted

const SLIME := "res://enemies/slime.tscn"
const BAT := "res://enemies/bat.tscn"
const GOBLIN := "res://enemies/goblin.tscn"
const ARCHER := "res://enemies/archer.tscn"
const WOLF := "res://enemies/wolf.tscn"
const GOLEM := "res://enemies/golem.tscn"
const SPLITTER := "res://enemies/splitter.tscn"
const SNIPER := "res://enemies/sniper.tscn"
const SWARM := "res://enemies/swarm.tscn"
const KNIGHT := "res://enemies/knight.tscn"

static func band(t: float) -> Dictionary:
	if t < 60.0:
		return {"interval": 2.0, "batch": [1, 1], "cap": 22, "weights": [[SLIME, 1.0]]}
	if t < 120.0:
		return {"interval": 1.4, "batch": [1, 2], "cap": 34, "weights": [[SLIME, 0.7], [BAT, 0.3]]}
	if t < 180.0:
		return {"interval": 1.0, "batch": [2, 2], "cap": 50, "weights": [[SLIME, 0.5], [BAT, 0.2], [GOBLIN, 0.3]]}
	if t < 240.0:
		return {"interval": 0.8, "batch": [2, 3], "cap": 67, "weights": [[SLIME, 0.4], [BAT, 0.2], [GOBLIN, 0.25], [ARCHER, 0.15]]}
	if t < 300.0:
		return {"interval": 0.6, "batch": [3, 3], "cap": 90, "weights": [[SLIME, 0.3], [BAT, 0.2], [GOBLIN, 0.2], [ARCHER, 0.15], [WOLF, 0.15]]}
	if t < 420.0:
		return {"interval": 0.5, "batch": [3, 4], "cap": 134, "weights": [[GOBLIN, 0.2], [ARCHER, 0.15], [WOLF, 0.15], [GOLEM, 0.15], [SPLITTER, 0.15], [BAT, 0.2]]}
	if t < 510.0:
		return {"interval": 0.4, "batch": [4, 4], "cap": 179, "weights": [[WOLF, 0.15], [GOLEM, 0.15], [SPLITTER, 0.15], [SNIPER, 0.15], [SWARM, 0.25], [ARCHER, 0.15]]}
	if t < 600.0:
		return {"interval": 0.3, "batch": [4, 5], "cap": 224, "weights": [[GOLEM, 0.15], [SPLITTER, 0.15], [SNIPER, 0.15], [SWARM, 0.2], [KNIGHT, 0.2], [WOLF, 0.15]]}
	return {"interval": 0.2, "batch": [5, 5], "cap": 280, "weights": [[GOLEM, 0.15], [SPLITTER, 0.15], [SNIPER, 0.2], [SWARM, 0.2], [KNIGHT, 0.2], [WOLF, 0.1]]}

static func pick(weights: Array) -> String:
	var total: float = 0.0
	for w: Array in weights:
		total += float(w[1])
	var r: float = randf() * total
	for w: Array in weights:
		r -= float(w[1])
		if r <= 0.0:
			return str(w[0])
	return str((weights[0] as Array)[0])
