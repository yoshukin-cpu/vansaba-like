extends SceneTree
## P16 検証: T10ノヴァ・タイトル終了・タイトル画像。
## 実行: godot --path <project> --script res://tools/verify_v13.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const MainScene: PackedScene = preload("res://main.tscn")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const ItemsDB := preload("res://data/items_db.gd")

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	await process_frame
	await process_frame
	var player: Node2D = main.get_node("Player")
	var director: Node = main.get_node("ChestDirector")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	director.set("running", false)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame
	await _t_weights()
	await _t_nova(player, director, main)
	await _t_nova_item(player, director)
	_t_title(main)
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)


## 1) T10 が重み4で抽選枠に入っている
func _t_weights() -> void:
	var found := false
	var total := 0
	for w: Array in ItemsDB.WEIGHTS:
		total += int(w[1])
		if str(w[0]) == "T10" and int(w[1]) == 4:
			found = true
	_check("T10 weight 4 in table", found)
	_check("total weights 104", total == 104)
	var seen := false
	for k: int in range(2000):
		if ItemsDB.roll() == "T10":
			seen = true
			break
	_check("T10 rolled within 2000", seen)


## 2) ノヴァ: 画面内700pxに80dmg + 敵弾全消去 + 警告
func _t_nova(player: Node2D, director: Node, main: Node) -> void:
	for w: Node in player.get_node("Weapons").get_children():
		w.set("cooldown", 9999.0)
	var near: Node2D = _spawn_slime(player.global_position + Vector2(300, 0))
	var edge: Node2D = _spawn_slime(player.global_position + Vector2(650, 0))
	var far: Node2D = _spawn_slime(player.global_position + Vector2(900, 0))
	var hp_far: float = float(far.get("hp"))
	# 敵弾を3発アクティブ化する
	var pool: Node = get_first_node_in_group("pool_enemy_shots")
	var shots: Array = []
	for i: int in range(3):
		var s: Node = pool.call("acquire")
		if s == null:
			continue
		(s as Node2D).global_position = player.global_position + Vector2(100 + i * 40, 0)
		(s as Node).call("setup", Vector2.ZERO, 0.0, 1.0)
		shots.append(s)
	for i: int in range(5):
		await process_frame
	director.call("apply_item", "T10", player.global_position)
	for i: int in range(5):
		await process_frame
	_check("near slime killed by nova", not is_instance_valid(near))
	_check("edge slime killed by nova", not is_instance_valid(edge))
	_check("far slime unharmed", is_instance_valid(far) and absf(float(far.get("hp")) - hp_far) < 0.01)
	var left := 0
	for s: Node in shots:
		if is_instance_valid(s) and bool(s.get("active")):
			left += 1
	_check("all nova shots erased (%d left)" % left, left == 0)
	_check("nova warning shown", str(main.get_node("HUD/WarningLabel").get("text")) == "ノヴァ!")
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame


## 3) T10 は取得式アイテムとして飛び出す (nova絵)
func _t_nova_item(player: Node2D, director: Node) -> void:
	var it: Node = director.call("spawn_item", "T10", player.global_position, false)
	_check("T10 spawns item", is_instance_valid(it) and str(it.get("kind")) == "T10")
	var tex: Texture2D = (it.get("sprite") as Sprite2D).texture
	_check("T10 uses nova art", tex != null and tex.resource_path.ends_with("item_nova.png"))
	# 取得でノヴァが発動する (敵を置いて確認)
	var v: Node2D = _spawn_slime(player.global_position + Vector2(200, 0))
	# headless は fps が不定のため、固定フレーム数ではなく状態が変わるまで待つ。
	var guard := 0
	while is_instance_valid(it) and guard < 900:
		player.global_position = (it as Node2D).global_position
		await process_frame
		guard += 1
	for i: int in range(30):
		await process_frame
	_check("T10 pickup fires nova", not is_instance_valid(v))
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for n: Node in get_nodes_in_group("items"):
		n.queue_free()
	for i: int in range(5):
		await process_frame


## 4) タイトル: 終了ボタン・quit接続・絵・Dim
func _t_title(main: Node) -> void:
	var title: CanvasLayer = main.get_node("TitleUI")
	_check("quit button exists", title.get_node_or_null("QuitBtn") != null)
	_check("quit_pressed connected", title.is_connected("quit_pressed", Callable(main, "_on_desktop_quit")))
	var art: TextureRect = title.get_node_or_null("Art") as TextureRect
	_check("title art shown", art != null and art.texture != null)
	var dim: ColorRect = title.get_node("Dim") as ColorRect
	_check("dim alpha 0.55", absf(dim.color.a - 0.55) < 0.01)


func _spawn_slime(at: Vector2) -> Node2D:
	var a: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(a)
	a.global_position = at
	return a
