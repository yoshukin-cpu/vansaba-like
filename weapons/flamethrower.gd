extends "res://weapons/weapon_base.gd"

const DPS_TABLE := [10.0, 13.0, 16.0, 20.0, 24.0, 28.0, 32.0, 35.0]

const FLAME_TEXTURES := [
	"res://weapons/sprites/flame_tongue.png",
	"res://weapons/sprites/flame_puff.png",
	"res://weapons/sprites/flame_wisp.png",
	"res://weapons/sprites/flame_ember.png",
]
const SPAWN_INTERVAL := 0.04
const PARTICLE_LIFE := 0.5

@export var flame_range: float = 220.0
@export var half_angle: float = 0.44
@export var tick: float = 0.25

var tick_timer: float = 0.0
var spawn_timer: float = 0.0
var textures: Array[Texture2D] = []
var particles: Array = []

func _ready() -> void:
	super._ready()
	weapon_id = "C05"
	weapon_name = "Flamethrower"
	damage = DPS_TABLE[0] * tick
	cooldown = 9999.0
	timer = 0.0
	for p: String in FLAME_TEXTURES:
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p) as Texture2D
			if tex != null:
				textures.append(tex)

func upgrade() -> void:
	super.upgrade()
	damage = DPS_TABLE[clampi(weapon_level - 1, 0, 7)] * tick

func _process(delta: float) -> void:
	if player == null or bool(player.get("dead")):
		_clear_particles()
		return
	_update_particles(delta)
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_flames(delta)
	tick_timer += delta
	if tick_timer < tick:
		return
	tick_timer = 0.0
	_burn()

## 炎のパーティクルを進行方向へ撒く (見た目のみ。ダメージは _burn() 側)
func _spawn_flames(_delta: float) -> void:
	if textures.is_empty() or player == null:
		return
	var dir: Vector2 = get_fire_direction()
	var rng: float = flame_range * pstat("area_mult", 1.0)
	var reach: float = maxf(60.0, rng)
	for i: int in 2:
		var d: Vector2 = dir.rotated(randf_range(-half_angle, half_angle) * 0.9)
		var s := Sprite2D.new()
		s.texture = textures[randi() % textures.size()]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.rotation = d.angle()
		var sc: float = randf_range(0.7, 1.15)
		s.scale = Vector2(sc, sc)
		add_child(s)
		s.global_position = player.global_position + d * randf_range(4.0, 24.0)
		var speed: float = randf_range(0.75, 1.05) * (reach / PARTICLE_LIFE)
		particles.append({
			"node": s,
			"vel": d * speed,
			"life": 0.0,
			"max_life": randf_range(PARTICLE_LIFE * 0.8, PARTICLE_LIFE * 1.15),
			"spin": randf_range(-1.2, 1.2),
			"base_scale": sc,
		})

func _update_particles(delta: float) -> void:
	var alive: Array = []
	for p: Dictionary in particles:
		var n: Sprite2D = p["node"]
		if n == null or not is_instance_valid(n):
			continue
		p["life"] = float(p["life"]) + delta
		var k: float = float(p["life"]) / float(p["max_life"])
		if k >= 1.0:
			n.queue_free()
			continue
		n.global_position += (p["vel"] as Vector2) * delta
		n.rotation += float(p["spin"]) * delta
		var sc: float = float(p["base_scale"]) * (1.0 - 0.6 * k)
		n.scale = Vector2(sc, sc)
		# 白黄 -> 橙 -> 赤 と色を落としながら消える
		n.modulate = Color(1.0, 1.0 - 0.3 * k, 1.0 - 0.7 * k, 1.0 - k * k)
		alive.append(p)
	particles = alive

func _clear_particles() -> void:
	for p: Dictionary in particles:
		var n: Sprite2D = p["node"]
		if n != null and is_instance_valid(n):
			n.queue_free()
	particles.clear()

func _burn() -> void:
	var dir: Vector2 = get_fire_direction()
	var rng: float = flame_range * pstat("area_mult", 1.0)
	var rh: Array = roll_hit()
	var dmg: float = rh[0]
	var crit: bool = rh[1]
	var kb: float = kb_mult()
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
