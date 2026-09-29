"""実機キャプチャの左右が、インストール済みフレームの左右と一致するか検証する
(±3pxの位置合わせをして、スプライトの不透明領域だけで比較する)
期待: 「左移動」のキャプチャは player_walk_left_* に近く、right_* とは遠い
"""
import os
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT / "player" / "sprites")
SHOTS = str(ROOT / "tmp_shots")


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
    crop = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    canvas = Image.new("RGB", (64, 64), (26, 26, 34))
    w, h = crop.size
    canvas.paste(crop, (32 - w // 2, 61 - h + 1))
    return np.asarray(canvas).astype(np.int16)


def best_diff(cap, frame):
    """±3pxずらして最小の差分を返す (フレームの不透明領域のみで比較)"""
    alpha = frame[:, :, 3] > 0
    rgb = frame[:, :, :3]
    best = 1e9
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            s = np.roll(np.roll(cap, dy, axis=0), dx, axis=1)
            d = float(np.abs(s - rgb).sum(axis=2)[alpha].mean())
            best = min(best, d)
    return best


installed = {}
for d in ["left", "right"]:
    installed[d] = [np.asarray(Image.open(os.path.join(BASE, f"player_walk_{d}_{i}.png")).convert("RGBA")).astype(np.int16)
                    for i in range(4)]

print("=== 実機キャプチャ vs インストール済みフレーム (位置合わせ後の最小差分) ===")
ok = True
for d in ["left", "right"]:
    for k in range(4):
        cap = extract(os.path.join(SHOTS, f"{d}_{k}.png"))
        dl = min(best_diff(cap, f) for f in installed["left"])
        dr = min(best_diff(cap, f) for f in installed["right"])
        match = "left" if dl < dr else "right"
        good = (match == d)
        ok = ok and good
        print("  %-5s移動のキャプチャ: left差=%6.1f right差=%6.1f -> %s に一致  %s" % (
            d, dl, dr, match, "OK" if good else "NG(左右が逆!)"))
print("RESULT:", "ALL OK" if ok else "MISMATCH")
