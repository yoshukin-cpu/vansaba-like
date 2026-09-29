"""down(正面)/up(背面) の判定: 頭部の肌(顔)の面積で判定する
正面なら顔が見える(肌画素が多い) / 背面なら髪で覆われる(肌画素が少ない)
"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT / "player" / "sprites")
OLD = os.path.join(BASE, "raw", "old_v1")


def skin_ratio(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    ys, xs = np.where(al > 0)
    y0, y1 = ys.min(), ys.max()
    head = slice(y0, y0 + int((y1 - y0 + 1) * 0.45))
    content = (al[head, :] > 0)
    skin = (r > 170) * (g > 110) * (g < 200) * (b < 170) * (r - b > 40) * (al > 0)
    return float(skin[head, :].sum()) / max(1, float(content.sum()))


print("=== 頭部の肌(顔)の割合 ===")
print("旧v1 (実機確認済み): down=正面 / up=背面")
for d in ["down", "up"]:
    vals = [skin_ratio(os.path.join(OLD, f"player_walk_{d}_{i}.png")) for i in range(4)]
    print("  old_%-4s 顔の割合: %s  平均%.3f" % (d, ["%.3f" % v for v in vals], sum(vals) / 4))
print("現在のフレーム:")
for d in ["down", "up"]:
    vals = [skin_ratio(os.path.join(BASE, f"player_walk_{d}_{i}.png")) for i in range(4)]
    print("  cur_%-4s 顔の割合: %s  平均%.3f" % (d, ["%.3f" % v for v in vals], sum(vals) / 4))
