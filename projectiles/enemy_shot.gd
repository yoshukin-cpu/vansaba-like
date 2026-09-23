extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 220.0
var damage: float = 8.0
var life: float = 4.0
var age: float = 0.0
var active: bool = true
var home_pool: Node = null

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body)

func activate() -> void:
	active = true
	visible = true
	age = 0.0
	set_deferred("monitoring", true)

func deactivate() -> void:
	active = false
	visible = false
	age = 0.0
	set_deferred("monitoring", false)

func setup(dir: Vector2, spd: float, dmg: float) -> void:
	if dir.length() > 0.001:
		direction = dir.normalized()
	speed = spd
	damage = dmg
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
	if area.is_in_group("player_hurtbox"):
		var p: Node = area.get_parent()
		if p != null and p.has_method("take_damage"):
			p.call("take_damage", damage)
		_despawn()

func _on_body(body: Node2D) -> void:
	if not active:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", damage)
		_despawn()

func _despawn() -> void:
	if home_pool != null and is_instance_valid(home_pool):
		home_pool.call("release", self)
	else:
		queue_free()
