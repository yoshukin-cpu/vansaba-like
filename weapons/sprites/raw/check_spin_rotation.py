"""スピンソードの回転検証: 剣(シアン系)の重心角度を測り、4枚の比較画像を作る"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SHOTS = str(ROOT / "tmp_shots")
OUT = str(ROOT / "weapons" / "sprites" / "raw")
CX, CY = 576, 324   # プレイヤーは画面中央 (静止)


def sword_pixels(a):
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    # 剣: シアン系グロー (g,b が高く r が低い) または明るい銀 (全体に明るい)
    cyan = (g > 120) * (b > 140) * (b - r > 30)
    return cyan


print("=== 剣の角度 (プレイヤー中心) ===")
crops = []
for k in range(4):
    im = Image.open(os.path.join(SHOTS, f"spin_{k}.png")).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    m = sword_pixels(a)
    # プレイヤー近傍のリング内だけを見る
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    d = np.sqrt((xx - CX) ** 2 + (yy - CY) ** 2)
    ring = (d > 50) & (d < 140)
    sel = m & ring
    ys, xs = np.where(sel)
    if len(xs) == 0:
        print(f"  spin_{k}: 剣のピクセルが見つからない")
        continue
    ang = np.degrees(np.arctan2(ys.mean() - CY, xs.mean() - CX))
    print(f"  spin_{k}: 剣ピクセル {len(xs)}個  重心角度 {ang:7.1f}度  平均距離 {d[sel].mean():.1f}px")
    crop = im.crop((CX - 160, CY - 160, CX + 160, CY + 160))
    crops.append(crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST))

if crops:
    strip = Image.new("RGB", (sum(c.width for c in crops), crops[0].height), (26, 26, 34))
    x = 0
    for c in crops:
        strip.paste(c, (x, 0))
        x += c.width
    p = os.path.join(OUT, "spin_sword_rotation.png")
    strip.save(p)
    print("wrote", p, strip.size)
