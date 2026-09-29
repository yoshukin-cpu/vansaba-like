"""剣スプライトの傾きを水平に補正する (回転武器用)"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT)
SP = os.path.join(BASE, "weapons", "sprites")


def axis_angle(img):
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    ys, xs = np.where(a[:, :, 3] > 0)
    pts = np.stack([xs - xs.mean(), ys - ys.mean()])
    evals, evecs = np.linalg.eigh(np.cov(pts))
    v = evecs[:, np.argmax(evals)]
    ang = np.degrees(np.arctan2(v[1], v[0]))
    if ang > 90:
        ang -= 180
    if ang < -90:
        ang += 180
    return ang


p = os.path.join(SP, "spin_sword.png")
im = Image.open(p).convert("RGBA")
before = axis_angle(im)
# 傾きを打ち消す方向に回転 (PILの正の角度は反時計回り)
rot = im.rotate(before, resample=Image.NEAREST, center=(im.width / 2, im.height / 2), fillcolor=(0, 0, 0, 0))
after = axis_angle(rot)
rot.save(p)
print(f"補正前: {before:+.1f}度 -> 補正後: {after:+.1f}度")
