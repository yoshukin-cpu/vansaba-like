extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: float = 10.0
var life: float = 2.0
var pierce: int = 1
var age: float = 0.0
var kb_scale: float = 1.0
var crit_hit: bool = false
var active: bool = true
var home_pool: Node = null
var hit_set: Dictionary = {}

func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

func activate() -> void:
	active = true
	visible = true
	age = 0.0
	crit_hit = false
	hit_set.clear()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate() -> void:
	active = false
	visible = false
	age = 0.0
	hit_set.clear()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func setup(dir: Vector2, spd: float, dmg: float, lifetime: float, pier: int) -> void:
	if dir.length() > 0.001:
		direction = dir.normalized()
	speed = spd
	damage = dmg
	life = lifetime
	pierce = pier
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if not active:
		return
	age += delta
	if age >= life:
		_despawn()
		return
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	var enemy: Node = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage"):
		return
	if bool(enemy.get("dead")):
		return
	var id: int = enemy.get_instance_id()
	if hit_set.has(id):
		return
	hit_set[id] = true
	enemy.call("take_damage", damage, direction * 120.0 * kb_scale, crit_hit)
	pierce -= 1
	if pierce <= 0:
		_despawn()

func _despawn() -> void:
	if home_pool != null and is_instance_valid(home_pool):
		home_pool.call("release", self)
	else:
		queue_free()
