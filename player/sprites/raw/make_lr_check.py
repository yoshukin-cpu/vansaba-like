"""left/right フレームの向き確認用の比較画像を作る"""
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT / "player" / "sprites")
OUT = os.path.join(BASE, "raw", "preview")
S = 8
W = 64 * S

names = [
    ("player_walk_left_0.png", "LEFT_0 (should face LEFT)"),
    ("player_walk_left_2.png", "LEFT_2 (should face LEFT)"),
    ("player_walk_right_0.png", "RIGHT_0 (should face RIGHT)"),
    ("player_walk_right_2.png", "RIGHT_2 (should face RIGHT)"),
]
im = Image.new("RGBA", (W * len(names), W + 44), (30, 30, 40, 255))
dr = ImageDraw.Draw(im)
for i, (n, label) in enumerate(names):
    img = Image.open(os.path.join(BASE, n)).convert("RGBA")
    big = img.resize((W, W), Image.NEAREST)
    im.paste(big, (i * W, 44), big)
    dr.line([(i * W, 0), (i * W, W + 44)], fill=(90, 90, 110, 255), width=2)
    dr.text((i * W + 12, 16), label, fill=(240, 240, 250, 255))
path = os.path.join(OUT, "lr_direction_check_x8.png")
im.save(path)
print("wrote", path, im.size)
