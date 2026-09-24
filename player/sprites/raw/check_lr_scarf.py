"""向きの独立判定: マフラー(赤)と顔(肌)の重心位置から左右を判定する
左向きキャラなら: マフラーは後方=画像右寄り / 顔は左寄り
"""
import os
import numpy as np
from PIL import Image

BASE = "<repo-root>/player/sprites"
OLD = os.path.join(BASE, "raw", "old_v1")


def analyze(path, label):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    ys, xs = np.where(al > 0)
    cx = (xs.min() + xs.max()) / 2.0
    red = (r - g > 50) * (r - b > 40) * (r > 100) * (al > 0)
    skin = (r > 170) * (g > 110) * (g < 200) * (b < 170) * (r - b > 40) * (al > 0)
    ry, rx = np.where(red)
    sy, sx = np.where(skin)
    red_off = (rx.mean() - cx) if len(rx) else float("nan")
    skin_off = (sx.mean() - cx) if len(sx) else float("nan")
    # 左向きなら red_off>0 (後方=右), skin_off<0 (顔は左)
    verdict = "左向き" if (red_off > 0 and skin_off < 0) else ("右向き" if (red_off < 0 and skin_off > 0) else "判定不能")
    print("  %-28s red_off=%+6.1f skin_off=%+6.1f  -> %s" % (label, red_off, skin_off, verdict))


print("=== 旧v1 (実機で向き確認済み) ===")
for d in ["left", "right"]:
    for i in [0, 2]:
        analyze(os.path.join(OLD, f"player_walk_{d}_{i}.png"), f"old_{d}_{i}")

print("=== 新v2 (現在インストール済み) ===")
for d in ["left", "right"]:
    for i in [0, 2]:
        analyze(os.path.join(BASE, f"player_walk_{d}_{i}.png"), f"new_{d}_{i}")
