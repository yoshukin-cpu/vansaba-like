extends "res://weapons/weapon_base.gd"

@export var radius: float = 90.0
@export var rotation_time: float = 1.6

var orbit: Node2D = null
var blades: Array = []
var angle: float = 0.0
var fx: Node = null

const DMG_TABLE := [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0]
const COUNT_TABLE := [1, 1, 2, 2, 2, 3, 3, 3]

func _ready() -> void:
	super._ready()
	weapon_id = "C01"
	weapon_name = "Spin Sword"
	damage = 8.0
	cooldown = 9999.0
	timer = 0.0
	orbit = Node2D.new()
	orbit.name = "Orbit"
	add_child(orbit)
	_refresh_blades()

func upgrade() -> void:
	super.upgrade()
	damage = DMG_TABLE[clampi(weapon_level - 1, 0, 7)]
	radius = 90.0 + float(weapon_level - 1) * 6.0
	_refresh_blades()

func blade_count() -> int:
	return COUNT_TABLE[clampi(weapon_level - 1, 0, 7)]

## 刃の数をレベルに合わせる。Orbit 下に等角度で配置する。
func _refresh_blades() -> void:
	if orbit == null:
		return
	for b: Node in blades:
		if is_instance_valid(b):
			b.queue_free()
	blades.clear()
	var n: int = blade_count()
	for i: int in range(n):
		var bl := Area2D.new()
		bl.name = "Blade%d" % i
		bl.collision_layer = 4
		bl.collision_mask = 10
		bl.monitoring = true
		# 刃は放射状に向ける (位置角度と同じだけ回転。Orbit の回転で振り回す)
		bl.position = Vector2(radius, 0).rotated(TAU * float(i) / float(n))
		bl.rotation = TAU * float(i) / float(n)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 28)
		shape.shape = rect
		bl.add_child(shape)
		# 1枚絵の剣スプライト(右向き)を Orbit の回転で振り回す
		var tex_path := "res://weapons/sprites/spin_sword.png"
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path) as Texture2D
			if tex != null:
				var visual := Sprite2D.new()
				visual.name = "Visual"
				visual.texture = tex
				visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				bl.add_child(visual)
		orbit.add_child(bl)
		bl.area_entered.connect(_on_blade_area)
		blades.append(bl)

func _process(_delta: float) -> void:
	if orbit == null or player == null:
		return
	if bool(player.get("dead")):
		return
	angle += TAU / rotation_time / pstat("cooldown_mult", 1.0) * _delta
	orbit.rotation = angle
	orbit.global_position = player.global_position
	var r: float = radius * pstat("area_mult", 1.0)
	var n: int = blades.size()
	for i: int in range(n):
		var bl: Node = blades[i]
		if is_instance_valid(bl):
			(bl as Node2D).position = Vector2(r, 0).rotated(TAU * float(i) / float(maxi(n, 1)))

func _on_blade_area(area: Area2D) -> void:
	# 敵弾 (layer 8) は消去する (D18)。味方弾 (layer 4) は対象外。
	if int(area.collision_layer) == 8 and area.has_method("erase") and bool(area.get("active")):
		var sp: Vector2 = area.global_position
		area.call("erase")
		_fx().call("spark", sp, Color(0.6, 0.9, 1.0, 1.0))
		return
	var enemy: Node = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage"):
		return
	if bool(enemy.get("dead")):
		return
	var dir: Vector2 = (enemy as Node2D).global_position - player.global_position
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	var rh: Array = roll_hit()
	enemy.call("take_damage", rh[0], dir.normalized() * 160.0 * kb_mult(), rh[1])

func _fx() -> Node:
	if fx == null or not is_instance_valid(fx):
		fx = get_tree().get_first_node_in_group("combat_fx")
	return fx
