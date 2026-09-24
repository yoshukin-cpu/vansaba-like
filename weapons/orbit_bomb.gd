extends "res://weapons/weapon_base.gd"

const BombScript := preload("res://projectiles/bomb.gd")

const COUNT_TABLE := [1, 1, 1, 2, 2, 2, 3, 3]
const DMG_TABLE := [30.0, 38.0, 46.0, 54.0, 62.0, 70.0, 80.0, 90.0]

@export var blast_radius: float = 90.0
@export var throw_range: float = 420.0

func _ready() -> void:
	super._ready()
	weapon_id = "C06"
	weapon_name = "Orbit Bomb"
	cooldown = 3.0
	damage = DMG_TABLE[0]
	timer = 2.2

func upgrade() -> void:
	super.upgrade()
	damage = DMG_TABLE[clampi(weapon_level - 1, 0, 7)]

func base_count() -> int:
	return COUNT_TABLE[clampi(weapon_level - 1, 0, 7)]

func fire() -> void:
	if player == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var n: int = base_count() + int(pstat("bonus_projectiles", 0.0))
	var dir: Vector2 = get_fire_direction()
	var rh: Array = roll_hit()
	var dmg: float = rh[0]
	var crit: bool = rh[1]
	var radius: float = blast_radius * pstat("area_mult", 1.0)
	for i: int in range(n):
		var tgt: Node2D = find_nearest_enemy(throw_range + 200.0, true)
		var to: Vector2
		if tgt != null and (tgt.global_position - player.global_position).length() <= throw_range:
			to = tgt.global_position
		else:
			to = player.global_position + dir.rotated((float(i) - float(n - 1) / 2.0) * 0.3) * throw_range * 0.75
		var b := Area2D.new()
		b.set_script(BombScript)
		scene.add_child(b)
		b.call("setup", player.global_position, to, dmg, radius, kb_mult())
		b.set("crit_hit", crit)
