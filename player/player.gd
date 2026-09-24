extends CharacterBody2D
class_name Player

signal level_up

const WEAPON_SCRIPTS := {
	"C01": preload("res://weapons/spin_sword.gd"),
	"C02": preload("res://weapons/straight_shot.gd"),
	"C03": preload("res://weapons/homing_missiles.gd"),
	"C04": preload("res://weapons/chain_lightning.gd"),
	"C05": preload("res://weapons/flamethrower.gd"),
	"C06": preload("res://weapons/orbit_bomb.gd"),
}

@export var speed: float = 230.0
@export var max_hp: float = 120.0

var hp: float = 120.0
var xp: int = 0
var level: int = 1
var xp_next: int = 10
var pending_levels: int = 0
var attack_mult: float = 1.0
var cooldown_mult: float = 1.0
var bonus_projectiles: int = 0
var area_mult: float = 1.0
var duration_mult: float = 1.0
var crit_chance: float = 0.05
var crit_mult: float = 2.0
var knockback_mult: float = 1.0
var bullet_speed_mult: float = 1.0
var regen: float = 0.0
var armor: float = 0.0
var magnet_mult: float = 1.0
var xp_mult: float = 1.0
var dead: bool = false
var invuln: float = 0.0
var facing: String = "down"
var move_direction: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var use_mouse_aim: bool = false
var mouse_aim_msec: int = 0

@onready var body: AnimatedSprite2D = $Body
@onready var weapons: Node2D = $Weapons
@onready var hurtbox: Area2D = $Hurtbox
@onready var magnet: Area2D = $Magnet
@onready var camera: Camera2D = $Camera2D

var trauma: float = 0.0
var fx: Node = null

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	hurtbox.add_to_group("player_hurtbox")
	magnet.area_entered.connect(_on_magnet_area)
	add_weapon("C02")
	add_weapon("C01")

func add_weapon(card_id: String) -> void:
	if not WEAPON_SCRIPTS.has(card_id):
		return
	for w: Node in weapons.get_children():
		if w.is_queued_for_deletion():
			continue
		if str(w.get("weapon_id")) == card_id:
			return
	var wnode := Node2D.new()
	wnode.name = "Weapon_" + card_id
	wnode.set_script(WEAPON_SCRIPTS[card_id] as Script)
	weapons.add_child(wnode)

func _physics_process(_delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move_direction * speed
	move_and_slide()
	_update_aim()
	_update_animation()

func _process(delta: float) -> void:
	if not dead and regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen * delta)
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - 1.6 * delta)
		var s: float = trauma * trauma * 24.0
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
	if invuln > 0.0:
		invuln -= delta
		var k: float = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 60.0))
		body.modulate = Color(1, 1, 1, k)
		if invuln <= 0.0:
			body.modulate = Color(1, 1, 1, 1)

func take_damage(amount: float) -> void:
	if dead or invuln > 0.0:
		return
	hp -= maxf(1.0, amount - armor)
	invuln = 0.6
	add_shake(0.35)
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", "hurt")
	if fx == null or not is_instance_valid(fx):
		fx = get_tree().get_first_node_in_group("combat_fx")
	if fx != null:
		fx.call("damage_number", global_position, amount, false)
		fx.call("spark", global_position, Color(1, 0.3, 0.3, 1))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		if body != null:
			body.play("idle_" + facing)

func add_shake(a: float) -> void:
	trauma = minf(1.0, trauma + a)

func add_xp(v: int) -> void:
	if dead:
		return
	xp += int(round(float(v) * xp_mult))
	var grew := false
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = 10 + (level - 1) * 8
		pending_levels += 1
		grew = true
	if grew:
		level_up.emit()

func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)

func _on_magnet_area(area: Area2D) -> void:
	if area.has_method("attract"):
		area.call("attract")

func _update_aim() -> void:
	var joy_aim: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if joy_aim.length() > 0.2:
		aim_direction = joy_aim.normalized()
		use_mouse_aim = false
	elif is_mouse_aim_fresh():
		var mouse_pos: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_pos - global_position
		if to_mouse.length() > 4.0:
			aim_direction = to_mouse.normalized()
		elif move_direction.length() > 0.1:
			aim_direction = move_direction.normalized()
	elif move_direction.length() > 0.1:
		aim_direction = move_direction.normalized()

func _update_animation() -> void:
	var moving: bool = move_direction.length() > 0.1
	if moving:
		if absf(move_direction.x) > absf(move_direction.y):
			facing = "right" if move_direction.x > 0.0 else "left"
		else:
			facing = "down" if move_direction.y > 0.0 else "up"
	var anim: String = ("walk_" if moving else "idle_") + facing
	if String(body.animation) != anim:
		body.play(anim)
	if moving:
		body.speed_scale = clampf(velocity.length() / speed, 0.75, 1.6)
	else:
		body.speed_scale = 1.0

func is_mouse_aim_fresh() -> bool:
	if not use_mouse_aim:
		return false
	return Time.get_ticks_msec() - mouse_aim_msec < 3000

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		use_mouse_aim = true
		mouse_aim_msec = Time.get_ticks_msec()
