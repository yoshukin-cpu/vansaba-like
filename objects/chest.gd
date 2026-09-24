extends Node2D
## 宝箱 (SPEC §19.2)。壊せるオブジェクトとしてふるまう:
## 受信用 Area2D を layer 2 (Enemy) に置くため、既存の弾・スピンソード・
## ホーミング・オービットボムがコード変更なしで当たる。
## グループは "chests" (enemies には入れない)。Hitbox は持たない。

const OPEN_TEXTURE: Texture2D = preload("res://objects/sprites/chest_open.png")

const MAX_HP := 25.0
const OPEN_SHOW_TIME := 0.5

var opened := false
var dead := false
var hp := MAX_HP
var flash := 0.0
var free_in := -1.0
var director: Node = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("chests")

func setup(director_node: Node) -> void:
	director = director_node

func _process(delta: float) -> void:
	if opened:
		if free_in > 0.0:
			free_in -= delta
			if free_in <= 0.0:
				queue_free()
		return
	if flash > 0.0:
		flash -= delta
		if flash <= 0.0 and sprite != null:
			sprite.modulate = Color(1, 1, 1, 1)

func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if opened:
		return
	hp -= amount
	_fx().call("damage_number", global_position + Vector2(0, -20), amount, crit)
	if sprite != null:
		sprite.modulate = Color(3, 3, 3, 1)
	flash = 0.12
	if hp > 0.0:
		return
	opened = true
	dead = true
	free_in = OPEN_SHOW_TIME
	if sprite != null:
		sprite.texture = OPEN_TEXTURE
		sprite.modulate = Color(1, 1, 1, 1)
	# 開けた一撃が弾の area_entered (物理フラッシュ中) の場合があるため、
	# 中身の出現 (スポーンを伴う) は遅延する。位置は今の値を渡す。
	if director != null and is_instance_valid(director):
		director.call_deferred("open_chest_at", global_position)

func _fx() -> Node:
	return get_tree().get_first_node_in_group("combat_fx")
