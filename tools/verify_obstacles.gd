extends SceneTree
## P9 検証: (1) 障害物5種の衝突範囲 (2) 木タイルの Yソート境界 を実測する。
## 実行: godot --path <project> --script res://tools/verify_obstacles.gd

const TB := preload("res://world/tileset_builder.gd")
const OUT_DIR := "res://tmp_shots/"

const ROOT_OFFSET := Vector2(300.0, 320.0)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var world := Node2D.new()
	world.y_sort_enabled = true
	world.position = ROOT_OFFSET
	root.add_child(world)
	var ts: TileSet = TB.build(false)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.y_sort_enabled = true
	layer.collision_enabled = true
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(layer)
	for i: int in range(TB.OB_SPECS.size()):
		layer.set_cell(Vector2i(i * 2, 0), TB.OB_SOURCE_BASE + i, Vector2i.ZERO)
	for i: int in range(12):
		await physics_frame

	# --- (1) 衝突範囲 (セル中心 x を縦に走査) ---
	var space: PhysicsDirectSpaceState2D = root.world_2d.direct_space_state
	var fails: int = 0
	for i: int in range(TB.OB_SPECS.size()):
		var cx: float = float(i * 2) * 48.0 + 24.0
		var blocked: Array = []
		for y: int in range(-96, 80, 2):
			var q := PhysicsPointQueryParameters2D.new()
			q.position = ROOT_OFFSET + Vector2(cx, float(y))
			q.collision_mask = 64
			if space.intersect_point(q).size() > 0:
				blocked.append(y)
		var lo: float = float(blocked[0]) if blocked.size() > 0 else -999.0
		var hi: float = float(blocked[blocked.size() - 1]) if blocked.size() > 0 else -999.0
		print("ob_%d (%s) 衝突 y=%.0f..%.0f (%d点)" % [i, str(TB.OB_SPECS[i]["size"]), lo, hi, blocked.size()])
		if blocked.is_empty():
			fails += 1
			print("  FAIL 衝突なし")
	# 期待値: 木の幹は y 32..48 (セル下端16px)、岩は中心付近
	if fails > 0:
		print("RESULT: FAIL (衝突なし %d)" % fails)

	# --- (2) Yソート境界 (大きなマゼンタ矩形が木の手前に出る最小 y) ---
	var boundary: float = -999.0
	for k: int in range(41):
		var m: float = -80.0 + float(k) * 4.0
		var rect := Polygon2D.new()
		rect.polygon = PackedVector2Array([
			Vector2(0, -120), Vector2(48, -120), Vector2(48, 120), Vector2(0, 120),
		])
		rect.color = Color(1, 0, 1, 1)
		rect.position = Vector2(0, m)
		world.add_child(rect)
		await process_frame
		await process_frame
		var img: Image = root.get_texture().get_image()
		var px: Color = img.get_pixel(int(ROOT_OFFSET.x + 24.0), int(ROOT_OFFSET.y + 40.0))
		var rect_in_front: bool = px.r > 0.7 and px.b > 0.7 and px.g < 0.4
		if rect_in_front:
			boundary = m
			rect.queue_free()
			break
		rect.queue_free()
		await process_frame
	var expect: int = TB.TILE / 2 + (TB.TILE / 2 - TB.ENTITY_FEET_OFFSET)
	print("Yソート境界: y=%.0f (予測 %d = セル中心24 + y_sort_origin %d)" % [
		boundary, expect, TB.TILE / 2 - TB.ENTITY_FEET_OFFSET,
	])
	print("木の根元は y=48 / 境界が 28 なら「足元が根元より 20px 上まで奥に描画」= 設計どおり")
	if absf(boundary - float(expect)) > 4.0:
		print("RESULT: FAIL (境界が予測とずれている)")
	else:
		print("RESULT: PASS")
	quit()
