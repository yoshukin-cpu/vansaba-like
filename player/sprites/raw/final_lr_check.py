"""現在の left/right フレームが、向き確認済みの旧v1アートと同じ向きかを判定する
(±3px位置合わせ + 不透明領域のみで比較)
"""
import os
import numpy as np
from PIL import Image

BASE = "<repo-root>/player/sprites"
OLD = os.path.join(BASE, "raw", "old_v1")


def load_rgba(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.int16)


def best_diff(a, b):
    alpha = (a[:, :, 3] > 0) | (b[:, :, 3] > 0)
    best = 1e9
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            s = np.roll(np.roll(b[:, :, :3], dy, axis=0), dx, axis=1)
            d = float(np.abs(a[:, :, :3] - s).sum(axis=2)[alpha].mean())
            best = min(best, d)
    return best


print("=== 現在のフレーム vs 旧v1アート (向き確認済み) ===")
for d in ["left", "right"]:
    for i in range(4):
        cur = load_rgba(os.path.join(BASE, f"player_walk_{d}_{i}.png"))
        d_same = best_diff(cur, load_rgba(os.path.join(OLD, f"player_walk_{d}_{i}.png")))
        d_opp = best_diff(cur, load_rgba(os.path.join(OLD, f"player_walk_{'right' if d == 'left' else 'left'}_{i}.png")))
        verdict = "v1と同じ向き" if d_same < d_opp else "v1と逆の向き(要確認)"
        print("  cur_%s_%d: v1_%s差=%6.1f v1_%s差=%6.1f -> %s" % (
            d, i, d, d_same, "right" if d == "left" else "left", d_opp, verdict))
