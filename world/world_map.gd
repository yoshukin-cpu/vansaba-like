extends Node2D

## 周期的に無限に続くマップの描画と生成を管理する。
## - アクティブ窓 (既定 5x5 チャンク) だけを TileMapLayer に置く
## - チャンク跨ぎで差分更新 (進入したチャンクを追加 / 離れたチャンクを消去)
## - 生成は chunk_gen が決定論的なので、同じ座標には常に同じ地形が出る
## - 座標は折り返さない (世界の内容が周期 PERIOD_TILES で繰り返す)
## 詳細: SPEC §17

const CG := preload("res://world/chunk_gen.gd")
const TB := preload("res://world/tileset_builder.gd")

## 本素材 (world/sprites/*.png) を使うか。無ければ単色の仮素材。
@export var use_art: bool = true
## アクティブ窓の半径 (チャンク)。2 なら 5x5。
@export var window_radius: int = 2

## セル座標が16bitを超えないようにするための再配置しきい値
const REBASE_LIMIT: int = 10000

var ground: TileMapLayer = null
var obstacles: TileMapLayer = null

var _cache: Dictionary = {}      # 周期内チャンクキー -> 生成データ
var _placed: Dictionary = {}     # 絶対チャンク座標 -> true
var _center: Vector2i = Vector2i(1 << 29, 1 << 29)
var _cell_offset: Vector2i = Vector2i.ZERO

func _ready() -> void:
	add_to_group("world")
	y_sort_enabled = true
	var ts: TileSet = TB.build(use_art)
	ground = _make_layer("Ground", ts, -10, false)
	obstacles = _make_layer("Obstacles", ts, 0, true)
	_center = _chunk_of(_player_pos())
	_refresh()

func _process(_delta: float) -> void:
	var cc: Vector2i = _chunk_of(_player_pos())
	if cc == _center:
		return
	_center = cc
	if absi(_center.x) > REBASE_LIMIT or absi(_center.y) > REBASE_LIMIT:
		_rebase()
	_refresh()

## 障害物があるセルか (スポーン位置の回避に使う)
func is_blocked(global_pos: Vector2) -> bool:
	if obstacles == null:
		return false
	var cell: Vector2i = obstacles.local_to_map(obstacles.to_local(global_pos))
	return obstacles.get_cell_source_id(cell) != -1

## 障害物が無い場所を探す (見つからなければ原点位置を返す)
func find_free(global_pos: Vector2, tries: int = 8) -> Vector2:
	if not is_blocked(global_pos):
		return global_pos
	for i: int in range(tries):
		var p: Vector2 = global_pos + Vector2.RIGHT.rotated(randf() * TAU) * (float(i + 1) * 48.0)
		if not is_blocked(p):
			return p
	return global_pos

func _make_layer(lname: String, ts: TileSet, z: int, ysort: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = lname
	l.tile_set = ts
	l.z_index = z
	l.y_sort_enabled = ysort
	l.collision_enabled = ysort
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	return l

func _player_pos() -> Vector2:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return Vector2.ZERO
	return p.global_position

func _chunk_of(pos: Vector2) -> Vector2i:
	var s: float = float(CG.CHUNK * CG.TILE)
	return Vector2i(int(floor(pos.x / s)), int(floor(pos.y / s)))

func _refresh() -> void:
	var want: Dictionary = {}
	for dy: int in range(-window_radius, window_radius + 1):
		for dx: int in range(-window_radius, window_radius + 1):
			want[Vector2i(_center.x + dx, _center.y + dy)] = true
	for c: Vector2i in want.keys():
		if not _placed.has(c):
			_place(c)
	for c: Vector2i in _placed.keys():
		if not want.has(c):
			_erase(c)

func _place(c: Vector2i) -> void:
	var key: Vector2i = CG.chunk_key(c.x, c.y)
	var data: Dictionary = _cache.get(key, {})
	if data.is_empty():
		data = CG.generate_chunk(c.x, c.y)
		_cache[key] = data
	var g: PackedInt32Array = data["ground"] as PackedInt32Array
	var ox: int = c.x * CG.CHUNK - _cell_offset.x
	var oy: int = c.y * CG.CHUNK - _cell_offset.y
	for ly: int in range(CG.CHUNK):
		var row: int = ly * CG.CHUNK
		for lx: int in range(CG.CHUNK):
			ground.set_cell(Vector2i(ox + lx, oy + ly), g[row + lx], Vector2i.ZERO)
	for ob: Dictionary in (data["obstacles"] as Array):
		var local: Vector2i = ob["cell"] as Vector2i
		obstacles.set_cell(Vector2i(ox + local.x, oy + local.y), TB.OB_SOURCE_BASE + int(ob["tile"]), Vector2i.ZERO)
	_placed[c] = true

func _erase(c: Vector2i) -> void:
	var ox: int = c.x * CG.CHUNK - _cell_offset.x
	var oy: int = c.y * CG.CHUNK - _cell_offset.y
	for ly: int in range(CG.CHUNK):
		for lx: int in range(CG.CHUNK):
			var cell := Vector2i(ox + lx, oy + ly)
			ground.erase_cell(cell)
			obstacles.erase_cell(cell)
	_placed.erase(c)

## セル座標が16bit範囲に近づいたら、周期の倍数ぶんずらして置き直す (内容は同一)
func _rebase() -> void:
	var period: int = CG.CHUNKS_PER_PERIOD
	var shift := Vector2i(
		int(round(float(_center.x) / float(period))) * period,
		int(round(float(_center.y) / float(period))) * period
	)
	if shift == Vector2i.ZERO:
		return
	_cell_offset += shift * CG.CHUNK
	ground.clear()
	obstacles.clear()
	_placed.clear()
	var pos: Vector2 = Vector2(float(_cell_offset.x), float(_cell_offset.y)) * float(CG.TILE)
	ground.position = pos
	obstacles.position = pos
	_refresh()
	print("[world] rebased by %s chunks (offset %s)" % [str(shift), str(_cell_offset)])
