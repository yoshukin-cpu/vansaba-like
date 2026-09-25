extends RefCounted

## 周期対応のハッシュ / 値ノイズ。地形生成の「決定論」と「シームレスな周期」を担保する。
## すべて static。座標はタイルセル単位の整数 (またはセル単位の実数) で扱う。
##
## 注意: FastNoiseLite は周期タイル化できないため使わない (シームで地形が切れる)。

const SEED: int = 20260924

## ラン単位の地形シード。ラン開始時に `chunk_gen.begin_run()` が設定する (§27.1)。
## 0 のままだと v1.3 までの地形と同一。値を変えると地形 (バイオーム/障害物/装飾) が
## まるごと変わる。同じ値なら何度生成しても同じ地形 (決定論)。
static var run_seed: int = 0

## ラン単位のシードを設定する。掛け算の桁溢れを避けるため 31bit に丸める。
static func set_run_seed(v: int) -> void:
	run_seed = v & 0x7FFFFFFF

## 正の剰余 (GDScript の % は負で負を返すため)
static func pos_mod(v: int, m: int) -> int:
	var r: int = v % m
	return r + m if r < 0 else r

## 整数ハッシュ (64bit の範囲で決定的)。s は用途別の塩、run_seed はラン単位の種。
static func h2(x: int, y: int, s: int = SEED) -> int:
	var n: int = x * 374761393 + y * 668265263 + s * 2246822519 + run_seed * 2654435761
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return n

## 0.0〜1.0 のハッシュ値
static func f2(x: int, y: int, s: int = SEED) -> float:
	return float(h2(x, y, s) & 0xFFFFFF) / 16777215.0

## 周期 period (セル) の値ノイズ。x, y はセル単位の実数。
static func value_noise(x: float, y: float, period: int, s: int = SEED) -> float:
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var fx: float = x - float(x0)
	var fy: float = y - float(y0)
	var sx: float = fx * fx * (3.0 - 2.0 * fx)
	var sy: float = fy * fy * (3.0 - 2.0 * fy)
	var xa: int = pos_mod(x0, period)
	var xb: int = pos_mod(x0 + 1, period)
	var ya: int = pos_mod(y0, period)
	var yb: int = pos_mod(y0 + 1, period)
	var v00: float = f2(xa, ya, s)
	var v10: float = f2(xb, ya, s)
	var v01: float = f2(xa, yb, s)
	var v11: float = f2(xb, yb, s)
	return lerpf(lerpf(v00, v10, sx), lerpf(v01, v11, sx), sy)

## 周期を保ったままオクターブを重ねる (各オクターブで period を倍にする)
static func fbm(x: float, y: float, period: int, octaves: int, s: int = SEED) -> float:
	var total: float = 0.0
	var norm: float = 0.0
	var amp: float = 1.0
	var freq: float = 1.0
	var p: int = period
	for i: int in range(octaves):
		total += value_noise(x * freq, y * freq, p, s + i * 977) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.0
		p *= 2
	return total / maxf(norm, 0.0001)
