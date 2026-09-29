"""歩行フレームの拡大比較画像を作る (方向ごとに4フレーム横並び、8倍拡大)"""
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
SP = str(ROOT / "player" / "sprites")
OUT = os.path.join(SP, "raw", "preview")
os.makedirs(OUT, exist_ok=True)
DIRS = ["down", "left", "right", "up"]
S = 8

for d in DIRS:
    strip = Image.new("RGBA", (64 * 4 * S, 64 * S), (30, 30, 40, 255))
    for i in range(4):
        im = Image.open(os.path.join(SP, f"player_walk_{d}_{i}.png")).convert("RGBA")
        big = im.resize((64 * S, 64 * S), Image.NEAREST)
        strip.paste(big, (i * 64 * S, 0), big)
    dr = ImageDraw.Draw(strip)
    for i in range(1, 4):
        dr.line([(i * 64 * S, 0), (i * 64 * S, 64 * S)], fill=(90, 90, 110, 255), width=2)
    path = os.path.join(OUT, f"walk_{d}_x8.png")
    strip.save(path)
    print("wrote", path, strip.size)
