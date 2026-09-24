#!/usr/bin/env python3
"""1min-image (gpt-image-2) のマゼンタ背景スプライトシートを
Godot 用の 64x64 フレーム PNG に変換するスクリプト。

使い方:
  python process_sheet.py <sheet.png> <out_dir> <prefix> <cols> <rows> <dir1,dir2,...>

例:
  python process_sheet.py raw/walk_sheet_v1.png . player_walk 4 4 down,left,right,up
  python process_sheet.py raw/idle_sheet_v1.png . player_idle 2 4 down,left,right,up

出力:
  <out_dir>/<prefix>_<dir>_<n>.png   (64x64, 足元ベースライン揃え)
  <out_dir>/<prefix>_preview.png     (4倍拡大コンタクトシート)
"""
import sys
import os
from collections import deque

import numpy as np
from PIL import Image

CANVAS = 64        # 出力キャンバスサイズ
TARGET_H = 44      # キャラクターの高さ(px)
BASELINE = 62      # 足元のY座標
ALPHA_CUT = 96     # アルファ二値化しきい値
X_DAMP = 0.5       # 横方向センタリングのダンピング (0=セル中央固定, 1=bbox中央)


def load_and_key(path, tol_hard=60.0, tol_soft=130.0):
    """マゼンタ背景を抜いて RGBA numpy 配列を返す。"""
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(np.int32)
    h, w, _ = a.shape

    border = np.concatenate([
        a[0:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
        a[:, 0:3].reshape(-1, 3), a[:, -3:].reshape(-1, 3),
    ])
    bg = np.median(border, axis=0)
    print(f"  bg color = {bg}")

    d = np.sqrt(((a - bg) ** 2).sum(axis=2))
    hard = d < tol_hard

    # 外周から連結している hard 領域だけを背景とみなす (flood fill)
    bgmask = np.zeros((h, w), dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if hard[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if hard[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and hard[ny, nx] and not bgmask[ny, nx]:
                bgmask[ny, nx] = True
                dq.append((ny, nx))

    alpha = np.full((h, w), 255.0, dtype=np.float32)
    alpha[bgmask] = 0.0
    near = (~bgmask) & (d < tol_soft)
    alpha[near] = np.clip(
        (d[near] - tol_hard) / max(1.0, tol_soft - tol_hard) * 255.0, 0, 255)

    r = a[:, :, 0].astype(np.float32)
    g = a[:, :, 1].astype(np.float32)
    b = a[:, :, 2].astype(np.float32)
    semi = (alpha > 0) & (alpha < 255)
    t = np.minimum(r, b) - g
    des = semi & (t > 30)
    r[des] -= t[des] * 0.85
    b[des] -= t[des] * 0.85

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 0] = np.clip(r, 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(g, 0, 255).astype(np.uint8)
    out[:, :, 2] = np.clip(b, 0, 255).astype(np.uint8)
    out[:, :, 3] = alpha.astype(np.uint8)
    return out


def segments(profile, min_gap=6, min_len=10):
    """1次元の占有率プロファイルをギャップで分割して区間リストを返す。"""
    segs = []
    in_seg = False
    start = 0
    for i, v in enumerate(profile):
        if v and not in_seg:
            in_seg = True
            start = i
        elif not v and in_seg:
            segs.append([start, i])
            in_seg = False
    if in_seg:
        segs.append([start, len(profile)])
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] < min_gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [tuple(m) for m in merged if m[1] - m[0] >= min_len]


def split_axis(occupancy, count, label):
    """占有率から count 個の区間を得る。失敗したら等分割にフォールバック。"""
    segs = segments(occupancy)
    if len(segs) == count:
        return segs
    print(f"  WARN: {label}: {len(segs)} 区間しか見つからず "
          f"(期待 {count}) -> 等分割にフォールバック: {segs}")
    n = len(occupancy)
    step = n / count
    return [(int(i * step), int((i + 1) * step)) for i in range(count)]


def main():
    sheet_path, out_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    cols, rows = int(sys.argv[4]), int(sys.argv[5])
    dirs = sys.argv[6].split(",")
    assert len(dirs) == rows, "dirs の数と rows が不一致"

    rgba = load_and_key(sheet_path)
    occ = rgba[:, :, 3] > 40
    h, w, _ = rgba.shape

    row_bands = split_axis(occ.any(axis=1), rows, "rows")
    print(f"  row bands: {row_bands}")

    # 全フレームを切り出して bbox を収集
    frames = []  # (row_idx, col_idx, crop_rgba)
    for ri, (y0, y1) in enumerate(row_bands):
        band = occ[y0:y1, :]
        col_bands = split_axis(band.any(axis=0), cols, f"row{ri} cols")
        print(f"  row{ri} col bands: {col_bands}")
        for ci, (x0, x1) in enumerate(col_bands):
            sub = rgba[y0:y1, x0:x1]
            m = sub[:, :, 3] > 40
            ys, xs = np.where(m)
            if len(ys) == 0:
                print(f"  WARN: row{ri} col{ci} は空")
                continue
            crop = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            cx = x0 + (xs.min() + xs.max() + 1) / 2.0   # シート上のbbox中心x
            frames.append({
                "ri": ri, "ci": ci, "crop": crop,
                "h": crop.shape[0], "cx": cx,
                "cell_cx": (x0 + x1) / 2.0,
            })

    hs = [f["h"] for f in frames]
    med_h = float(np.median(hs))
    scale = TARGET_H / med_h
    print(f"  content heights: {hs} (median {med_h:.1f}) -> scale {scale:.4f}")

    os.makedirs(out_dir, exist_ok=True)
    for f in frames:
        crop = f["crop"]
        nh = max(1, int(round(crop.shape[0] * scale)))
        nw = max(1, int(round(crop.shape[1] * scale)))
        im = Image.fromarray(crop, "RGBA").resize((nw, nh), Image.LANCZOS)
        arr = np.asarray(im).copy()
        arr[:, :, 3] = np.where(arr[:, :, 3] >= ALPHA_CUT, 255, 0).astype(np.uint8)
        # 横位置: セル中央からのずれをダンピングして適用
        offset = (f["cx"] - f["cell_cx"]) * scale * X_DAMP
        x = int(round(CANVAS / 2 - nw / 2 + offset))
        y = BASELINE - nh
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.paste(Image.fromarray(arr, "RGBA"), (x, y))
        name = f"{prefix}_{dirs[f['ri']]}_{f['ci']}.png"
        canvas.save(os.path.join(out_dir, name))
        print(f"  wrote {name} ({nw}x{nh})")

    # プレビュー (4倍拡大コンタクトシート)
    prev = Image.new("RGBA", (CANVAS * cols, CANVAS * rows), (24, 24, 32, 255))
    for f in frames:
        name = f"{prefix}_{dirs[f['ri']]}_{f['ci']}.png"
        im = Image.open(os.path.join(out_dir, name)).convert("RGBA")
        prev.paste(im, (f["ci"] * CANVAS, f["ri"] * CANVAS), im)
    prev = prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST)
    prev_path = os.path.join(out_dir, f"{prefix}_preview.png")
    prev.save(prev_path)
    print(f"  preview -> {prev_path}")


if __name__ == "__main__":
    main()
