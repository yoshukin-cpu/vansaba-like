extends "res://weapons/weapon_base.gd"

const ProjectileScene: PackedScene = preload("res://projectiles/projectile.tscn")

@export var projectile_speed: float = 500.0
@export var projectile_count: int = 1
@export var spread: float = 0.12
@export var projectile_lifetime: float = 2.0
@export var pierce: int = 1

func _ready() -> void:
	super._ready()
	weapon_id = "C02"
	weapon_name = "Straight Shot"
	cooldown = 1.0
	damage = 10.0
	timer = 0.7

func upgrade() -> void:
	super.upgrade()
	damage = 10.0 + float(weapon_level - 1) * 4.0
	projectile_count = 1 + int(float(weapon_level - 1) / 3.0)

func fire() -> void:
	if player == null:
		return
	var dir: Vector2 = get_fire_direction()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var n: int = projectile_count + int(pstat("bonus_projectiles", 0.0))
	var spd: float = projectile_speed * pstat("bullet_speed_mult", 1.0)
	var life: float = projectile_lifetime * pstat("duration_mult", 1.0)
	var hit: Array = roll_hit()
	var dmg: float = hit[0]
	var crit: bool = hit[1]
	var kb: float = kb_mult()
	var pool: Node = ammo_pool("pool_shots")
	for i: int in range(n):
		var offset: float = (float(i) - (float(n) - 1.0) / 2.0) * spread
		var d: Vector2 = dir.rotated(offset)
		var pr: Area2D
		if pool != null:
			pr = pool.call("acquire") as Area2D
			if pr == null:
				continue
		else:
			pr = ProjectileScene.instantiate() as Area2D
			scene.add_child(pr)
		pr.global_position = player.global_position + d * 24.0
		pr.call("setup", d, spd, dmg, life, pierce)
		pr.set("kb_scale", kb)
		pr.set("crit_hit", crit)
