#!/usr/bin/env python3
"""マゼンタ背景のモンスター/弾スプライトシートを Godot 用フレームに変換する。
process_sheet.py との違い:
  - 足元ベースラインではなく **中央アンカー** (敵・弾は原点中心)
  - キャンバスサイズと目標サイズを指定できる

使い方:
  python process_monsters.py <sheet.png> <out_dir> <prefix> <cols> <rows> <names> <canvas> <target>
例:
  python process_monsters.py raw/enemies_sheet_v1.png . enemy 4 3 slime,bat,goblin,archer,wolf,golem,splitter,sniper,swarm,knight,empty1,empty2 48 34
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ALPHA_CUT = 96


def load_and_key(path, tol_hard=60.0, tol_soft=130.0):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(np.int32)
    h, w, _ = a.shape
    border = np.concatenate([
        a[0:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
        a[:, 0:3].reshape(-1, 3), a[:, -3:].reshape(-1, 3),
    ])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(axis=2))
    hard = d < tol_hard
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
    alpha[near] = np.clip((d[near] - tol_hard) / max(1.0, tol_soft - tol_hard) * 255.0, 0, 255)
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
    segs = segments(occupancy)
    if len(segs) == count:
        return segs
    print(f"  WARN: {label}: {len(segs)} 区間 -> 等分割にフォールバック")
    n = len(occupancy)
    step = n / count
    return [(int(i * step), int((i + 1) * step)) for i in range(count)]


def main():
    sheet_path, out_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    cols, rows = int(sys.argv[4]), int(sys.argv[5])
    names = sys.argv[6].split(",")
    canvas = int(sys.argv[7])
    target = float(sys.argv[8])
    per_sprite = len(sys.argv) > 9 and sys.argv[9] == "each"
    per_pair = len(sys.argv) > 9 and sys.argv[9] == "pair"
    assert len(names) == cols * rows, "names の数と cols*rows が不一致"

    rgba = load_and_key(sheet_path)
    occ = rgba[:, :, 3] > 40
    h, w, _ = rgba.shape

    row_bands = split_axis(occ.any(axis=1), rows, "rows")
    print(f"  row bands: {row_bands}")

    cells = []
    for ri, (y0, y1) in enumerate(row_bands):
        col_bands = split_axis(occ[y0:y1, :].any(axis=0), cols, f"row{ri} cols")
        for ci, (x0, x1) in enumerate(col_bands):
            sub = rgba[y0:y1, x0:x1]
            m = sub[:, :, 3] > 40
            ys, xs = np.where(m)
            name = names[ri * cols + ci]
            if len(ys) == 0:
                print(f"  WARN: {name} は空セル")
                continue
            cells.append({
                "name": name,
                "crop": sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1],
            })

    sizes = [max(c["crop"].shape[0], c["crop"].shape[1]) for c in cells]
    med = float(np.median(sizes))
    mode = "per-pair" if per_pair else ("per-sprite" if per_sprite else "global")
    print(f"  content sizes: {sizes} (median {med:.1f})")
    print(f"  normalization: {mode} (target {target})")

    # ペア単位の基準サイズ (2フレームを同じ倍率に揃えてアニメのガタつきを防ぐ)
    pair_base = {}
    for i in range(0, len(cells), 2):
        j = min(i + 1, len(sizes) - 1)
        pair_base[i // 2] = float(max(sizes[i], sizes[j]))

    os.makedirs(out_dir, exist_ok=True)
    for idx, c in enumerate(cells):
        crop = c["crop"]
        own = max(crop.shape[0], crop.shape[1])
        if per_pair:
            base = pair_base[idx // 2]
        elif per_sprite:
            base = float(own)
        else:
            base = med
        scale = target / base
        nh = max(1, int(round(crop.shape[0] * scale)))
        nw = max(1, int(round(crop.shape[1] * scale)))
        im = Image.fromarray(crop, "RGBA").resize((nw, nh), Image.LANCZOS)
        arr = np.asarray(im).copy()
        arr[:, :, 3] = np.where(arr[:, :, 3] >= ALPHA_CUT, 255, 0).astype(np.uint8)
        canvas_img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        # 中央アンカー
        canvas_img.paste(Image.fromarray(arr, "RGBA"),
                         ((canvas - nw) // 2, (canvas - nh) // 2))
        out = os.path.join(out_dir, f"{prefix}_{c['name']}.png")
        canvas_img.save(out)
        print(f"  wrote {prefix}_{c['name']}.png ({nw}x{nh})")


if __name__ == "__main__":
    main()
