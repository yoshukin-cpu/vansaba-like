"""実機キャプチャから歩行アニメの動作を検証する
- 各方向4枚のスクリーンショットからキャラを検出して切り出し
- フレーム間差分(脚/腕)を測り、アニメが動いているか確認
- 比較用ストリップ画像とGIFを作る
"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SHOTS = str(ROOT / "tmp_shots")
OUT = str(ROOT / "player" / "sprites" / "raw" / "preview")
DIRS = ["down", "left", "right", "up"]
S = 6


def char_mask(a):
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    blue = (b - r > 25) * (b > 90) * (g < 200)
    red = (r - g > 50) * (r > 110) * (b < 140)
    brown = (r - b > 40) * (r > 90) * (r < 200) * (g > 50)
    m = ((blue + red + brown) > 0)
    m[:100, :] = False
    m[560:, :] = False
    return m


def extract(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    m = char_mask(a)
    ys, xs = np.where(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    # 64x64キャンバスに足元ベースラインで貼る (ゲーム内と同じ基準)
    canvas = Image.new("RGB", (64, 64), (26, 26, 34))
    w, h = crop.size
    canvas.paste(crop, (32 - w // 2, 61 - h + 1))
    return canvas, (x1 - x0 + 1, y1 - y0 + 1)


print("=== 実機キャプチャのフレーム差分 ===")
frames = {}
for d in DIRS:
    frames[d] = []
    for k in range(4):
        c, size = extract(os.path.join(SHOTS, f"{d}_{k}.png"))
        frames[d].append(c)
    arrs = [np.asarray(c).astype(np.int16) for c in frames[d]]
    line = []
    for k in range(4):
        j = (k + 1) % 4
        diff = np.abs(arrs[k] - arrs[j]).sum(axis=2)
        mask = (diff > 60)
        # 脚(下40%)と上半身
        legs = mask[40:, :].mean()
        upper = mask[10:40, :].mean()
        line.append("f%d→f%d legs=%.2f upper=%.2f" % (k, j, legs, upper))
    print(f"{d:5s} " + " | ".join(line))

# 比較ストリップ
W = 64 * S
strip = Image.new("RGB", (W * 4, W * 4), (24, 24, 32))
for ri, d in enumerate(DIRS):
    for k in range(4):
        big = frames[d][k].resize((W, W), Image.NEAREST)
        strip.paste(big, (k * W, ri * W))
strip.save(os.path.join(OUT, "ingame_walk_strip.png"))
print("wrote ingame_walk_strip.png", strip.size)

# ゲーム内GIF (各方向4フレーム)
gif_frames = []
for k in range(4):
    row = Image.new("RGB", (64 * 4, 64), (24, 24, 32))
    for j, d in enumerate(DIRS):
        row.paste(frames[d][k], (j * 64, 0))
    gif_frames.append(row.resize((row.width * 3, row.height * 3), Image.NEAREST))
gif_frames[0].save(os.path.join(OUT, "preview_walk_ingame.gif"), save_all=True,
                   append_images=gif_frames[1:], duration=125, loop=0, disposal=2)
print("wrote preview_walk_ingame.gif")
