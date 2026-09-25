extends RefCounted

## 決定論的な地形生成 (純関数)。同じチャンクは常に同じ内容を返す。
## 世界は周期 PERIOD_TILES で繰り返すため、座標は内部で必ず周期座標に畳んでから使う。
##
## 生成内容:
##   ground    : PackedInt32Array (CHUNK*CHUNK) 地面タイルID (0..17)
##   obstacles : Array[Dictionary] {cell: Vector2i (チャンク内ローカル), tile: int (0..4)}
##
## 速度の勘所:
##   バイオームは周期全体 (288x288) の LUT を起動時に一度だけ構築する (サブ円をスタンプ)。
##   セルごとに全パッチを走査する素朴な実装は 1チャンク 20ms 超で、チャンク跨ぎにヒッチが出る。

const HN := preload("res://world/hash_noise.gd")

const TILE: int = 48
const CHUNK: int = 32
const PERIOD_TILES: int = 288          # 周期 = 9チャンク = 13,824px
const CHUNKS_PER_PERIOD: int = PERIOD_TILES / CHUNK

## 荒野パッチ: パッチ格子 (タイル) ごとに 1〜4 個の候補をジッタ配置
const PATCH_GRID: int = 96
const PATCH_COUNT_MAX: int = 4
const PATCH_SUB_MIN: int = 3
const PATCH_SUB_MAX: int = 5
const PATCH_R_MIN: float = 8.0          # タイル (384px)
const PATCH_R_MAX: float = 17.0         # タイル (816px)
const NOISE_SCALE: float = 12.0         # 円周ノイズの波長 (タイル)
const PATCH_R_MARGIN: float = 1.3       # ノイズによる半径の最大倍率

## 障害物候補格子 (タイル) と出現率
const OB_GRID: int = 4
const OB_P_GRASS: float = 0.32
const OB_P_WASTE: float = 0.80
const TREE_RATIO_GRASS: float = 0.6
const TREE_RATIO_WASTE: float = 0.3

## 装飾 (花・小石・草むら) の出現率
const DECOR_P: float = 0.06

## 開始地点の周囲は障害物を置かない (タイル)
const SPAWN_CLEAR: float = 3.0

## 地面タイルID
const G_GRASS: int = 0                  # 0..3  草原バリアント
const G_WASTE: int = 4                  # 4..7  荒野バリアント
const G_GRAVEL: int = 8                 # 8..11 砂利 (境界)
const G_DECOR: int = 12                 # 12..17 装飾 (花2 / 小石2 / 草むら2)
const GROUND_TILE_COUNT: int = 18

## 障害物タイルID (チャンク内)
const O_TREE: int = 0                   # 0..2 木3種
const O_ROCK: int = 3                   # 3..4 岩2種
const OBSTACLE_TILE_COUNT: int = 5

static var _patches: Array = []
static var _biome_lut := PackedByteArray()

## 絶対チャンク座標 → 周期内の正規チャンクキー
static func chunk_key(cx: int, cy: int) -> Vector2i:
	return Vector2i(HN.pos_mod(cx, CHUNKS_PER_PERIOD), HN.pos_mod(cy, CHUNKS_PER_PERIOD))

## セル座標のラップ距離 (最短符号付き差分, タイル単位)
static func wrap_delta_cell(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	var p: float = float(PERIOD_TILES)
	d.x -= p * round(d.x / p)
	d.y -= p * round(d.y / p)
	return d

## ピクセル座標のラップ距離 (最短符号付き差分)
static func wrap_delta_px(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	var l: float = float(PERIOD_TILES * TILE)
	d.x -= l * round(d.x / l)
	d.y -= l * round(d.y / l)
	return d

## 荒野パッチの一覧 (周期内に 9格子 × 1〜4個)。起動時に一度だけ構築する。
static func patches() -> Array:
	if _patches.is_empty():
		_build_patches()
	return _patches

static func _build_patches() -> void:
	var cells: int = PERIOD_TILES / PATCH_GRID
	for gy: int in range(cells):
		for gx: int in range(cells):
			var count: int = 1 + int(HN.f2(gx, gy, 4001) * float(PATCH_COUNT_MAX - 1) + 0.999)
			for i: int in range(count):
				var s: int = 5000 + i * 131
				var cx: float = float(gx * PATCH_GRID) + 8.0 + HN.f2(gx, gy, s) * float(PATCH_GRID - 16)
				var cy: float = float(gy * PATCH_GRID) + 8.0 + HN.f2(gx, gy, s + 17) * float(PATCH_GRID - 16)
				var base_r: float = PATCH_R_MIN + HN.f2(gx, gy, s + 43) * (PATCH_R_MAX - PATCH_R_MIN)
				var subs: Array = []
				var k: int = PATCH_SUB_MIN + int(HN.f2(gx, gy, s + 31) * float(PATCH_SUB_MAX - PATCH_SUB_MIN + 1))
				for j: int in range(k):
					var ang: float = HN.f2(gx * 7 + j, gy * 13 + i, s + 61) * TAU
					var dist: float = HN.f2(gx + j * 3, gy - i * 5, s + 71) * base_r * 0.9
					var rr: float = base_r * (0.5 + HN.f2(gx - j * 2, gy + i * 2, s + 83) * 0.6)
					subs.append({
						"c": Vector2(cx + cos(ang) * dist, cy + sin(ang) * dist),
						"r": rr,
					})
				_patches.append({"subs": subs})

## 円周ノイズ (パッチ半径の揺らぎ)。セル座標から決まる。
static func patch_scale(cell: Vector2i) -> float:
	var n: float = HN.value_noise(
		float(cell.x) / NOISE_SCALE,
		float(cell.y) / NOISE_SCALE,
		int(float(PERIOD_TILES) / NOISE_SCALE),
		7001
	)
	return 0.8 + 0.4 * n

## 周期全体のバイオーム LUT (1 = 荒野)。起動時に一度だけ構築する。
static func biome_lut() -> PackedByteArray:
	if _biome_lut.size() != PERIOD_TILES * PERIOD_TILES:
		_build_biome_lut()
	return _biome_lut

static func _build_biome_lut() -> void:
	_biome_lut.resize(PERIOD_TILES * PERIOD_TILES)
	_biome_lut.fill(0)
	for patch: Dictionary in patches():
		for sub: Dictionary in patch["subs"]:
			var c: Vector2 = sub["c"] as Vector2
			var r: float = float(sub["r"])
			var rmax: float = r * PATCH_R_MARGIN
			var x0: int = int(floor(c.x - rmax))
			var x1: int = int(ceil(c.x + rmax))
			var y0: int = int(floor(c.y - rmax))
			var y1: int = int(ceil(c.y + rmax))
			for yy: int in range(y0, y1 + 1):
				var yw: int = HN.pos_mod(yy, PERIOD_TILES)
				var row: int = yw * PERIOD_TILES
				for xx: int in range(x0, x1 + 1):
					var xw: int = HN.pos_mod(xx, PERIOD_TILES)
					var idx: int = row + xw
					if _biome_lut[idx] == 1:
						continue
					var re: float = r * patch_scale(Vector2i(xw, yw))
					var dx: float = float(xx) + 0.5 - c.x
					var dy: float = float(yy) + 0.5 - c.y
					if dx * dx + dy * dy <= re * re:
						_biome_lut[idx] = 1

## セルが荒野かどうか (周期座標)
static func is_wasteland(cell: Vector2i) -> bool:
	return biome_at(cell)

static func biome_at(cell: Vector2i) -> bool:
	var lut: PackedByteArray = biome_lut()
	var x: int = HN.pos_mod(cell.x, PERIOD_TILES)
	var y: int = HN.pos_mod(cell.y, PERIOD_TILES)
	return lut[y * PERIOD_TILES + x] == 1

## ラン開始時に呼ぶ: 地形シードを決めてシード依存のキャッシュを捨てる (§27.1)。
## これを呼ぶと以降に生成する地形がまるごと変わる (同じ seed なら常に同じ地形)。
## 戻り値は実際に使われるシード (内部で 31bit に丸めた値)。
static func begin_run(seed: int) -> int:
	HN.set_run_seed(seed)
	clear_cache()
	return HN.run_seed

## シード依存のキャッシュ (荒野パッチ / バイオーム LUT) を捨てる。
static func clear_cache() -> void:
	_patches.clear()
	_biome_lut = PackedByteArray()

## チャンクを生成する。cx, cy は絶対チャンク座標 (内部で周期に畳む)。
static func generate_chunk(cx: int, cy: int) -> Dictionary:
	var key: Vector2i = chunk_key(cx, cy)
	var ox: int = key.x * CHUNK
	var oy: int = key.y * CHUNK
	var lut: PackedByteArray = biome_lut()

	# --- バイオーム (1セル余白付きで読み、境界を求める) ---
	var size: int = CHUNK + 2
	var bio := PackedByteArray()
	bio.resize(size * size)
	var i: int = 0
	for ly: int in range(-1, CHUNK + 1):
		var yw: int = HN.pos_mod(oy + ly, PERIOD_TILES) * PERIOD_TILES
		for lx: int in range(-1, CHUNK + 1):
			bio[i] = lut[yw + HN.pos_mod(ox + lx, PERIOD_TILES)]
			i += 1

	# --- 地面タイル ---
	var ground := PackedInt32Array()
	ground.resize(CHUNK * CHUNK)
	for ly: int in range(CHUNK):
		for lx: int in range(CHUNK):
			var gx: int = ox + lx
			var gy: int = oy + ly
			var c: int = (ly + 1) * size + (lx + 1)
			var wl: bool = bio[c] == 1
			var boundary: bool = bio[c - 1] != bio[c] or bio[c + 1] != bio[c] or bio[c - size] != bio[c] or bio[c + size] != bio[c]
			var variant: int = int(HN.f2(gx, gy, 1101) * 3.999)
			var t: int = (G_WASTE if wl else G_GRASS) + variant
			if boundary and HN.f2(gx, gy, 1201) < 0.5:
				t = G_GRAVEL + variant
			elif HN.f2(gx, gy, 1301) < DECOR_P:
				t = G_DECOR + int(HN.f2(gx, gy, 1302) * 5.999)
			ground[ly * CHUNK + lx] = t

	# --- 障害物 (4タイル格子のジッタ配置) ---
	var obstacles: Array = []
	var g0x: int = int(floor(float(ox) / float(OB_GRID)))
	var g0y: int = int(floor(float(oy) / float(OB_GRID)))
	var g1x: int = g0x + CHUNK / OB_GRID - 1
	var g1y: int = g0y + CHUNK / OB_GRID - 1
	for gy2: int in range(g0y, g1y + 1):
		for gx2: int in range(g0x, g1x + 1):
			var ggx: int = HN.pos_mod(gx2, PERIOD_TILES / OB_GRID)
			var ggy: int = HN.pos_mod(gy2, PERIOD_TILES / OB_GRID)
			var jx: int = int(HN.f2(ggx, ggy, 9200) * float(OB_GRID))
			var jy: int = int(HN.f2(ggx, ggy, 9300) * float(OB_GRID))
			var cell := Vector2i(gx2 * OB_GRID + jx, gy2 * OB_GRID + jy)
			var wl2: bool = biome_at(cell)
			var p: float = OB_P_WASTE if wl2 else OB_P_GRASS
			if HN.f2(ggx, ggy, 9100) >= p:
				continue
			# 開始地点の周囲は空けておく
			if wrap_delta_cell(Vector2(0.0, 0.0), Vector2(float(cell.x), float(cell.y))).length() < SPAWN_CLEAR:
				continue
			var tree_ratio: float = TREE_RATIO_WASTE if wl2 else TREE_RATIO_GRASS
			var is_tree: bool = HN.f2(ggx, ggy, 9400) < tree_ratio
			var variant2: int = int(HN.f2(ggx, ggy, 9500) * (2.999 if is_tree else 1.999))
			obstacles.append({
				"cell": Vector2i(cell.x - ox, cell.y - oy),
				"tile": (O_TREE + variant2) if is_tree else (O_ROCK + variant2),
			})

	return {"ground": ground, "obstacles": obstacles}
