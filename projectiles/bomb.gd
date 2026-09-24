extends Area2D

const BOMB_TEXTURE := "res://enemies/sprites/projectiles/proj_bomb.png"

var target: Vector2 = Vector2.ZERO
var start: Vector2 = Vector2.ZERO
var damage: float = 30.0
var blast_radius: float = 90.0
var kb_scale: float = 1.0
var crit_hit: bool = false
var flight_time: float = 0.45
var age: float = 0.0
var exploded: bool = false
var fade: float = 0.0
var visual: Sprite2D = null

func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	if ResourceLoader.exists(BOMB_TEXTURE):
		var tex: Texture2D = load(BOMB_TEXTURE) as Texture2D
		if tex != null:
			visual = Sprite2D.new()
			visual.name = "Visual"
			visual.texture = tex
			visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(visual)

func setup(from: Vector2, to: Vector2, dmg: float, radius: float, kb: float) -> void:
	start = from
	target = to
	damage = dmg
	blast_radius = radius
	kb_scale = kb
	global_position = from
	queue_redraw()

func _physics_process(delta: float) -> void:
	if exploded:
		return
	age += delta
	var t: float = clampf(age / flight_time, 0.0, 1.0)
	global_position = start.lerp(target, t)
	queue_redraw()
	if t >= 1.0:
		_explode()

func _process(delta: float) -> void:
	if not exploded:
		return
	fade += delta
	queue_redraw()
	if fade > 0.3:
		queue_free()

func _explode() -> void:
	exploded = true
	if visual != null and is_instance_valid(visual):
		visual.visible = false
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var nn: Node2D = n as Node2D
		if nn.global_position.distance_to(target) <= blast_radius:
			var away: Vector2 = nn.global_position - target
			if away.length() < 1.0:
				away = Vector2.RIGHT
			n.call("take_damage", damage, away.normalized() * 260.0 * kb_scale, crit_hit)
	# 宝箱も開く (SPEC §19.2。爆発はグループ走査のため chests も走査する)
	for n: Node in get_tree().get_nodes_in_group("chests"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		if (n as Node2D).global_position.distance_to(target) <= blast_radius:
			n.call("take_damage", damage, Vector2.ZERO, crit_hit)

func _draw() -> void:
	# 飛行中は Visual (スプライト) を表示し、爆発エフェクトだけ自前で描く
	if not exploded:
		return
	var k: float = clampf(fade / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, blast_radius * (0.4 + 0.6 * k), Color(1.0, 0.6, 0.15, 0.5 * (1.0 - k)))
	draw_circle(Vector2.ZERO, blast_radius * k, Color(1, 1, 1, 0.6 * (1.0 - k)))
