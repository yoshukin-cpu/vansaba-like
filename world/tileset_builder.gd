extends RefCounted

## TileSet をコードで組み立てる (地面 + 障害物)。仮素材 (単色生成) と本素材 (PNG) を切り替える。
##
## タイルID ↔ ソースID:
##   地面/装飾  0..17 (草原4 / 荒野4 / 砂利4 / 装飾6) → source_id = tile_id
##   障害物     0..4  (木3 / 岩2)                      → source_id = OB_SOURCE_BASE + tile_id
##
## 障害物は「セルより大きい領域」を1セルに置く (木は 48x144)。texture_origin で上に伸ばす。
## y_sort_origin は「セル中心 + 4」= セル下端 - 20px。詳細は SPEC §18.3。

const CG := preload("res://world/chunk_gen.gd")

const TILE: int = 48
const GROUND_SOURCE_COUNT: int = 18
const OB_SOURCE_BASE: int = 18

## エンティティの足元補正 (px)。ソート基準を「セル下端」からこの分だけ上にずらす。
## プレイヤー (ノード原点 +10 が足元) と敵 (同 +24) の折衷値。
const ENTITY_FEET_OFFSET: int = 20

## 障害物の衝突レイヤ (layer 6 = 64)
const OBSTACLE_COLLISION_LAYER: int = 64

const ART_DIR: String = "res://world/sprites/"

## 障害物スペック: 領域サイズ / texture_origin / 衝突形状
const OB_SPECS: Array = [
	{"size": Vector2i(48, 144), "origin": Vector2i(0, 48), "shape": "trunk"},
	{"size": Vector2i(48, 144), "origin": Vector2i(0, 48), "shape": "trunk"},
	{"size": Vector2i(48, 144), "origin": Vector2i(0, 48), "shape": "trunk"},
	{"size": Vector2i(48, 48), "origin": Vector2i(0, 0), "shape": "rock_small"},
	{"size": Vector2i(48, 72), "origin": Vector2i(0, 12), "shape": "rock_big"},
]

static func build(use_art: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, OBSTACLE_COLLISION_LAYER)

	for i: int in range(GROUND_SOURCE_COUNT):
		var tex: Texture2D = _texture("ground_%d" % i, Vector2i(TILE, TILE), use_art)
		_add_ground_source(ts, tex)

	for i: int in range(OB_SPECS.size()):
		var spec: Dictionary = OB_SPECS[i]
		var size: Vector2i = spec["size"] as Vector2i
		var tex2: Texture2D = _texture("ob_%d" % i, size, use_art)
		_add_obstacle_source(ts, tex2, size, spec["origin"] as Vector2i, str(spec["shape"]))

	return ts

static func _add_ground_source(ts: TileSet, tex: Texture2D) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src)

static func _add_obstacle_source(ts: TileSet, tex: Texture2D, size: Vector2i, origin: Vector2i, shape: String) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = size
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src)
	var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
	td.texture_origin = origin
	# セル中心 (24) を基準に「下端 - ENTITY_FEET_OFFSET」へ合わせる
	td.y_sort_origin = TILE / 2 - ENTITY_FEET_OFFSET
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, _collision_points(shape, size))

## 衝突ポリゴンは「タイル中心 (セル中心) を原点」とする座標で指定する。
## ランタイムは shape の点に map_to_local(coords) = セル中心 を足すため、
## セル左上基準で指定すると (24,24) ずれる (実測で確認済み)。
static func _collision_points(shape: String, size: Vector2i) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"trunk":
			# セル下端 16px、幅 28px (中心基準なので y は 8..24)
			pts.append(Vector2(-14.0, 8.0))
			pts.append(Vector2(14.0, 8.0))
			pts.append(Vector2(14.0, 24.0))
			pts.append(Vector2(-14.0, 24.0))
		"rock_small":
			pts = _octagon(Vector2(0.0, 12.0), 14.0)
		"rock_big":
			pts = _octagon(Vector2(0.0, 8.0), 18.0)
	return pts

static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(8):
		var a: float = TAU * float(i) / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

## 本素材 (PNG) があれば読み、無ければ単色の仮素材を返す
static func _texture(name: String, size: Vector2i, use_art: bool) -> Texture2D:
	if use_art:
		var path: String = ART_DIR + name + ".png"
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				return res as Texture2D
	return _placeholder(name, size)

## ---- 仮素材 (単色 + 最小限の形) ----

static func _placeholder(name: String, size: Vector2i) -> ImageTexture:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	if name.begins_with("ground_"):
		var idx: int = int(name.substr(7))
		if idx < 4:
			img.fill(_shade(Color(0.23, 0.42, 0.20), idx, 0.035))
		elif idx < 8:
			img.fill(_shade(Color(0.56, 0.45, 0.29), idx - 4, 0.035))
		elif idx < 12:
			img.fill(_shade(Color(0.44, 0.44, 0.40), idx - 8, 0.035))
		else:
			img.fill(Color(0.23, 0.42, 0.20))
			var d: int = idx - 12
			match d:
				0, 1:
					_ellipse(img, 24, 24, 4, 4, Color(0.95, 0.55, 0.75) if d == 0 else Color(0.98, 0.88, 0.35))
				2, 3:
					_ellipse(img, 24, 30, 6, 4, Color(0.62, 0.60, 0.56) if d == 2 else Color(0.50, 0.48, 0.44))
				_:
					for k: int in range(4):
						_rect(img, 12 + k * 8, 20, 2, 14, Color(0.15, 0.32, 0.13))
	elif name.begins_with("ob_"):
		var oi: int = int(name.substr(3))
		if oi < 3:
			# 木: 上が樹冠 (領域 0..96)、下が幹 (領域 96..144)
			var canopy := Color(0.13, 0.30 + float(oi) * 0.03, 0.14)
			_ellipse(img, 24, 44, 23, 42, canopy)
			_ellipse(img, 14, 30, 13, 22, canopy.lightened(0.08))
			_rect(img, 16, 96, 16, 48, Color(0.34, 0.24, 0.14))
			_rect(img, 16, 96, 4, 48, Color(0.42, 0.31, 0.19))
		else:
			var rock := Color(0.52, 0.52, 0.50) if oi == 3 else Color(0.46, 0.46, 0.48)
			if oi == 3:
				_ellipse(img, 24, 36, 17, 12, rock)
				_ellipse(img, 24, 32, 13, 8, rock.lightened(0.12))
			else:
				_ellipse(img, 24, 56, 21, 16, rock)
				_ellipse(img, 22, 50, 15, 10, rock.lightened(0.12))
	return ImageTexture.create_from_image(img)

static func _shade(base: Color, idx: int, step: float) -> Color:
	var d: float = (float(idx) - 1.5) * step
	return Color(clampf(base.r + d, 0.0, 1.0), clampf(base.g + d, 0.0, 1.0), clampf(base.b + d, 0.0, 1.0))

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)

static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy: int in range(cy - ry, cy + ry + 1):
		for xx: int in range(cx - rx, cx + rx + 1):
			if xx < 0 or yy < 0 or xx >= img.get_width() or yy >= img.get_height():
				continue
			var dx: float = float(xx - cx) / maxf(1.0, float(rx))
			var dy: float = float(yy - cy) / maxf(1.0, float(ry))
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(xx, yy, c)
