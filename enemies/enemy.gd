extends CharacterBody2D

const GEM_SCENE: PackedScene = preload("res://pickups/xp_gem.tscn")
const ENEMY_SHOT_SCRIPT := preload("res://projectiles/enemy_shot.gd")

## SpriteFrames のアニメ速度の基準 (anim_fps は speed_scale で反映する)
const BASE_ANIM_FPS := 6.0

## 障害物 (layer 6) との衝突マスク。詰まったら一時的に外して抜け出す (SPEC §18.5)
const OBSTACLE_MASK: int = 64
const STUCK_TIME: float = 8.0
const STUCK_IGNORE_TIME: float = 3.0

@export var max_hp: float = 12.0
@export var speed: float = 70.0
@export var contact_damage: float = 8.0
@export var xp_value: int = 1
@export var body_color: Color = Color(0.9, 0.3, 0.3, 1)
@export var behavior: String = "chase"
@export var preferred_range: float = 300.0
@export var shot_damage: float = 8.0
@export var shot_speed: float = 220.0
@export var shot_interval: float = 2.5
@export var dash_speed: float = 350.0
@export var dash_interval: float = 3.0
@export var split_scene: String = ""
@export var frames_path: String = ""
@export var anim_fps: float = 6.0

var hp: float = 12.0
var dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var flash: float = 0.0
var contact_cd: float = 0.0
var shot_cd: float = 0.0
var dash_cd: float = 0.0
var dash_phase: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var strafe_phase: float = 0.0
var fx: Node = null
var gem_pool: Node = null
var stuck_time: float = 0.0
var stuck_ignore: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _prev_valid: bool = false

@onready var body: AnimatedSprite2D = $Body
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_apply_sprite()
	hitbox.area_entered.connect(_on_hitbox_area)
	shot_cd = shot_interval * (0.5 + randf() * 0.5)
	dash_cd = dash_interval
	strafe_phase = randf() * TAU

## frames_path の SpriteFrames を Body に適用する (未指定なら何もしない)
func _apply_sprite() -> void:
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return
	var frames: SpriteFrames = load(frames_path) as SpriteFrames
	if frames == null or body == null:
		return
	body.sprite_frames = frames
	body.speed_scale = anim_fps / BASE_ANIM_FPS
	body.play("down")

## 移動方向で前後2パターンを使い分ける。左右移動は正面絵を反転して使う
func _update_facing(move: Vector2) -> void:
	if body == null or body.sprite_frames == null:
		return
	if move.length() < 1.0:
		return
	var want: String = "down"
	var flip: bool = false
	if absf(move.x) > absf(move.y):
		want = "down"
		flip = move.x < 0.0
	else:
		want = "down" if move.y > 0.0 else "up"
	if String(body.animation) != want:
		body.play(want)
	body.flip_h = flip

func _physics_process(delta: float) -> void:
	if dead:
		return
	contact_cd -= delta
	var target: Node2D = _find_player()
	var dir := Vector2.ZERO
	var spd: float = speed
	if target != null:
		var to: Vector2 = target.global_position - global_position
		var dist: float = to.length()
		if dist > 1.0:
			dir = to.normalized()
		match behavior:
			"keeper":
				shot_cd -= delta
				if dist > preferred_range + 60.0:
					pass
				elif dist < preferred_range - 60.0:
					dir = -dir
				else:
					dir = to.normalized().rotated(PI / 2.0) * sin(Time.get_ticks_msec() / 900.0 + strafe_phase)
					spd = speed * 0.5
				if shot_cd <= 0.0 and dist < preferred_range + 250.0:
					shot_cd = shot_interval
					_fire_shot(to.normalized())
			"dasher":
				dash_cd -= delta
				if dash_phase > 0.0:
					dash_phase -= delta
					if dash_phase <= 0.0:
						dash_dir = dir
						dash_phase = -0.4
						flash = 0.15
						if body != null:
							body.modulate = Color(3, 3, 3, 1)
					dir = Vector2.ZERO
					spd = 0.0
				elif dash_phase < 0.0:
					dash_phase += delta
					dir = dash_dir
					spd = dash_speed
					if dash_phase >= 0.0:
						dash_phase = 0.0
						dash_cd = dash_interval
				elif dash_cd <= 0.0 and dist < 500.0 and dist > 60.0:
					dash_phase = 0.4
					dir = Vector2.ZERO
					spd = 0.0
	_update_facing(dir * spd)
	velocity = dir * spd + knockback
	move_and_slide()
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	_update_stuck(delta)
	_check_contact()

## 障害物に引っかかったままの個体を救済する。一定時間ほぼ動けていなければ
## 障害物との衝突を一時的に外して抜け出させる (SPEC §18.5)。
func _update_stuck(delta: float) -> void:
	if not _prev_valid:
		_prev_valid = true
		_prev_pos = global_position
		return
	if stuck_ignore > 0.0:
		stuck_ignore -= delta
		if stuck_ignore <= 0.0:
			collision_mask = OBSTACLE_MASK
		_prev_pos = global_position
		return
	var moved: float = global_position.distance_to(_prev_pos)
	_prev_pos = global_position
	var expect: float = maxf(speed * 0.5, 25.0) * delta
	if moved < expect:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time >= STUCK_TIME:
		stuck_time = 0.0
		stuck_ignore = STUCK_IGNORE_TIME
		collision_mask = 0

func _fire_shot(dir: Vector2, spd: float = -1.0, dmg: float = -1.0) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var pool: Node = get_tree().get_first_node_in_group("pool_enemy_shots")
	var s: Area2D
	if pool != null:
		s = pool.call("acquire") as Area2D
		if s == null:
			return
	else:
		s = Area2D.new()
		s.set_script(ENEMY_SHOT_SCRIPT)
		scene.add_child(s)
	s.global_position = global_position
	s.call("setup", dir, shot_speed if spd < 0.0 else spd, shot_damage if dmg < 0.0 else dmg)

func apply_scaling(hp_mult: float, dmg_mult: float) -> void:
	max_hp *= hp_mult
	hp = max_hp
	contact_damage *= dmg_mult
	shot_damage *= dmg_mult

func make_elite() -> void:
	apply_scaling(5.0, 1.5)
	set("xp_value", xp_value * 5)
	scale = Vector2(1.5, 1.5)
	if body != null:
		body.self_modulate = Color(1.0, 0.8, 0.2, 1.0)

func _process(delta: float) -> void:
	if flash > 0.0:
		flash -= delta
		if flash <= 0.0 and body != null:
			body.modulate = Color(1, 1, 1, 1)

func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if dead:
		return
	hp -= amount
	_fx().call("damage_number", global_position, amount, crit)
	_fx().call("spark", global_position, Color(1, 1, 1, 1))
	knockback += kb
	if knockback.length() > 400.0:
		knockback = knockback.normalized() * 400.0
	flash = 0.12
	if body != null:
		body.modulate = Color(3, 3, 3, 1)
	if hp <= 0.0:
		dead = true
		remove_from_group("enemies")
		var game: Node = get_tree().get_first_node_in_group("game")
		if game != null:
			game.call("add_kill")
		_fx().call("poof", global_position, body_color, scale.x > 1.2)
		_audio().call("play", "kill")
		_spawn_gem()
		_spawn_split()
		queue_free()

func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio")

func _fx() -> Node:
	if fx == null or not is_instance_valid(fx):
		fx = get_tree().get_first_node_in_group("combat_fx")
	return fx

func _check_contact() -> void:
	if contact_cd > 0.0 or dead:
		return
	for a: Area2D in hitbox.get_overlapping_areas():
		if a.is_in_group("player_hurtbox"):
			_deal_contact()
			break

func _on_hitbox_area(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		_deal_contact()

func _deal_contact() -> void:
	if contact_cd > 0.0 or dead:
		return
	var p: Node = _find_player_raw()
	if p == null or bool(p.get("dead")):
		return
	contact_cd = 1.0
	p.call("take_damage", contact_damage)

func _spawn_gem() -> void:
	if xp_value <= 0:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if gem_pool == null or not is_instance_valid(gem_pool):
		gem_pool = get_tree().get_first_node_in_group("pool_gems")
	var g: Area2D
	if gem_pool != null:
		g = gem_pool.call("acquire") as Area2D
		if g == null:
			return
	else:
		g = GEM_SCENE.instantiate() as Area2D
		scene.add_child(g)
	g.global_position = global_position
	g.set("value", xp_value)

func _spawn_split() -> void:
	if split_scene == "":
		return
	if not ResourceLoader.exists(split_scene):
		return
	var scn: PackedScene = load(split_scene) as PackedScene
	if scn == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for i: int in range(3):
		var m: Node = scn.instantiate()
		scene.add_child(m)
		(m as Node2D).global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / 3.0) * 20.0

func _find_player() -> Node2D:
	var p: Node = _find_player_raw()
	if p == null or bool(p.get("dead")):
		return null
	return p as Node2D

func _find_player_raw() -> Node:
	var ps: Array[Node] = get_tree().get_nodes_in_group("player")
	if ps.size() > 0:
		return ps[0]
	var sc: Node = get_tree().current_scene
	if sc != null and sc.has_node("Player"):
		return sc.get_node("Player")
	return null
