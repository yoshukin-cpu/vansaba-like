extends Node2D
## 取得式アイテム (D23)。宝箱から飛び出し、主人公が取りに行く必要がある。
## 接触半径 26px で取得。引き寄せは一切なし (マグネット無効・永続)。
## 取得時は chest_director.apply_item(kind, 取得位置) を流用する。

const ART := {
	"heart": preload("res://objects/sprites/item_heart.png"),
	"star": preload("res://objects/sprites/item_star.png"),
	"magnet": preload("res://objects/sprites/item_magnet.png"),
	"sword": preload("res://objects/sprites/item_sword.png"),
	"nova": preload("res://objects/sprites/item_nova.png"),
	"coin": preload("res://objects/sprites/coin.png"),
	"bomb": preload("res://objects/sprites/bomb.png"),
}

## アイテムID → 絵のキー
const ART_BY_ID := {
	"T01": "heart", "R_HEAL": "heart",
	"T02": "coin", "R_COIN": "coin",
	"T03": "bomb",
	"T06": "star",
	"T07": "magnet",
	"T09": "sword", "R_WEAPON": "sword",
	"T10": "nova",
}

const PICKUP_RADIUS := 26.0

var kind := ""
var big := false
var age := 0.0
var base_y := -20.0
## 落下演出中。初速で飛び出し、減速して着地するまで取得できない。
var fly_vel := Vector2.ZERO
var flying := false

var sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("items")

## kind: アイテムID (T01/T02/T03/T06/T07/T09/R_HEAL/R_COIN/R_WEAPON)
func setup(item_kind: String, is_big: bool = false) -> void:
	kind = item_kind
	big = is_big
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ART.get(str(ART_BY_ID.get(kind, "coin")), ART["coin"])
	var h: float = float((sprite.texture as Texture2D).get_height())
	base_y = -h / 2.0 + 4.0
	sprite.position = Vector2(0, base_y)
	if big:
		sprite.scale = Vector2(1.4, 1.4)
	add_child(sprite)
	# 宝箱から飛び出す: ランダム方向に初速を与え、着地するまで取得できない
	# 飛距離は約40〜85px (取得半径26より外に落ちる)
	fly_vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(220.0, 320.0)
	flying = true

func _process(delta: float) -> void:
	age += delta
	if flying:
		var step: Vector2 = fly_vel * delta
		# 減速 (約0.3〜0.5秒で着地)
		fly_vel = fly_vel.move_toward(Vector2.ZERO, 600.0 * delta)
		global_position += step
		if fly_vel.length() < 5.0:
			flying = false
			_fx().call("poof", global_position, Color(1, 1, 1, 1), false)
	if sprite != null and is_instance_valid(sprite):
		var hop := 0.0
		if flying:
			hop = -10.0 * (fly_vel.length() / 320.0)
		sprite.position.y = base_y + sin(age * 3.0) * 3.0 + hop

func _fx() -> Node:
	return get_tree().get_first_node_in_group("combat_fx")

func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio")

func _physics_process(_delta: float) -> void:
	if flying:
		return
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null or bool(p.get("dead")):
		return
	if global_position.distance_to(p.global_position) > PICKUP_RADIUS:
		return
	var director: Node = get_tree().get_first_node_in_group("chest_director")
	_audio().call("play", "item_pickup")
	if director != null:
		director.call("apply_item", kind, p.global_position)
	queue_free()
