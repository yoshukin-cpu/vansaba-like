"""歩行フレームの定量解析: 脚/腕の動き量と、フレーム間の位置ズレを測る
使い方: python analyze_walk.py [スプライトのディレクトリ]
"""
import os
from pathlib import Path
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SP = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "player" / "sprites")
DIRS = ["down", "left", "right", "up"]


def load(d, i):
    return np.asarray(Image.open(os.path.join(SP, f"player_walk_{d}_{i}.png")).convert("RGBA")).astype(np.int16)


print("=== 各フレームの内容位置 (64x64キャンバス内) ===")
for d in DIRS:
    rows = []
    for i in range(4):
        a = load(d, i)[:, :, 3]
        ys, xs = np.where(a > 0)
        rows.append("f%d: y=%2d..%2d x=%2d..%2d (h=%d, cx=%.1f)" % (
            i, ys.min(), ys.max(), xs.min(), xs.max(), ys.max() - ys.min() + 1,
            (xs.min() + xs.max()) / 2))
    print(f"{d:5s} " + " | ".join(rows))

print()
print("=== フレーム間の差分 (領域別 平均|Δ|) ===")
for d in DIRS:
    frames = [load(d, i) for i in range(4)]
    for i in range(4):
        j = (i + 1) % 4
        f0, f1 = frames[i], frames[j]
        a0 = f0[:, :, 3] > 0
        a1 = f1[:, :, 3] > 0
        both = a0 | a1
        ys, xs = np.where(both)
        y0, y1 = ys.min(), ys.max()
        h = y1 - y0 + 1
        head = slice(y0, y0 + int(h * 0.35))
        arms = slice(y0 + int(h * 0.35), y0 + int(h * 0.62))
        legs = slice(y0 + int(h * 0.62), y1 + 1)
        diff = np.abs(f0 - f1).sum(axis=2).astype(np.float32)
        def m(sl):
            reg = diff[sl, :]
            return float(reg.mean())
        # 脚領域の「変化しているピクセルの割合」も出す
        leg_mask = (diff[legs, :] > 60)
        arm_mask = (diff[arms, :] > 60)
        print("%-5s f%d→f%d : head=%6.1f arms=%6.1f legs=%6.1f | 変化画素率 legs=%.2f arms=%.2f" % (
            d, i, j, m(head), m(arms), m(legs),
            leg_mask.mean(), arm_mask.mean()))

print()
print("=== 脚領域の最下段(足先)の高さ推移 ===")
for d in DIRS:
    feet = []
    for i in range(4):
        a = load(d, i)[:, :, 3]
        ys, xs = np.where(a > 0)
        feet.append(ys.max())
    print(f"{d:5s} feet_y = {feet}  (ばらつき={max(feet) - min(feet)}px)")
