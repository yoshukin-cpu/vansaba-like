extends Node2D
## 宝箱 (SPEC §19.2)。壊せるオブジェクトとしてふるまう:
## 受信用 Area2D を layer 2 (Enemy) に置くため、既存の弾・スピンソード・
## ホーミング・オービットボムがコード変更なしで当たる。
## グループは "chests" (enemies には入れない)。Hitbox は持たない。

const OPEN_TEXTURE: Texture2D = preload("res://objects/sprites/chest_open.png")

const LIFE := 30.0
const BLINK_AT := 5.0
const OPEN_SHOW_TIME := 0.5

var opened := false
var dead := false
var life := LIFE
var free_in := -1.0
var director: Node = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("chests")

func setup(director_node: Node, life_time: float = LIFE) -> void:
	director = director_node
	life = life_time

func _process(delta: float) -> void:
	if opened:
		if free_in > 0.0:
			free_in -= delta
			if free_in <= 0.0:
				queue_free()
		return
	life -= delta
	if life <= BLINK_AT and sprite != null:
		sprite.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 90.0))
	if life <= 0.0:
		queue_free()

## 同時上限で消されるときは中身を出さずに消える
func expire_silent() -> void:
	opened = true
	dead = true
	queue_free()

func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if opened:
		return
	opened = true
	dead = true
	free_in = OPEN_SHOW_TIME
	if sprite != null:
		sprite.texture = OPEN_TEXTURE
		sprite.modulate.a = 1.0
	# 開けた一撃が弾の area_entered (物理フラッシュ中) の場合があるため、
	# 中身の適用 (スポーンを伴う) は遅延する。位置は今の値を渡す。
	if director != null and is_instance_valid(director):
		director.call_deferred("open_chest_at", global_position)
