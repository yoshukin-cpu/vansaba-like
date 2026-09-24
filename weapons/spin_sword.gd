extends "res://weapons/weapon_base.gd"

@export var radius: float = 90.0
@export var rotation_time: float = 1.6

var orbit: Node2D = null
var blade: Area2D = null
var angle: float = 0.0

const DMG_TABLE := [12.0, 16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 44.0]

func _ready() -> void:
	super._ready()
	weapon_id = "C01"
	weapon_name = "Spin Sword"
	damage = 12.0
	cooldown = 9999.0
	timer = 0.0
	orbit = Node2D.new()
	orbit.name = "Orbit"
	add_child(orbit)
	blade = Area2D.new()
	blade.name = "Blade"
	blade.collision_layer = 4
	blade.collision_mask = 2
	blade.monitoring = true
	blade.position = Vector2(radius, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 28)
	shape.shape = rect
	blade.add_child(shape)
	# 1枚絵の剣スプライト(右向き)を Orbit の回転で振り回す
	var tex_path := "res://weapons/sprites/spin_sword.png"
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex != null:
			var visual := Sprite2D.new()
			visual.name = "Visual"
			visual.texture = tex
			visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			blade.add_child(visual)
	orbit.add_child(blade)
	blade.area_entered.connect(_on_blade_area)

func upgrade() -> void:
	super.upgrade()
	damage = DMG_TABLE[clampi(weapon_level - 1, 0, 7)]
	radius = 90.0 + float(weapon_level - 1) * 6.0
	if blade != null:
		blade.position = Vector2(radius, 0)

func _process(_delta: float) -> void:
	if orbit == null or player == null:
		return
	if bool(player.get("dead")):
		return
	angle += TAU / rotation_time / pstat("cooldown_mult", 1.0) * _delta
	orbit.rotation = angle
	orbit.global_position = player.global_position
	if blade != null:
		blade.position = Vector2(radius * pstat("area_mult", 1.0), 0)

func _on_blade_area(area: Area2D) -> void:
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
