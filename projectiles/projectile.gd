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
## D51: 発射位置 (前方24px) と敵半径を考慮した初回ヒット範囲。
const SPAWN_HIT_R := 30.0

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

func setup(dir: Vector2, spd: float, dmg: float, lifetime: float, pier: int, visual_scale: float = 1.0) -> void:
	if dir.length() > 0.001:
		direction = dir.normalized()
	speed = spd
	damage = dmg
	life = lifetime
	pierce = pier
	rotation = direction.angle()
	# D54: 見た目のみの拡大 (衝突形状は不変)。
	if has_node("Visual"):
		(get_node("Visual") as Sprite2D).scale = Vector2(visual_scale, visual_scale)
	# D51: スポーン時点で重なっていた敵・宝箱にも当てる (密着不発の修正)。初回のみ。
	call_deferred("_check_initial_overlap")

## D51: 発射直後に重なっている個体へ通常ヒット処理を行う (hit_set・pierce 共有)。
func _check_initial_overlap() -> void:
	if not active:
		return
	for n: Node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("chests"):
		if pierce <= 0 or not active:
			return
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		if not n.has_method("take_damage"):
			continue
		if ((n as Node2D).global_position - global_position).length() > SPAWN_HIT_R:
			continue
		var id: int = n.get_instance_id()
		if hit_set.has(id):
			continue
		hit_set[id] = true
		n.call("take_damage", damage, direction * 120.0 * kb_scale, crit_hit)
		pierce -= 1
		if pierce <= 0:
			_despawn()
			return

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
