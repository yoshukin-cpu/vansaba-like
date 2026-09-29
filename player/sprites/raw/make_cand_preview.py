"""新候補フレームの拡大比較と、既存idleとの整合チェック画像を作る"""
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT / "player" / "sprites")
CAND = os.path.join(BASE, "raw", "candidate")
OUT = os.path.join(BASE, "raw", "preview")
os.makedirs(OUT, exist_ok=True)
S = 8
W = 64 * S


def strip_row(paths, labels, out_name, bg=(30, 30, 40, 255)):
    im = Image.new("RGBA", (W * len(paths), W + 40), bg)
    dr = ImageDraw.Draw(im)
    for i, p in enumerate(paths):
        img = Image.open(p).convert("RGBA")
        big = img.resize((W, W), Image.NEAREST)
        im.paste(big, (i * W, 40), big)
        dr.line([(i * W, 0), (i * W, W + 40)], fill=(90, 90, 110, 255), width=2)
        dr.text((i * W + 10, 12), labels[i], fill=(230, 230, 240, 255))
    path = os.path.join(OUT, out_name)
    im.save(path)
    print("wrote", path, im.size)


# 新候補: down / up の4フレーム
for d in ["down", "up", "left", "right"]:
    strip_row([os.path.join(CAND, f"player_walk_{d}_{i}.png") for i in range(4)],
              [f"f{i}" for i in range(4)], f"cand_walk_{d}_x8.png")

# 整合チェック: 既存idle vs 新walk (down / left)
strip_row([os.path.join(BASE, "player_idle_down_0.png"),
           os.path.join(CAND, "player_walk_down_0.png"),
           os.path.join(CAND, "player_walk_down_1.png"),
           os.path.join(BASE, "player_idle_left_0.png"),
           os.path.join(CAND, "player_walk_left_0.png")],
          ["idle_down(v1)", "walk_down(f0)", "walk_down(f1)", "idle_left(v1)", "walk_left(f0)"],
          "consistency_check_x8.png")
