extends "res://weapons/weapon_base.gd"

const DPS_TABLE := [10.0, 13.0, 16.0, 20.0, 24.0, 28.0, 32.0, 35.0]

@export var flame_range: float = 220.0
@export var half_angle: float = 0.44
@export var tick: float = 0.25

var tick_timer: float = 0.0
var cone: Polygon2D = null
var cone_hide: float = 0.0

func _ready() -> void:
	super._ready()
	weapon_id = "C05"
	weapon_name = "Flamethrower"
	damage = DPS_TABLE[0] * tick
	cooldown = 9999.0
	timer = 0.0
	cone = Polygon2D.new()
	cone.color = Color(1.0, 0.55, 0.15, 0.55)
	cone.visible = false
	add_child(cone)

func upgrade() -> void:
	super.upgrade()
	damage = DPS_TABLE[clampi(weapon_level - 1, 0, 7)] * tick

func _process(_delta: float) -> void:
	if player == null or bool(player.get("dead")):
		return
	if cone_hide > 0.0:
		cone_hide -= _delta
		if cone_hide <= 0.0 and cone != null:
			cone.visible = false
	tick_timer += _delta
	if tick_timer < tick:
		return
	tick_timer = 0.0
	_burn()

func _burn() -> void:
	var dir: Vector2 = get_fire_direction()
	var rng: float = flame_range * pstat("area_mult", 1.0)
	var rh: Array = roll_hit()
	var dmg: float = rh[0]
	var crit: bool = rh[1]
	var kb: float = kb_mult()
	if cone != null:
		var half_w: float = rng * tan(half_angle)
		cone.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rng, -half_w), Vector2(rng, half_w)])
		cone.rotation = dir.angle()
		cone.global_position = player.global_position
		cone.visible = true
		cone_hide = 0.14
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var nn: Node2D = n as Node2D
		var to: Vector2 = nn.global_position - player.global_position
		if to.length() > rng:
			continue
		if absf(to.normalized().angle_to(dir)) > half_angle:
			continue
		n.call("take_damage", dmg, to.normalized() * 60.0 * kb, crit)
