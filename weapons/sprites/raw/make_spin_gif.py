"""剣スプライトの軸の傾きを測り、実機4枚から回転GIFを作る"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT)
SP = os.path.join(BASE, "weapons", "sprites")
SHOTS = os.path.join(BASE, "tmp_shots")

# 1) 剣スプライトの主軸角度 (PCA)
a = np.asarray(Image.open(os.path.join(SP, "spin_sword.png")).convert("RGBA")).astype(np.float32)
mask = a[:, :, 3] > 0
ys, xs = np.where(mask)
pts = np.stack([xs - xs.mean(), ys - ys.mean()])
cov = np.cov(pts)
evals, evecs = np.linalg.eigh(cov)
v = evecs[:, np.argmax(evals)]
ang = np.degrees(np.arctan2(v[1], v[0]))
if ang > 90:
    ang -= 180
if ang < -90:
    ang += 180
print(f"剣スプライトの主軸角度: {ang:+.1f}度 (0度=完全に水平)")

# 2) 実機4枚から回転GIF (0.4s間隔 = 1/4回転なので400msで連続回転に見える)
frames = []
for k in range(4):
    im = Image.open(os.path.join(SHOTS, f"spin_{k}.png")).convert("RGB")
    c = im.crop((576 - 130, 324 - 130, 576 + 130, 324 + 130))
    frames.append(c.resize((c.width * 3, c.height * 3), Image.NEAREST))
out = os.path.join(SP, "raw", "spin_sword_ingame.gif")
frames[0].save(out, save_all=True, append_images=frames[1:], duration=400, loop=0, disposal=2)
print("wrote", out)
