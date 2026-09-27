extends "res://weapons/weapon_base.gd"

const HomingScene: PackedScene = preload("res://projectiles/homing_projectile.tscn")

const COUNT_TABLE := [2, 2, 3, 3, 4, 4, 5, 6]
const DMG_TABLE := [8.0, 10.0, 12.0, 14.0, 16.0, 17.0, 18.0, 20.0]

@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 3.0

func _ready() -> void:
	super._ready()
	weapon_id = "C03"
	weapon_name = "Homing Missile"
	cooldown = 2.0
	damage = DMG_TABLE[0]
	timer = 1.2

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
	var hit: Array = roll_hit()
	# D54: 見た目のみの拡大。Lv8 はさらに ×1.3 でかなり大きく (約2.7)。速度・寿命は不変。
	var vis: float = 1.0 + 0.15 * float(weapon_level - 1)
	if weapon_level >= 8:
		vis *= 1.3
	var pool: Node = ammo_pool("pool_homing")
	for i: int in range(n):
		var d: Vector2 = dir.rotated((float(i) - float(n - 1) / 2.0) * 0.35)
		var pr: Area2D
		if pool != null:
			pr = pool.call("acquire") as Area2D
			if pr == null:
				continue
		else:
			pr = HomingScene.instantiate() as Area2D
			scene.add_child(pr)
		pr.global_position = player.global_position + d * 24.0
		pr.call("setup", d, projectile_speed * pstat("bullet_speed_mult", 1.0), hit[0], projectile_lifetime * pstat("duration_mult", 1.0), 1, vis)
		pr.set("trail_scale", vis)
		pr.set("kb_scale", kb_mult())
		pr.set("crit_hit", hit[1])
