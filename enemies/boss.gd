extends "res://enemies/enemy.gd"

@export var boss_id: String = "B01"
@export var boss_name: String = "BOSS"

var _rewarded: bool = false
var charge_cd: float = 6.0
var summon_cd: float = 10.0
var barrage_cd: float = 3.0
var aimed_cd: float = 5.0
var windup: float = 0.0
var charging: float = 0.0
var charge_dir: Vector2 = Vector2.RIGHT
var mv_dir: Vector2 = Vector2.ZERO
var mv_spd: float = 0.0

func _ready() -> void:
	# ボスは個体ばらつきの対象外 (D49)。super._ready() より前に無効化する。
	use_variance = false
	super._ready()
	add_to_group("bosses")
	# ボスはエリートと同じ「加算式」の硬さにする (SPEC §31.5)。
	# 通常敵ぶんは super._ready() で適用済みなので、比だけを追加で掛ける。
	var ratio: float = DiffDB.cur_elite_ratio()
	if not is_equal_approx(ratio, 1.0):
		max_hp *= ratio
		hp = max_hp
	charge_cd = 6.0
	summon_cd = 12.0 if boss_id == "B02" else 10.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	contact_cd -= delta
	var target: Node2D = _find_player()
	mv_dir = Vector2.ZERO
	mv_spd = 0.0
	if target != null:
		var to: Vector2 = target.global_position - global_position
		var dist: float = to.length()
		var dir := Vector2.ZERO
		if dist > 1.0:
			dir = to.normalized()
		if windup > 0.0:
			windup -= delta
			flash = maxf(flash, 0.1)
			if windup <= 0.0:
				charging = 0.7
				charge_dir = dir
		elif charging > 0.0:
			charging -= delta
			mv_dir = charge_dir
			mv_spd = 520.0
			if charging <= 0.0:
				_shockwave()
				charge_cd = 10.0 if boss_id == "B02" else 8.0
		else:
			mv_dir = dir
			mv_spd = speed
			if boss_id == "B01":
				_b01_idle(delta, target, dist)
			else:
				_b02_idle(delta, target, dist)
	velocity = mv_dir * mv_spd + knockback
	move_and_slide()
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	_check_contact()

func _maybe_charge(delta: float, dist: float, min_d: float, max_d: float) -> void:
	charge_cd -= delta
	if charge_cd <= 0.0 and dist >= min_d and dist <= max_d:
		windup = 0.8
		flash = 0.8
		if body != null:
			body.modulate = Color(3, 1, 1, 1)

func _b01_idle(delta: float, target: Node2D, dist: float) -> void:
	_maybe_charge(delta, dist, 150.0, 600.0)
	summon_cd -= delta
	if summon_cd <= 0.0:
		summon_cd = 20.0
		_summon(["res://enemies/slime.tscn", "res://enemies/goblin.tscn", "res://enemies/bat.tscn"], 6)

func _b02_idle(delta: float, target: Node2D, dist: float) -> void:
	if hp < max_hp * 0.5:
		_maybe_charge(delta, dist, 150.0, 600.0)
	barrage_cd -= delta
	if barrage_cd <= 0.0:
		barrage_cd = 3.0
		for i: int in range(12):
			_fire_shot(Vector2.RIGHT.rotated(TAU * float(i) / 12.0))
	aimed_cd -= delta
	if aimed_cd <= 0.0:
		aimed_cd = 5.0
		var to: Vector2 = target.global_position - global_position
		if to.length() > 1.0:
			for k: int in range(3):
				_fire_shot(to.normalized().rotated(0.12 * float(k - 1)), 420.0, shot_damage)
	summon_cd -= delta
	if summon_cd <= 0.0:
		summon_cd = 25.0
		_summon(["res://enemies/golem.tscn", "res://enemies/knight.tscn"], 4)

func _shockwave() -> void:
	var p: Node = _find_player_raw()
	if p == null or bool(p.get("dead")):
		return
	var pp: Node2D = p as Node2D
	var away: Vector2 = pp.global_position - global_position
	if away.length() <= 170.0:
		if away.length() < 1.0:
			away = Vector2.RIGHT
		p.call("take_damage", 15.0)
		if p is CharacterBody2D:
			(p as CharacterBody2D).velocity += away.normalized() * 300.0

func _summon(paths: Array, n: int) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for i: int in range(n):
		var path: String = str(paths[randi() % paths.size()])
		if not ResourceLoader.exists(path):
			continue
		var scn: PackedScene = load(path) as PackedScene
		if scn == null:
			continue
		var m: Node = scn.instantiate()
		scene.add_child(m)
		(m as Node2D).global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 120.0

func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if dead:
		return
	super.take_damage(amount, kb, crit)
	if dead and not _rewarded:
		_rewarded = true
		_boss_reward()

func _boss_reward() -> void:
	var scene: Node = get_tree().current_scene
	var p: Node = _find_player_raw()
	var game: Node = get_tree().get_first_node_in_group("game")
	if boss_id == "B01":
		if scene != null:
			for i: int in range(3):
				var g: Area2D = GEM_SCENE.instantiate() as Area2D
				# 撃破の一撃が弾の area_entered (物理フラッシュ中) の場合があるため遅延追加する。
				# 親は原点の Main なので、追加前の global 設定がそのまま有効。
				g.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(i) / 3.0) * 40.0
				g.set("value", 20)
				scene.call_deferred("add_child", g)
		if game != null:
			game.call("add_score", 500)
		if p != null and not bool(p.get("dead")):
			p.call("heal", 30.0)
			p.set("pending_levels", int(p.get("pending_levels")) + 1)
			p.emit_signal("level_up")
	elif boss_id == "B02":
		# v1.1までは else 分岐のため永久に呼ばれなかった (D25で修正)
		if game != null:
			game.call("add_score", 1000)
			game.call("on_boss2_killed")
	if p != null and p.has_method("add_shake"):
		p.call("add_shake", 0.6)
